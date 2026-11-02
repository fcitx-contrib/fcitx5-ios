import Foundation
import ZIPFoundation

private struct DocumentsSyncFailure: Error { let message: String }

private func require(_ condition: @autoclosure () throws -> Bool, _ message: String) throws {
  if try !condition() { throw DocumentsSyncFailure(message: message) }
}

func testDocumentsSync(root: URL) throws {
  let manager = FileManager.default
  let base = root.appendingPathComponent("documents-sync")
  let documents = base.appendingPathComponent("Documents")
  let group = base.appendingPathComponent("AppGroup")
  let state = base.appendingPathComponent("Library/documents-sync.json")
  func synchronizer(destination: URL? = nil) -> DocumentsSync {
    DocumentsSync(documents: documents, destination: destination ?? group, stateURL: state)
  }
  func write(_ text: String, _ url: URL) throws {
    try manager.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data(text.utf8).write(to: url)
  }
  func read(_ url: URL) throws -> String {
    try String(contentsOf: url, encoding: .utf8)
  }
  func zip(_ name: String, entries: [(String, String)], databaseArchive: URL? = nil) throws -> URL {
    let url = base.appendingPathComponent(name)
    if let databaseArchive { try manager.copyItem(at: databaseArchive, to: url) }
    let archive = try Archive(url: url, accessMode: databaseArchive == nil ? .create : .update)
    let metadata = databaseArchive == nil ? [("metadata.json", "{}")] : []
    for (path, text) in metadata + entries {
      let data = Data(text.utf8)
      try archive.addEntry(
        with: path, type: .file, uncompressedSize: Int64(data.count),
        provider: { position, size in
          data.subdata(in: Int(position)..<min(Int(position) + size, data.count))
        })
    }
    return url
  }
  let importer = BackupArchive(
    configDirectory: documents.appendingPathComponent("config"),
    dataDirectory: documents.appendingPathComponent("data"),
    databasesDirectory: group.appendingPathComponent("databases"))
  let config = "config/conf/test.conf"
  let rime = "data/rime/default.custom.yaml"
  let table = "data/inputmethod/customized.conf"
  for path in [config, rime, table] {
    try write("original", documents.appendingPathComponent(path))
  }
  try write("runtime only", group.appendingPathComponent("config/runtime-only"))
  try require(try synchronizer().synchronize(), "Initial copy requests a reload")
  for path in [config, rime, table] {
    try require(try read(group.appendingPathComponent(path)) == "original", "Initial copy: \(path)")
  }

  try write("edited in app", group.appendingPathComponent(config))
  try manager.removeItem(at: group.appendingPathComponent(table))
  // A fresh instance exercises the on-disk baseline, as on relaunch.
  try require(try !synchronizer().synchronize(), "Unchanged Documents do not request a reload")
  try require(try read(group.appendingPathComponent(config)) == "edited in app", "Keep app edits")
  try require(
    !manager.fileExists(atPath: group.appendingPathComponent(table).path), "Keep deletions")
  try write("edited in Files", documents.appendingPathComponent(config))
  try synchronizer().synchronize()
  try require(
    try read(group.appendingPathComponent(config)) == "edited in Files", "Apply source edit")

  let archive = try zip(
    "import.zip", entries: [("external/" + config, "imported"), ("external/" + table, "table")])
  try synchronizer().importData(using: importer, from: archive, source: .fcitx5)
  for storage in [documents, group] {
    try require(
      try read(storage.appendingPathComponent(config)) == "imported", "ZIP config mapping")
    try require(try read(storage.appendingPathComponent(table)) == "table", "ZIP table mapping")
  }
  try write("edited after import", group.appendingPathComponent(config))
  try synchronizer().synchronize()
  try require(
    try read(group.appendingPathComponent(config)) == "edited after import", "No stale ZIP replay")
  try synchronizer().importData(using: importer, from: archive, source: .fcitx5)
  try require(
    try read(group.appendingPathComponent(config)) == "imported", "Identical ZIP overrides")

  let hamster = try zip(
    "hamster.zip", entries: [("HamsterBackup/RIME/Rime/default.custom.yaml", "rime")])
  try synchronizer().importData(using: importer, from: hamster, source: .hamster)
  for storage in [documents, group] {
    try require(
      try read(storage.appendingPathComponent(rime)) == "rime", "Hamster data/rime mapping")
  }

  let exported = base.appendingPathComponent("export.zip")
  try write("latest runtime config", group.appendingPathComponent(config))
  let exporter = BackupArchive(
    configDirectory: group.appendingPathComponent("config"),
    dataDirectory: group.appendingPathComponent("data"),
    databasesDirectory: group.appendingPathComponent("databases"))
  try exporter.export(to: exported, date: Date())
  let restored = base.appendingPathComponent("exported")
  try BackupArchive(
    configDirectory: restored.appendingPathComponent("config"),
    dataDirectory: restored.appendingPathComponent("data"),
    databasesDirectory: restored.appendingPathComponent("databases")
  ).importData(from: exported, source: .fcitx5)
  try require(
    try read(restored.appendingPathComponent(config)) == "latest runtime config",
    "Export reads runtime config")
  try require(
    try read(group.appendingPathComponent("config/runtime-only")) == "runtime only",
    "Preserve destination-only files")

  let liveClipboard = ClipboardStore(directory: group.appendingPathComponent("databases"))
  try liveClipboard.capture("before import")
  let inode =
    try manager.attributesOfItem(atPath: liveClipboard.databaseURL.path)[.systemFileNumber]
    as? NSNumber
  let incomingClipboard = ClipboardStore(
    directory: base.appendingPathComponent("incoming-databases"))
  try incomingClipboard.capture("from ZIP")
  let databaseZip = base.appendingPathComponent("database.zip")
  try BackupArchive(
    configDirectory: base.appendingPathComponent("incoming-config"),
    dataDirectory: base.appendingPathComponent("incoming-data"),
    databasesDirectory: incomingClipboard.databaseURL.deletingLastPathComponent(),
    clipboardStore: incomingClipboard
  ).export(to: databaseZip, date: Date())
  let liveImporter = BackupArchive(
    configDirectory: documents.appendingPathComponent("config"),
    dataDirectory: documents.appendingPathComponent("data"),
    databasesDirectory: liveClipboard.databaseURL.deletingLastPathComponent(),
    clipboardStore: liveClipboard)
  try synchronizer().importData(using: liveImporter, from: databaseZip, source: .fcitx5)
  try require(
    try liveClipboard.entries().filter { !$0.record.deleted }.map { $0.record.text } == [
      "from ZIP"
    ],
    "Import clipboard into live App Group store")
  try require(
    try manager.attributesOfItem(atPath: liveClipboard.databaseURL.path)[.systemFileNumber]
      as? NSNumber == inode, "Do not replace live clipboard inode")
  try require(
    !manager.fileExists(atPath: documents.appendingPathComponent("databases").path),
    "Do not copy the shared database into Documents")

  for extractionFailure in [true, false] {
    let failureRoot = base.appendingPathComponent("import-failure-\(extractionFailure)")
    let failureDocs = failureRoot.appendingPathComponent("Documents")
    let failureGroup = failureRoot.appendingPathComponent("AppGroup")
    let failureState = failureRoot.appendingPathComponent("state.json")
    func failureSync() -> DocumentsSync {
      DocumentsSync(documents: failureDocs, destination: failureGroup, stateURL: failureState)
    }
    let processed = "config/processed.conf"
    let later = "config/later.conf"
    for path in [processed, later] {
      try write("original", failureDocs.appendingPathComponent(path))
    }
    try failureSync().synchronize()
    for path in [processed, later] {
      try write("runtime edit", failureGroup.appendingPathComponent(path))
    }
    var entries = [("external/" + processed, "original")]
    if extractionFailure {
      try write("not a directory", failureDocs.appendingPathComponent("config/blocker"))
      entries.append(("external/config/blocker/failed.conf", "new contents"))
    } else {
      // Database validation fails after all configuration files have been extracted.
      try write("not a directory", failureGroup.appendingPathComponent("databases"))
    }
    entries.append(("external/" + later, "original"))
    let failedZip = try zip(
      "import-failure-\(extractionFailure).zip", entries: entries,
      databaseArchive: extractionFailure ? nil : databaseZip)
    let failureImporter = BackupArchive(
      configDirectory: failureDocs.appendingPathComponent("config"),
      dataDirectory: failureDocs.appendingPathComponent("data"),
      databasesDirectory: failureGroup.appendingPathComponent("databases"))
    var importFailed = false
    do {
      try failureSync().importData(using: failureImporter, from: failedZip, source: .fcitx5)
    } catch { importFailed = true }
    try require(importFailed, "Expected an import failure")
    let checksums = try JSONDecoder().decode(
      [String: String].self, from: Data(contentsOf: failureState))
    try require(checksums[processed] == nil, "An identical extracted file must stay invalidated")
    try require(
      (checksums[later] != nil) == extractionFailure,
      "Keep baselines only for files whose extraction never started")
    try failureSync().synchronize()
    try require(
      try read(failureGroup.appendingPathComponent(processed)) == "original",
      "Retry the identical file that was already extracted")
    try require(
      try read(failureGroup.appendingPathComponent(later))
        == (extractionFailure ? "runtime edit" : "original"),
      "Preserve unextracted runtime edits; retry extracted files after a database failure")
  }

  // A failed authoritative copy remains pending even if the source hash is unchanged.
  let blocked = group.appendingPathComponent("config/conf")
  let saved = group.appendingPathComponent("saved-conf")
  try manager.moveItem(at: blocked, to: saved)
  try manager.createSymbolicLink(at: blocked, withDestinationURL: saved)
  var failed = false
  do {
    try synchronizer().importData(using: importer, from: archive, source: .fcitx5)
  } catch { failed = true }
  try require(failed, "Copy failure must propagate")
  try manager.removeItem(at: blocked)
  try manager.moveItem(at: saved, to: blocked)
  try synchronizer().synchronize()
  try require(
    try read(group.appendingPathComponent(config)) == "imported", "Retry failed import copy")

  try write("private edit", documents.appendingPathComponent(config))
  try synchronizer(destination: documents).synchronize()
  try require(try read(documents.appendingPathComponent(config)) == "private edit", "No self-copy")
  let privateImporter = BackupArchive(
    configDirectory: documents.appendingPathComponent("config"),
    dataDirectory: documents.appendingPathComponent("data"),
    databasesDirectory: documents.appendingPathComponent("databases"))
  try synchronizer(destination: documents).importData(
    using: privateImporter, from: archive, source: .fcitx5)
  try require(
    try read(documents.appendingPathComponent(config)) == "imported", "Private ZIP import")

  try write("{broken", state)
  try write("pending Files edit", documents.appendingPathComponent(config))
  failed = false
  do { try synchronizer().synchronize() } catch { failed = true }
  try require(failed, "Corrupt state must not silently reset")
  try require(
    try read(group.appendingPathComponent(config)) == "imported", "Keep runtime on failure")
  print(
    "PASS Documents sync, durable baseline, ZIP/Hamster imports, retries, export and private mode")
}
