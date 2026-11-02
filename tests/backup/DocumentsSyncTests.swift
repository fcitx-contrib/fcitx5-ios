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
  func zip(_ name: String, entries: [(String, String)]) throws -> URL {
    let url = base.appendingPathComponent(name)
    let archive = try Archive(url: url, accessMode: .create)
    for (path, text) in [("metadata.json", "{}")] + entries {
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
