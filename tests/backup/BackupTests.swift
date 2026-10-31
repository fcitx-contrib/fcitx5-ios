import Foundation
import GRDB
import GRDBSQLite
import ZIPFoundation

private struct TestFailure: Error {
  let message: String
}

private func expect(_ condition: Bool, _ message: String) throws {
  if !condition { throw TestFailure(message: message) }
}

// Android's Room v4 model. Do not reuse UI UUIDs or timestamps in seconds.
private struct AndroidClipboardFixture: Codable, FetchableRecord, PersistableRecord, Equatable {
  static let databaseTableName = "clipboard"
  let id: Int64
  let text: String
  let pinned: Bool
  let timestamp: Int64
  let type: String
  let deleted: Bool
  let sensitive: Bool

  static let fixtures = [
    AndroidClipboardFixture(
      id: 1, text: "普通文本 ' SQL ; 中文 🐧", pinned: false, timestamp: 1_791_662_951_174,
      type: "text/plain", deleted: false, sensitive: false),
    AndroidClipboardFixture(
      id: 2, text: "置顶", pinned: true, timestamp: 1_791_662_971_116,
      type: "text/plain", deleted: false, sensitive: false),
    AndroidClipboardFixture(
      id: 3, text: "已删除", pinned: true, timestamp: 1_791_662_987_381,
      type: "text/html", deleted: true, sensitive: true),
  ]
}

@main
private struct BackupTests {
  static var manager: FileManager { .default }
  static let roomHash = "b0fe6cdac09e0d7deaff17d8b45fe565"
  static let clipboardArchivePath = "databases/\(ClipboardStore.databaseFileName)"

  static func main() async throws {
    let root = manager.temporaryDirectory.appendingPathComponent("backup-tests-\(UUID())")
    try manager.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? manager.removeItem(at: root) }

    try testWALRoundTrip(root: root, includeSHM: true)
    try testWALRoundTrip(root: root, includeSHM: false)
    try testLiveExport(root: root)
    try testAndroidImportWithStaleWAL(root: root)
    try testReplacement(root: root)
    try testFailurePreservesDatabase(root: root)
    try testLegacyArchives(root: root)
    try testFileSync(root: root)
    try testPathTraversal(root: root)
    try testNoDatabaseDirectoryEntry(root: root)
    try testUncommittedTransactions(root: root)
    try testUnsupportedVersions(root: root)
    try await testCancellation(root: root)

    // Optional local-only verification of a user's archive, never included as a fixture.
    if CommandLine.arguments.count > 1 {
      let backup = store(at: root.appendingPathComponent("android-archive"))
      try backup.importData(from: URL(fileURLWithPath: CommandLine.arguments[1]), source: .fcitx5)
      try assertStandalone(
        backup.databasesDirectory.appendingPathComponent(ClipboardStore.databaseFileName))
      let records = try readDatabase(
        backup.databasesDirectory.appendingPathComponent(ClipboardStore.databaseFileName)
      ) {
        try AndroidClipboardFixture.order(Column("id")).fetchAll($0)
      }
      let exported = root.appendingPathComponent("android-roundtrip.zip")
      try backup.export(to: exported, date: Date())
      let restored = store(at: root.appendingPathComponent("android-roundtrip"))
      try restored.importData(from: exported, source: .fcitx5)
      try assertStandalone(
        restored.databasesDirectory.appendingPathComponent(ClipboardStore.databaseFileName))
      try readDatabase(
        restored.databasesDirectory.appendingPathComponent(ClipboardStore.databaseFileName)
      ) { db in
        try expect(
          try AndroidClipboardFixture.order(Column("id")).fetchAll(db) == records,
          "Actual Android archive roundtrip")
      }
      print("PASS supplied Android archive roundtrip (\(records.count) rows)")
    }
    print("All backup tests passed")
  }

  static func store(at root: URL) -> BackupArchive {
    BackupArchive(
      configDirectory: root.appendingPathComponent("config"),
      dataDirectory: root.appendingPathComponent("data"),
      databasesDirectory: root.appendingPathComponent("databases"))
  }

  static func fixture(at url: URL, wal: Bool) throws -> DatabaseQueue {
    try manager.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    var configuration = Configuration()
    if wal { configuration.journalMode = .wal }
    let queue = try DatabaseQueue(path: url.path, configuration: configuration)
    try queue.writeWithoutTransaction { db in
      try db.execute(sql: "PRAGMA wal_autocheckpoint = 0")
    }
    try queue.write { db in
      try db.execute(
        sql: """
          CREATE TABLE clipboard (
            id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
            text TEXT NOT NULL,
            pinned INTEGER NOT NULL,
            timestamp INTEGER NOT NULL DEFAULT -1,
            type TEXT NOT NULL DEFAULT 'text/plain',
            deleted INTEGER NOT NULL DEFAULT 0,
            sensitive INTEGER NOT NULL DEFAULT 0);
          CREATE TABLE room_master_table (id INTEGER PRIMARY KEY, identity_hash TEXT);
          CREATE TABLE android_metadata (locale TEXT);
          INSERT INTO android_metadata VALUES ('zh_CN');
          PRAGMA user_version = 4;
          """)
      try db.execute(
        sql: "INSERT INTO room_master_table VALUES (42, ?)", arguments: [roomHash])
      for record in AndroidClipboardFixture.fixtures { try record.insert(db) }
    }
    return queue
  }

  static func readDatabase<T>(_ url: URL, _ body: (Database) throws -> T) throws -> T {
    var configuration = Configuration()
    configuration.readonly = true
    let queue = try DatabaseQueue(path: url.path, configuration: configuration)
    defer { try? queue.close() }
    return try queue.read(body)
  }

  static func assertStandalone(_ url: URL) throws {
    for suffix in ["-wal", "-shm", "-journal"] {
      try expect(!manager.fileExists(atPath: url.path + suffix), "Unexpected sidecar \(suffix)")
    }
    try readDatabase(url) { db in
      try expect(try String.fetchOne(db, sql: "PRAGMA integrity_check") == "ok", "Integrity check")
      try expect(
        try String.fetchOne(db, sql: "PRAGMA journal_mode") == "delete", "Snapshot journal mode")
      try expect(try Int.fetchOne(db, sql: "PRAGMA user_version") == 4, "Room version")
      try expect(
        try String.fetchOne(db, sql: "SELECT identity_hash FROM room_master_table WHERE id = 42")
          == roomHash,
        "Room hash")
    }
  }

  static func assertFixture(_ url: URL) throws {
    try assertStandalone(url)
    try readDatabase(url) { db in
      try expect(
        try AndroidClipboardFixture.order(Column("id")).fetchAll(db)
          == AndroidClipboardFixture.fixtures,
        "Record fields")
      try expect(
        try Int.fetchOne(db, sql: "SELECT seq FROM sqlite_sequence WHERE name = 'clipboard'") == 3,
        "Sequence")
      try expect(
        try String.fetchOne(db, sql: "SELECT locale FROM android_metadata") == "zh_CN",
        "Extra table")
      let columns = try db.columns(in: "clipboard")
      try expect(
        columns.count == 7 && columns.allSatisfy(\.isNotNull), "Android column constraints")
    }
  }

  static func add(_ data: Data, path: String, archive: Archive) throws {
    try archive.addEntry(
      with: path, type: .file, uncompressedSize: Int64(data.count), compressionMethod: .deflate,
      provider: { position, count in
        let start = Int(position)
        return data.subdata(in: start..<min(start + count, data.count))
      })
  }

  static func makeArchive(at url: URL, entries: [(String, Data)]) throws {
    let archive = try Archive(url: url, accessMode: .create)
    try add(Data("{}".utf8), path: "metadata.json", archive: archive)
    for (path, data) in entries { try add(data, path: path, archive: archive) }
  }

  static func walArchive(root: URL, includeSHM: Bool) throws -> URL {
    let database = root.appendingPathComponent("source").appendingPathComponent(
      ClipboardStore.databaseFileName)
    let queue = try fixture(at: database, wal: true)
    defer { try? queue.close() }
    let main = try Data(contentsOf: database)
    let wal = try Data(contentsOf: URL(fileURLWithPath: database.path + "-wal"))
    try expect(
      main.count == 4096 && wal.count > main.count, "Fixture must have WAL-only schema and rows")
    // WAL precedes the main file, testing extraction order independence.
    var entries = [(clipboardArchivePath + "-wal", wal), (clipboardArchivePath, main)]
    if includeSHM {
      entries.append((clipboardArchivePath + "-shm", Data("stale Android WAL index".utf8)))
    }
    entries.append(("external/config/example", Data("config".utf8)))
    entries.append(("external/data/example", Data("data".utf8)))
    let archive = root.appendingPathComponent("android.zip")
    try makeArchive(at: archive, entries: entries)
    return archive
  }

  static func testWALRoundTrip(root: URL, includeSHM: Bool) throws {
    let directory = root.appendingPathComponent("wal-\(includeSHM)")
    let archiveURL = try walArchive(root: directory, includeSHM: includeSHM)
    let backup = store(at: directory.appendingPathComponent("imported"))
    try backup.importData(from: archiveURL, source: .fcitx5)
    try assertFixture(
      backup.databasesDirectory.appendingPathComponent(ClipboardStore.databaseFileName))
    try expect(
      try Data(contentsOf: backup.configDirectory.appendingPathComponent("example"))
        == Data("config".utf8), "Config mapping")
    try expect(
      try Data(contentsOf: backup.dataDirectory.appendingPathComponent("example"))
        == Data("data".utf8), "Data mapping")
    let exported = directory.appendingPathComponent("ios.zip")
    try backup.export(to: exported, date: Date())
    let archive = try Archive(url: exported, accessMode: .read)
    try expect(archive[clipboardArchivePath] != nil, "Database archive path")
    try expect(
      archive[clipboardArchivePath + "-wal"]?.uncompressedSize == 0,
      "Empty compatibility WAL")
    try expect(
      !archive.contains { $0.path.hasSuffix("-shm") || $0.path.hasSuffix("-journal") },
      "No SHM or rollback journal")
    try expect(
      archive["external/config/example"] != nil && archive["metadata.json"] != nil,
      "Android ZIP layout")
    let restored = store(at: directory.appendingPathComponent("roundtrip"))
    try restored.importData(from: exported, source: .fcitx5)
    try assertFixture(
      restored.databasesDirectory.appendingPathComponent(ClipboardStore.databaseFileName))
    print("PASS WAL import/export, SHM=\(includeSHM)")
  }

  static func testLiveExport(root: URL) throws {
    let directory = root.appendingPathComponent("live")
    let backup = store(at: directory)
    let main = backup.databasesDirectory.appendingPathComponent(ClipboardStore.databaseFileName)
    let queue = try fixture(at: main, wal: true)
    defer { try? queue.close() }
    let before = try Data(contentsOf: URL(fileURLWithPath: main.path + "-wal"))
    let exported = directory.appendingPathComponent("live.zip")
    try backup.export(to: exported, date: Date())
    try expect(
      try Data(contentsOf: URL(fileURLWithPath: main.path + "-wal")) == before,
      "Source WAL must not change")
    let restored = store(at: directory.appendingPathComponent("restored"))
    try restored.importData(from: exported, source: .fcitx5)
    try assertFixture(
      restored.databasesDirectory.appendingPathComponent(ClipboardStore.databaseFileName))
    print("PASS live WAL export without checkpointing source")
  }

  static func testAndroidImportWithStaleWAL(root: URL) throws {
    let directory = root.appendingPathComponent("android-stale-wal")
    let backup = store(at: directory.appendingPathComponent("source"))
    let source = backup.databasesDirectory.appendingPathComponent(ClipboardStore.databaseFileName)
    let sourceQueue = try fixture(at: source, wal: false)
    try sourceQueue.close()
    let exported = directory.appendingPathComponent("ios.zip")
    try backup.export(to: exported, date: Date())

    let target = directory.appendingPathComponent("android").appendingPathComponent(
      ClipboardStore.databaseFileName)
    let targetQueue = try fixture(at: target, wal: true)
    defer { try? targetQueue.close() }
    try targetQueue.write { db in
      _ = try AndroidClipboardFixture.deleteAll(db)
    }
    // Preserve the sidecars left by Android's open Room connection during import.
    let wal = try Data(contentsOf: URL(fileURLWithPath: target.path + "-wal"))
    let shm = try Data(contentsOf: URL(fileURLWithPath: target.path + "-shm"))
    try targetQueue.close()
    try wal.write(to: URL(fileURLWithPath: target.path + "-wal"))
    try shm.write(to: URL(fileURLWithPath: target.path + "-shm"))
    try Data(contentsOf: source).write(to: target)
    try readDatabase(target) { db in
      try expect(
        try AndroidClipboardFixture.fetchCount(db) == 0,
        "Fixture WAL must hide imported records when only the main file is replaced")
    }

    // Android overlays only files present in the ZIP, retaining any old sidecars.
    let archive = try Archive(url: exported, accessMode: .read)
    for entry in archive where entry.type == .file && entry.path.hasPrefix("databases/") {
      var data = Data()
      _ = try archive.extract(entry) { data.append($0) }
      try data.write(
        to: target.deletingLastPathComponent().appendingPathComponent(
          String(entry.path.dropFirst("databases/".count))))
    }
    try readDatabase(target) { db in
      try expect(
        try String.fetchOne(db, sql: "PRAGMA integrity_check") == "ok", "Android integrity")
      try expect(
        try AndroidClipboardFixture.order(Column("id")).fetchAll(db)
          == AndroidClipboardFixture.fixtures,
        "Stale Android WAL must not override imported records")
    }
    print("PASS Android overlay import with stale WAL and SHM")
  }

  static func testReplacement(root: URL) throws {
    let directory = root.appendingPathComponent("replace")
    let archive = try walArchive(root: directory, includeSHM: true)
    let backup = store(at: directory.appendingPathComponent("imported"))
    let old = try fixture(
      at: backup.databasesDirectory.appendingPathComponent(ClipboardStore.databaseFileName),
      wal: false)
    try old.close()
    let unrelated = backup.databasesDirectory.appendingPathComponent("other")
    let other = try fixture(at: unrelated, wal: false)
    try other.close()
    for suffix in ["-wal", "-shm", "-journal"] {
      try Data("old sidecar".utf8).write(
        to: backup.databasesDirectory.appendingPathComponent(
          ClipboardStore.databaseFileName + suffix))
    }
    try backup.importData(from: archive, source: .fcitx5)
    try assertFixture(
      backup.databasesDirectory.appendingPathComponent(ClipboardStore.databaseFileName))
    try assertFixture(unrelated)
    print("PASS atomic replacement and stale sidecar cleanup")
  }

  static func testFailurePreservesDatabase(root: URL) throws {
    let directory = root.appendingPathComponent("failure")
    let backup = store(at: directory)
    let main = backup.databasesDirectory.appendingPathComponent(ClipboardStore.databaseFileName)
    let queue = try fixture(at: main, wal: false)
    try queue.close()
    let before = try Data(contentsOf: main)
    for (name, entries) in [
      ("corrupt", [(clipboardArchivePath, Data("not SQLite".utf8))]),
      ("orphan", [("databases/missing-wal", Data("orphan WAL".utf8))]),
    ] {
      let archive = directory.appendingPathComponent("\(name).zip")
      try makeArchive(at: archive, entries: entries)
      var failed = false
      do { try backup.importData(from: archive, source: .fcitx5) } catch { failed = true }
      try expect(failed, "Invalid database must fail")
      try expect(
        try Data(contentsOf: main) == before, "Failed import must preserve existing database")
    }
    let contents = try manager.contentsOfDirectory(atPath: directory.path)
    try expect(!contents.contains { $0.hasPrefix(".backup-") }, "Import staging cleanup")
    print("PASS corrupted database and orphan WAL preserve existing data")
  }

  static func testLegacyArchives(root: URL) throws {
    let directory = root.appendingPathComponent("legacy")
    let backup = store(at: directory)
    let main = backup.databasesDirectory.appendingPathComponent(ClipboardStore.databaseFileName)
    let queue = try fixture(at: main, wal: false)
    try queue.close()
    let archive = directory.appendingPathComponent("legacy.zip")
    try makeArchive(at: archive, entries: [("external/data/example", Data("old".utf8))])
    try backup.importData(from: archive, source: .fcitx5)
    try assertFixture(main)
    let hamster = directory.appendingPathComponent("hamster.zip")
    try makeArchive(at: hamster, entries: [("HamsterBackup/RIME/Rime/example", Data("rime".utf8))])
    try backup.importData(from: hamster, source: .hamster)
    try expect(
      manager.fileExists(atPath: backup.dataDirectory.appendingPathComponent("rime/example").path),
      "Hamster mapping")
    try assertFixture(main)
    let empty = store(at: directory.appendingPathComponent("empty"))
    let export = directory.appendingPathComponent("empty.zip")
    try empty.export(to: export, date: Date())
    try empty.importData(from: export, source: .fcitx5)
    try expect(
      try manager.contentsOfDirectory(atPath: empty.databasesDirectory.path).isEmpty,
      "Empty databases")
    print("PASS legacy, Hamster, and empty archives")
  }

  static func testPathTraversal(root: URL) throws {
    let directory = root.appendingPathComponent("traversal")
    try manager.createDirectory(at: directory, withIntermediateDirectories: true)
    for (index, path) in ["databases/../escaped", "databases//absolute", "databases/a\\b"]
      .enumerated()
    {
      let archive = directory.appendingPathComponent("bad-\(index).zip")
      try makeArchive(at: archive, entries: [(path, Data("bad".utf8))])
      var failed = false
      do { try store(at: directory).importData(from: archive, source: .fcitx5) } catch {
        failed = true
      }
      try expect(failed, "Unsafe database path must fail")
    }
    try expect(
      !manager.fileExists(atPath: directory.appendingPathComponent("escaped").path), "ZIP traversal"
    )
    print("PASS ZIP path validation")
  }

  static func testNoDatabaseDirectoryEntry(root: URL) throws {
    // walArchive intentionally has no explicit databases/ directory entry.
    let directory = root.appendingPathComponent("plain")
    let backup = store(at: directory)
    let source = directory.appendingPathComponent("source").appendingPathComponent(
      ClipboardStore.databaseFileName)
    let queue = try fixture(at: source, wal: false)
    try queue.close()
    let archive = directory.appendingPathComponent("plain.zip")
    try makeArchive(at: archive, entries: [(clipboardArchivePath, try Data(contentsOf: source))])
    try backup.importData(from: archive, source: .fcitx5)
    try assertFixture(
      backup.databasesDirectory.appendingPathComponent(ClipboardStore.databaseFileName))
    print("PASS standalone import without directory entries")
  }

  static func testUncommittedTransactions(root: URL) throws {
    let directory = root.appendingPathComponent("uncommitted")
    let backup = store(at: directory)
    let main = backup.databasesDirectory.appendingPathComponent(ClipboardStore.databaseFileName)
    let queue = try fixture(at: main, wal: true)
    defer { try? queue.close() }
    try queue.writeWithoutTransaction { db in
      try db.execute(sql: "PRAGMA cache_size = 1")
      let originalWAL = try Data(contentsOf: URL(fileURLWithPath: main.path + "-wal"))
      try db.execute(sql: "BEGIN IMMEDIATE")
      do {
        try db.execute(
          sql: "UPDATE clipboard SET pinned = 0, text = ? WHERE id = 2",
          arguments: [String(repeating: "uncommitted", count: 100_000)])
        try expect(
          sqlite3_db_cacheflush(db.sqliteConnection) == SQLITE_OK, "Flush uncommitted pages")
        let wal = try Data(contentsOf: URL(fileURLWithPath: main.path + "-wal"))
        try expect(wal.count > originalWAL.count, "Fixture must spill uncommitted WAL frames")
        let archive = directory.appendingPathComponent("uncommitted.zip")
        try backup.export(to: archive, date: Date())
        let restored = store(at: directory.appendingPathComponent("restored"))
        try restored.importData(from: archive, source: .fcitx5)
        try assertFixture(
          restored.databasesDirectory.appendingPathComponent(ClipboardStore.databaseFileName))
        let importedWAL = directory.appendingPathComponent("uncommitted-wal.zip")
        try makeArchive(
          at: importedWAL,
          entries: [
            (clipboardArchivePath, try Data(contentsOf: main)),
            (clipboardArchivePath + "-wal", wal),
          ])
        try restored.importData(from: importedWAL, source: .fcitx5)
        try assertFixture(
          restored.databasesDirectory.appendingPathComponent(ClipboardStore.databaseFileName))
        try db.execute(sql: "ROLLBACK")
      } catch {
        try? db.execute(sql: "ROLLBACK")
        throw error
      }
    }
    print("PASS uncommitted WAL frames are neither imported nor exported")
  }

  static func testUnsupportedVersions(root: URL) throws {
    for version in [0, 1, 2, 3, 5] {
      let directory = root.appendingPathComponent("schema-\(version)")
      let main = directory.appendingPathComponent("source").appendingPathComponent(
        ClipboardStore.databaseFileName)
      let queue = try fixture(at: main, wal: false)
      try queue.write { try $0.execute(sql: "PRAGMA user_version = \(version)") }
      try queue.close()
      let before = try Data(contentsOf: main)
      let archive = directory.appendingPathComponent("old.zip")
      try makeArchive(at: archive, entries: [(clipboardArchivePath, try Data(contentsOf: main))])
      let backup = store(at: directory.appendingPathComponent("restored"))
      let target = backup.databasesDirectory.appendingPathComponent(ClipboardStore.databaseFileName)
      try fixture(at: target, wal: false).close()
      do {
        try backup.importData(from: archive, source: .fcitx5)
        throw TestFailure(message: "Unsupported archive schema must fail")
      } catch ClipboardStore.Failure.unsupportedVersion(let rejected) {
        try expect(rejected == version, "Report unsupported archive version")
      }
      try expect(try Data(contentsOf: main) == before, "Source database unchanged")
      try assertFixture(target)
    }
    print("PASS unsupported archive schemas rejected without replacing existing data")
  }

  static func testCancellation(root: URL) async throws {
    let directory = root.appendingPathComponent("cancelled")
    let archive = try walArchive(root: directory, includeSHM: true)
    let backup = store(at: directory.appendingPathComponent("restored"))
    for export in [false, true] {
      let task = Task.detached {
        withUnsafeCurrentTask { $0?.cancel() }
        if export {
          try backup.export(to: directory.appendingPathComponent("cancelled.zip"), date: Date())
        } else {
          try backup.importData(from: archive, source: .fcitx5)
        }
      }
      var cancelled = false
      do { try await task.value } catch is CancellationError { cancelled = true }
      try expect(cancelled, "Cancellation must be propagated")
    }
    try expect(
      !manager.fileExists(atPath: backup.databasesDirectory.path),
      "Cancelled import must not install database")
    try expect(
      !manager.fileExists(atPath: directory.appendingPathComponent("cancelled.zip").path),
      "Cancelled export must not leave ZIP")
    print("PASS cancelled import/export cleanup")
  }
}
