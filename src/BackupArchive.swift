import Foundation
import ZIPFoundation

struct InvalidZipError: Error {}

enum ImportSource: Sendable {
  case fcitx5
  case hamster
}

/// Archive layout matches Fcitx5 Android. Database transport is local to the main app.
struct BackupArchive {
  let configDirectory: URL
  let dataDirectory: URL
  let databasesDirectory: URL

  private struct ArchiveEntry {
    let sourceURL: URL?
    let archivePath: String
    let isDirectory: Bool
  }

  private static let requiredDirectoryEntries = [
    "external/",
    "databases/",
    "recently_used/",
    "shared_prefs/",
  ]
  private static let metadataEntry = "metadata.json"
  private static let hamsterRimePrefix = "HamsterBackup/RIME/Rime/"

  private static func getMetadata(_ date: Date) throws -> Data {
    let object: [String: Any] = [
      "packageName": "org.fcitx.fcitx5.android",
      "versionCode": 0,
      "versionName": "",
      "exportTime": Int64(date.timeIntervalSince1970 * 1000),
    ]
    return try JSONSerialization.data(withJSONObject: object)
  }

  private static func validateImportArchive(_ archive: Archive, source: ImportSource) -> Bool {
    switch source {
    case .fcitx5:
      return archive.contains { $0.path == metadataEntry }
    case .hamster:
      return archive.contains { $0.path.hasPrefix(hamsterRimePrefix) }
    }
  }

  func export(to destination: URL, date: Date) throws {
    try Task.checkCancellation()
    let manager = FileManager.default
    let staging = manager.temporaryDirectory.appendingPathComponent("backup-\(UUID())")
    try manager.createDirectory(at: staging, withIntermediateDirectories: true)
    defer { try? manager.removeItem(at: staging) }

    let databases = staging.appendingPathComponent("databases")
    var mappings = [
      (source: configDirectory, destination: "external/config/"),
      (source: dataDirectory, destination: "external/data/"),
    ]
    if manager.fileExists(atPath: databasesDirectory.path) {
      try DatabaseBackup.snapshotDirectory(from: databasesDirectory, to: databases)
      mappings.append((source: databases, destination: "databases/"))
    }
    let entries = try collectEntries(mappings)

    if manager.fileExists(atPath: destination.path) {
      try manager.removeItem(at: destination)
    }

    var success = false
    defer {
      if !success {
        try? manager.removeItem(at: destination)
      }
    }
    let archive = try Archive(url: destination, accessMode: .create)
    var directories = Set<String>()
    for path in Self.requiredDirectoryEntries {
      try addDirectory(path, to: archive)
      directories.insert(path)
    }
    for entry in entries.filter({ $0.isDirectory }).sorted(by: { $0.archivePath < $1.archivePath })
    where !directories.contains(entry.archivePath) {
      try Task.checkCancellation()
      try addDirectory(entry.archivePath, to: archive)
      directories.insert(entry.archivePath)
    }
    for entry in entries.filter({ !$0.isDirectory }).sorted(by: { $0.archivePath < $1.archivePath })
    {
      try Task.checkCancellation()
      if let sourceURL = entry.sourceURL {
        try archive.addEntry(
          with: entry.archivePath, fileURL: sourceURL, compressionMethod: .deflate)
      }
    }
    let metadata = try Self.getMetadata(date)
    try archive.addEntry(
      with: Self.metadataEntry, type: .file, uncompressedSize: Int64(metadata.count),
      compressionMethod: .deflate,
      provider: { position, size in
        let start = Int(position)
        return metadata.subdata(in: start..<min(start + size, metadata.count))
      })
    try Task.checkCancellation()
    success = true
  }

  func importData(from sourceURL: URL, source: ImportSource) throws {
    try Task.checkCancellation()
    let archive = try Archive(url: sourceURL, accessMode: .read)
    guard Self.validateImportArchive(archive, source: source) else {
      throw InvalidZipError()
    }

    let manager = FileManager.default
    // Stage on the destination volume so the final database replacement is atomic.
    let staging = databasesDirectory.deletingLastPathComponent().appendingPathComponent(
      ".backup-\(UUID())")
    try manager.createDirectory(at: staging, withIntermediateDirectories: true)
    defer { try? manager.removeItem(at: staging) }
    let extracted = staging.appendingPathComponent("extracted")
    let normalized = staging.appendingPathComponent("normalized")

    if source == .fcitx5 {
      for entry in archive where entry.path.hasPrefix("databases/") {
        try extract(entry, from: archive, root: extracted, prefix: "databases/")
      }
      if manager.fileExists(atPath: extracted.path) {
        // Discard Android's SHM WAL index; keep the WAL containing committed data.
        // SQLite rebuilds the index when snapshotDirectory opens the extracted database.
        if let enumerator = manager.enumerator(at: extracted, includingPropertiesForKeys: nil) {
          for case let url as URL in enumerator where url.lastPathComponent.hasSuffix("-shm") {
            try manager.removeItem(at: url)
          }
        }
        try DatabaseBackup.snapshotDirectory(from: extracted, to: normalized)
      }
    }

    let mappings: [(String, URL)] =
      source == .fcitx5
      ? [("external/config/", configDirectory), ("external/data/", dataDirectory)]
      : [(Self.hamsterRimePrefix, dataDirectory.appendingPathComponent("rime"))]
    for entry in archive {
      for (prefix, root) in mappings where entry.path.hasPrefix(prefix) {
        try extract(entry, from: archive, root: root, prefix: prefix)
      }
    }
    if manager.fileExists(atPath: normalized.path) {
      try installDatabases(from: normalized, staging: staging)
    }
  }

  private static func validateDirectory(_ directory: URL) throws {
    let values = try directory.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
    guard values.isDirectory == true, values.isSymbolicLink != true else {
      throw DatabaseBackup.Failure.invalidDirectory
    }
  }

  private func installDatabases(from incoming: URL, staging: URL) throws {
    let manager = FileManager.default
    let replacement = staging.appendingPathComponent("replacement")
    let exists = manager.fileExists(atPath: databasesDirectory.path)
    if exists {
      try Self.validateDirectory(databasesDirectory)
      try manager.copyItem(at: databasesDirectory, to: replacement)
    } else {
      try manager.createDirectory(at: replacement, withIntermediateDirectories: true)
    }
    try overlayDatabases(from: incoming, to: replacement)
    try Task.checkCancellation()
    if exists {
      _ = try manager.replaceItemAt(databasesDirectory, withItemAt: replacement)
    } else {
      try manager.moveItem(at: replacement, to: databasesDirectory)
    }
  }

  private func overlayDatabases(from source: URL, to destination: URL) throws {
    let manager = FileManager.default
    for child in try manager.contentsOfDirectory(
      at: source, includingPropertiesForKeys: [.isDirectoryKey])
    {
      try Task.checkCancellation()
      let target = destination.appendingPathComponent(child.lastPathComponent)
      let values = try child.resourceValues(forKeys: [.isDirectoryKey])
      if values.isDirectory == true {
        if manager.fileExists(atPath: target.path) {
          try Self.validateDirectory(target)
        }
        try manager.createDirectory(at: target, withIntermediateDirectories: true)
        try overlayDatabases(from: child, to: target)
      } else {
        for suffix in ["", "-wal", "-shm", "-journal"] {
          let old = URL(fileURLWithPath: target.path + suffix)
          if manager.fileExists(atPath: old.path) {
            try manager.removeItem(at: old)
          }
        }
        try manager.copyItem(at: child, to: target)
      }
    }
  }

  private func collectEntries(_ mappings: [(source: URL, destination: String)]) throws
    -> [ArchiveEntry]
  {
    let manager = FileManager.default
    var entries = [ArchiveEntry]()
    for mapping in mappings {
      var isDirectory: ObjCBool = false
      guard manager.fileExists(atPath: mapping.source.path, isDirectory: &isDirectory),
        isDirectory.boolValue
      else {
        continue
      }
      entries.append(
        ArchiveEntry(sourceURL: nil, archivePath: mapping.destination, isDirectory: true))
      guard
        let enumerator = manager.enumerator(
          at: mapping.source, includingPropertiesForKeys: [.isDirectoryKey])
      else {
        continue
      }
      for case let url as URL in enumerator {
        try Task.checkCancellation()
        let values = try url.resourceValues(forKeys: [.isDirectoryKey])
        let directory = values.isDirectory == true
        let base = (mapping.source.path as NSString).standardizingPath + "/"
        let path = (url.path as NSString).standardizingPath
        guard path.hasPrefix(base) else { continue }
        entries.append(
          ArchiveEntry(
            sourceURL: directory ? nil : url,
            archivePath: mapping.destination + path.dropFirst(base.count) + (directory ? "/" : ""),
            isDirectory: directory))
      }
    }
    return entries
  }

  private func addDirectory(_ path: String, to archive: Archive) throws {
    try archive.addEntry(
      with: path, type: .directory, uncompressedSize: Int64(0), provider: { _, _ in Data() })
  }

  private func extract(_ entry: Entry, from archive: Archive, root: URL, prefix: String) throws {
    try Task.checkCancellation()
    let relativePath = String(entry.path.dropFirst(prefix.count))
    let destination = try Self.destinationURL(root: root, relativePath: relativePath)
    let manager = FileManager.default
    switch entry.type {
    case .directory:
      var directory: ObjCBool = false
      if manager.fileExists(atPath: destination.path, isDirectory: &directory), !directory.boolValue
      {
        try manager.removeItem(at: destination)
      }
      try manager.createDirectory(at: destination, withIntermediateDirectories: true)
    case .file:
      guard destination != root else { throw InvalidZipError() }
      try manager.createDirectory(
        at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
      if manager.fileExists(atPath: destination.path) {
        try manager.removeItem(at: destination)
      }
      _ = try archive.extract(entry, to: destination)
    case .symlink:
      break
    }
  }

  private static func destinationURL(root: URL, relativePath: String) throws -> URL {
    guard !relativePath.hasPrefix("/"), !relativePath.contains("\\") else {
      throw InvalidZipError()
    }
    var destination = root
    for component in relativePath.split(separator: "/", omittingEmptySubsequences: true) {
      guard component != "." && component != ".." else { throw InvalidZipError() }
      destination.appendPathComponent(String(component))
    }
    let rootPath = (root.path as NSString).standardizingPath
    let destinationPath = (destination.path as NSString).standardizingPath
    guard destinationPath == rootPath || destinationPath.hasPrefix(rootPath + "/") else {
      throw InvalidZipError()
    }
    return destination
  }
}
