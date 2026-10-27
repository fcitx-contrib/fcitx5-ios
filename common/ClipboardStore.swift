import Foundation
import GRDB

/// Android Room's clipboard schema, version 4. IDs are local to a database.
public struct ClipboardRecord: Codable, FetchableRecord, MutablePersistableRecord, Sendable,
  Equatable
{
  public static let databaseTableName = "clipboard"
  public var id: Int64?
  public var text: String
  public var pinned: Bool
  public var timestamp: Int64
  public var type: String
  public var deleted: Bool
  public var sensitive: Bool

  public init(text: String, timestamp: Int64 = Int64(Date().timeIntervalSince1970 * 1000)) {
    self.text = text
    self.timestamp = timestamp
    pinned = false
    type = "text/plain"
    deleted = false
    sensitive = false
  }

  public mutating func didInsert(_ inserted: InsertionSuccess) { id = inserted.rowID }

  func hasSameContent(as other: Self) -> Bool {
    var lhs = self
    var rhs = other
    lhs.id = nil
    rhs.id = nil
    return lhs == rhs
  }
}

/// Stable identity is separate from Android's auto-increment ID and survives text edits.
public struct ClipboardSyncEntry: Codable, Equatable, Sendable, Identifiable {
  public let id: UUID
  public var record: ClipboardRecord

  func hasSameContent(as other: Self) -> Bool { record.hasSameContent(as: other.record) }
}

private struct ClipboardIdentity: Codable, FetchableRecord, PersistableRecord {
  static let databaseTableName = "ios_clipboard_identity"
  let recordID: Int64
  let identity: UUID
}

struct ClipboardState: Codable, FetchableRecord, PersistableRecord {
  static let databaseTableName = "ios_clipboard_state"
  let key: String
  let value: Data
}

/// GRDB serializes each connection; SQLite's IMMEDIATE transactions serialize writers
/// across processes. Never replace the file while another process may have it open.
public final class ClipboardStore: @unchecked Sendable {
  public static let databaseFileName = "clbdb"

  public enum Failure: Error {
    case unsupportedVersion(Int)
    case invalidSync
  }

  public let databaseURL: URL
  private let legacyDirectory: URL?
  private let connectionLock = NSLock()
  // Protected by connectionLock. All subsequent access goes through GRDB.
  private var connection: DatabaseQueue?
  // Access only on the database queue. Archive readers leave retention unconfigured.
  private var historyLimit: Int?

  public init(directory: URL, legacyDirectory: URL? = nil) {
    databaseURL = directory.appendingPathComponent(Self.databaseFileName)
    self.legacyDirectory = legacyDirectory
  }

  func database() throws -> DatabaseQueue {
    connectionLock.lock()
    defer { connectionLock.unlock() }
    if let connection {
      if FileManager.default.fileExists(atPath: databaseURL.path) { return connection }
      // Documents can be removed while the app is running. The open SQLite
      // connection still points to the unlinked file and cannot be reused.
      try connection.close()
      self.connection = nil
    }
    try FileManager.default.createDirectory(
      at: databaseURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    let queue = try Self.openDatabase(at: databaseURL)
    do {
      // Read the legacy database before acquiring the destination's write lock.
      let legacy: [ClipboardSyncEntry]?
      let needsLegacy = try queue.read { db in
        guard try db.tableExists(ClipboardState.databaseTableName) else { return true }
        let migrated: Bool = try Self.state("legacyMigrated", in: db) ?? false
        return !migrated
      }
      if needsLegacy, let legacyDirectory,
        legacyDirectory != databaseURL.deletingLastPathComponent(),
        FileManager.default.fileExists(
          atPath: legacyDirectory.appendingPathComponent(Self.databaseFileName).path)
      {
        legacy = try ClipboardStore(directory: legacyDirectory).entries()
      } else {
        legacy = nil
      }
      try queue.write { db in
        try Self.prepareSchema(db)
        try Self.ensureIdentities(db)
        let migrated: Bool = try Self.state("legacyMigrated", in: db) ?? false
        if !migrated, let legacy {
          // A keyboard may have created the shared store before main's first launch.
          // Add legacy-only texts once; never overwrite existing shared rows/tombstones.
          let existing = try Self.entries(db)
          var texts = Set(existing.map { $0.record.text })
          let identities = Set(existing.map(\.id))
          for entry in legacy
          where !identities.contains(entry.id) && texts.insert(entry.record.text).inserted {
            try Self.insert(entry, in: db)
          }
          try Self.saveState(true, key: "legacyMigrated", in: db)
        }
      }
    } catch {
      try? queue.close()
      throw error
    }
    connection = queue
    return queue
  }

  private static func openDatabase(at url: URL) throws -> DatabaseQueue {
    var configuration = Configuration()
    configuration.journalMode = .wal
    configuration.busyMode = .timeout(5)
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: .seconds(5))
    while true {
      do {
        return try DatabaseQueue(path: url.path, configuration: configuration)
      } catch let error as DatabaseError
        where error.resultCode == .SQLITE_BUSY || error.resultCode == .SQLITE_LOCKED
      {
        // Simultaneous first opens can fail PRAGMA journal_mode = WAL immediately,
        // without invoking SQLite's busy handler. Retry opening, not a committed write.
        guard clock.now < deadline else { throw error }
        Thread.sleep(forTimeInterval: 0.02)
      }
    }
  }

  private static func prepareSchema(_ db: Database) throws {
    // Another process may have initialized the database after our initial read.
    // Clear GRDB's cached schema only after acquiring the IMMEDIATE write transaction.
    db.clearSchemaCache()
    let version = try Int.fetchOne(db, sql: "PRAGMA user_version") ?? 0
    if try db.tableExists(ClipboardRecord.databaseTableName) {
      guard version == 4 else { throw Failure.unsupportedVersion(version) }
    } else {
      guard version == 0 else { throw Failure.unsupportedVersion(version) }
      try db.create(table: ClipboardRecord.databaseTableName) { table in
        table.autoIncrementedPrimaryKey("id").notNull()
        table.column("text", .text).notNull()
        table.column("pinned", .integer).notNull()
        table.column("timestamp", .integer).notNull().defaults(to: -1)
        table.column("type", .text).notNull().defaults(to: "text/plain")
        table.column("deleted", .integer).notNull().defaults(to: 0)
        table.column("sensitive", .integer).notNull().defaults(to: 0)
      }
      try db.execute(sql: "PRAGMA user_version = 4")
    }
    try db.create(table: ClipboardIdentity.databaseTableName, ifNotExists: true) { table in
      table.primaryKey("recordID", .integer).references("clipboard", onDelete: .cascade)
      table.column("identity", .text).notNull().unique()
    }
    try db.create(table: ClipboardState.databaseTableName, ifNotExists: true) { table in
      table.primaryKey("key", .text)
      table.column("value", .blob).notNull()
    }
  }

  private static func ensureIdentities(_ db: Database) throws {
    let ids = Set(try ClipboardIdentity.fetchAll(db).map(\.recordID))
    for record in try ClipboardRecord.fetchAll(db) {
      if let id = record.id, !ids.contains(id) {
        try ClipboardIdentity(recordID: id, identity: UUID()).insert(db)
      }
    }
  }

  static func entries(_ db: Database) throws -> [ClipboardSyncEntry] {
    let identities = Dictionary(
      uniqueKeysWithValues: try ClipboardIdentity.fetchAll(db).map { ($0.recordID, $0.identity) })
    return try ClipboardRecord.order(
      Column("pinned").desc, Column("timestamp").desc, Column("id").desc
    )
    .fetchAll(db).map { record in
      guard let id = record.id, let identity = identities[id] else { throw Failure.invalidSync }
      return ClipboardSyncEntry(id: identity, record: record)
    }
  }

  public func entries() throws -> [ClipboardSyncEntry] {
    try database().read { try Self.entries($0) }
  }

  public func setHistoryLimit(_ limit: Int) throws {
    try database().write { db in
      historyLimit = max(0, limit)
      try pruneHistory(in: db)
    }
  }

  func pruneHistory(in db: Database) throws {
    guard let historyLimit else { return }
    // Recopying changes timestamps without changing IDs. Select exact overflow IDs,
    // including an ID tie-breaker, rather than deleting an ID range.
    let outdated = ClipboardRecord.filter(!Column("pinned") && !Column("deleted"))
      .order(Column("timestamp").desc, Column("id").desc)
      .select(Column("id"))
      .limit(-1, offset: historyLimit)
    // Keep tombstones so synchronization cannot resurrect expired entries.
    try ClipboardRecord.filter(outdated.contains(Column("id")))
      .updateAll(db, Column("deleted").set(to: true))
  }

  /// Discard local contents and sync history before an explicit full resync.
  /// Keep the database file open so concurrent readers never use an unlinked file.
  public func reset() throws {
    try database().write { db in
      try Self.replace([], in: db)
      try ClipboardState.deleteAll(db)
    }
  }

  public func capture(_ text: String) throws {
    guard text.contains(where: { !$0.isWhitespace }) else { return }
    try database().write { db in
      if var existing = try ClipboardRecord.filter(Column("text") == text && !Column("deleted"))
        .order(Column("timestamp").desc, Column("id").desc).fetchOne(db)
      {
        let (next, overflow) = existing.timestamp.addingReportingOverflow(1)
        existing.timestamp = max(
          Int64(Date().timeIntervalSince1970 * 1000), overflow ? existing.timestamp : next)
        try existing.update(db)
      } else {
        try Self.insert(ClipboardSyncEntry(id: UUID(), record: ClipboardRecord(text: text)), in: db)
      }
      try pruneHistory(in: db)
    }
  }

  public func togglePin(_ identity: UUID) throws {
    try database().write { db in
      guard var record = try Self.find(identity, in: db), !record.deleted else { return }
      record.pinned.toggle()
      try record.update(db)
    }
  }

  public func delete(_ identity: UUID) throws -> [ClipboardSyncEntry] {
    try database().write { db in
      guard var record = try Self.find(identity, in: db), !record.deleted else { return [] }
      let result = ClipboardSyncEntry(id: identity, record: record)
      record.deleted = true
      try record.update(db)
      return [result]
    }
  }

  public func clear(includePinned: Bool) throws -> [ClipboardSyncEntry] {
    try database().write { db in
      let entries = try Self.entries(db).filter {
        !$0.record.deleted && (includePinned || !$0.record.pinned)
      }
      for entry in entries {
        var record = entry.record
        record.deleted = true
        try record.update(db)
      }
      return entries
    }
  }

  public func restore(_ entries: [ClipboardSyncEntry]) throws {
    try database().write { db in
      for entry in entries {
        guard var original = try Self.find(entry.id, in: db), original.text == entry.record.text
        else {
          continue  // An import or authoritative sync replaced this identity.
        }
        // A newly captured identical text takes priority over the deleted row's timestamp.
        if var existing = try ClipboardRecord.filter(
          Column("text") == entry.record.text && !Column("deleted")
        ).order(Column("timestamp").desc, Column("id").desc).fetchOne(db) {
          existing.pinned = entry.record.pinned
          try existing.update(db)
        } else {
          original.deleted = false
          original.pinned = entry.record.pinned
          try original.update(db)
        }
      }
    }
  }

  static func find(_ identity: UUID, in db: Database) throws -> ClipboardRecord? {
    guard let mapping = try ClipboardIdentity.filter(Column("identity") == identity).fetchOne(db)
    else {
      return nil
    }
    return try ClipboardRecord.fetchOne(db, key: mapping.recordID)
  }

  static func insert(_ entry: ClipboardSyncEntry, in db: Database, recordID: Int64? = nil) throws {
    var record = entry.record
    record.id = recordID
    try record.insert(db)
    try ClipboardIdentity(recordID: record.id!, identity: entry.id).insert(db)
  }

  static func replace(_ entries: [ClipboardSyncEntry], in db: Database) throws {
    let existingIDs = Dictionary(
      uniqueKeysWithValues: try ClipboardIdentity.fetchAll(db).map { ($0.identity, $0.recordID) })
    try ClipboardIdentity.deleteAll(db)
    try ClipboardRecord.deleteAll(db)
    // Keep local numeric IDs for surviving identities, including deterministic timestamp ties.
    // Insert survivors first so auto-generated IDs cannot collide with an ID being retained.
    for entry in entries where existingIDs[entry.id] != nil {
      try insert(entry, in: db, recordID: existingIDs[entry.id])
    }
    for entry in entries where existingIDs[entry.id] == nil { try insert(entry, in: db) }
  }

  /// Called only with a normalized, disposable copy, so initialization cannot alter the archive.
  public func importDatabase(from url: URL) throws {
    let source = ClipboardStore(directory: url.deletingLastPathComponent())
    let imported = try source.entries().map { ClipboardSyncEntry(id: UUID(), record: $0.record) }
    try database().write { db in
      try Self.replace(imported, in: db)
      try pruneHistory(in: db)
      // Requests completed before an import remain replayable, but must not reapply their writes.
    }
  }

  static func state<T: Decodable>(_ key: String, in db: Database) throws -> T? {
    guard let row = try ClipboardState.fetchOne(db, key: key) else { return nil }
    return try JSONDecoder().decode(T.self, from: row.value)
  }

  static func saveState<T: Encodable>(_ value: T, key: String, in db: Database) throws {
    try ClipboardState(key: key, value: JSONEncoder().encode(value)).save(db)
  }

  /// Keep iOS sync bookkeeping out of Android-format archives.
  public static func removeSyncMetadata(from db: Database) throws {
    for table in [ClipboardIdentity.databaseTableName, ClipboardState.databaseTableName] {
      if try db.tableExists(table) { try db.drop(table: table) }
    }
  }
}
