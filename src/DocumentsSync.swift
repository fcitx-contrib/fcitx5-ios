import CryptoKit
import Foundation

/// Serializes main-app imports and file synchronization, including their durable baseline.
final class DocumentsSync: @unchecked Sendable {
  private let documents: URL
  private let destination: URL
  private let stateURL: URL
  private let lock = NSLock()

  init(documents: URL, destination: URL, stateURL: URL) {
    self.documents = documents.standardizedFileURL.resolvingSymlinksInPath()
    self.destination = destination.standardizedFileURL.resolvingSymlinksInPath()
    self.stateURL = stateURL
  }

  @discardableResult
  func synchronize() throws -> Bool {
    lock.lock()
    defer { lock.unlock() }
    guard documents != destination else { return false }
    return try synchronizeFiles()
  }

  func importData(using archive: BackupArchive, from url: URL, source: ImportSource) throws {
    lock.lock()
    defer { lock.unlock() }
    try archive.importData(from: url, source: source) { file in
      guard self.documents != self.destination else { return }
      // Invalidate only the file whose extraction is starting. Unreached files keep
      // their baselines after an error, while identical extracted files remain authoritative.
      var checksums = try self.loadChecksums()
      if checksums.removeValue(forKey: try self.relativePath(file)) != nil {
        // Persist before touching the file so failed copies remain eligible for retry.
        try self.saveChecksums(checksums)
      }
    }
    if documents != destination {
      _ = try synchronizeFiles()
    }
  }

  private func relativePath(_ url: URL) throws -> String {
    let prefix = documents.path + "/"
    let path = url.standardizedFileURL.resolvingSymlinksInPath().path
    guard path.hasPrefix(prefix) else {
      throw CocoaError(.fileReadInvalidFileName)
    }
    return String(path.dropFirst(prefix.count))
  }

  private func loadChecksums() throws -> [String: String] {
    guard FileManager.default.fileExists(atPath: stateURL.path) else { return [:] }
    // Do not treat an unreadable baseline as a first sync and overwrite runtime edits.
    return try JSONDecoder().decode([String: String].self, from: Data(contentsOf: stateURL))
  }

  private func saveChecksums(_ checksums: [String: String]) throws {
    try FileManager.default.createDirectory(
      at: stateURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try JSONEncoder().encode(checksums).write(to: stateURL, options: .atomic)
  }

  private func synchronizeFiles() throws -> Bool {
    let manager = FileManager.default
    let previous = try loadChecksums()
    var checksums = [String: String]()
    var changed = false

    func copy(_ source: URL, to target: URL) throws {
      try Task.checkCancellation()
      let values = try source.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
      guard values.isSymbolicLink != true else { throw CocoaError(.fileReadInvalidFileName) }
      var contents = Data()
      if values.isDirectory != true {
        let path = try relativePath(source)
        let data = try Data(contentsOf: source, options: .mappedIfSafe)
        let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        checksums[path] = hash
        guard previous[path] != hash else { return }
        contents = data
      }
      if manager.fileExists(atPath: target.path) {
        let targetValues = try target.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard targetValues.isSymbolicLink != true else {
          throw CocoaError(.fileWriteInvalidFileName)
        }
        if values.isDirectory != targetValues.isDirectory {
          // A directory may contain unchanged files; preserve a runtime type change.
          guard values.isDirectory != true else { throw CocoaError(.fileWriteFileExists) }
          try manager.removeItem(at: target)
        }
      }
      if values.isDirectory == true {
        try manager.createDirectory(at: target, withIntermediateDirectories: true)
        for child in try manager.contentsOfDirectory(at: source, includingPropertiesForKeys: nil) {
          try copy(child, to: target.appendingPathComponent(child.lastPathComponent))
        }
      } else {
        try contents.write(to: target, options: .atomic)
        changed = true
      }
    }

    for directory in ["data", "config"] {
      let source = documents.appendingPathComponent(directory)
      if manager.fileExists(atPath: source.path) {
        try copy(source, to: destination.appendingPathComponent(directory))
      }
    }
    // Missing Documents files are forgotten, without deleting their runtime copies.
    try saveChecksums(checksums)
    return changed
  }
}
