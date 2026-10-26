import Foundation
import GRDB

// The app imports these types from SwiftUtil; macOS tests compile their source
// files directly into the test module, where no SwiftUtil import is needed.
#if canImport(SwiftUtil)
  import SwiftUtil
#endif

/// Copies SQLite's committed view, including WAL transactions. Only iOS clipboard
/// sync bookkeeping is omitted; Android's schema and version are preserved.
enum DatabaseBackup {
  enum Failure: Error {
    case invalidDirectory
    case orphanedJournal(String)
    case integrityCheckFailed(String)
    case snapshotStillUsesWAL
  }

  private static let journalSuffixes = ["-wal", "-shm", "-journal"]

  static func snapshotDirectory(from source: URL, to destination: URL) throws {
    let manager = FileManager.default
    let children = try manager.contentsOfDirectory(
      at: source, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey])
    try manager.createDirectory(at: destination, withIntermediateDirectories: true)

    for child in children {
      try Task.checkCancellation()
      let values = try child.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
      guard values.isSymbolicLink != true else {
        throw Failure.invalidDirectory
      }
      if values.isDirectory == true {
        try snapshotDirectory(
          from: child, to: destination.appendingPathComponent(child.lastPathComponent))
      } else if let suffix = journalSuffixes.first(where: { child.lastPathComponent.hasSuffix($0) })
      {
        let main = child.deletingLastPathComponent().appendingPathComponent(
          String(child.lastPathComponent.dropLast(suffix.count)))
        guard manager.fileExists(atPath: main.path) else {
          throw Failure.orphanedJournal(child.lastPathComponent)
        }
      } else {
        try snapshot(from: child, to: destination.appendingPathComponent(child.lastPathComponent))
      }
    }
  }

  private static func snapshot(from source: URL, to destination: URL) throws {
    var configuration = Configuration()
    configuration.readonly = true
    configuration.busyMode = .timeout(5)
    let reader = try DatabaseQueue(path: source.path, configuration: configuration)
    defer { try? reader.close() }
    try reader.read { db in
      if source.lastPathComponent == ClipboardStore.databaseFileName {
        let version = try Int.fetchOne(db, sql: "PRAGMA user_version") ?? 0
        guard version == 4 else { throw ClipboardStore.Failure.unsupportedVersion(version) }
      }
      try checkIntegrity(db)
    }

    let writer = try DatabaseQueue(path: destination.path)
    defer { try? writer.close() }
    try reader.backup(to: writer)
    try Task.checkCancellation()
    // A backup may inherit the source's WAL mode. Only normalize the disposable copy.
    try writer.writeWithoutTransaction { db in
      guard try String.fetchOne(db, sql: "PRAGMA journal_mode = DELETE") == "delete" else {
        throw Failure.snapshotStillUsesWAL
      }
      try checkIntegrity(db)
    }
    try writer.write { db in
      if source.lastPathComponent == ClipboardStore.databaseFileName {
        try ClipboardStore.removeSyncMetadata(from: db)
      }
    }
    try writer.close()
    try reader.close()
    for suffix in journalSuffixes {
      let journal = URL(fileURLWithPath: destination.path + suffix)
      if FileManager.default.fileExists(atPath: journal.path) {
        try FileManager.default.removeItem(at: journal)
      }
    }
  }

  private static func checkIntegrity(_ db: Database) throws {
    let results = try String.fetchAll(db, sql: "PRAGMA integrity_check")
    guard results == ["ok"] else {
      throw Failure.integrityCheckFailed(results.joined(separator: "; "))
    }
  }
}
