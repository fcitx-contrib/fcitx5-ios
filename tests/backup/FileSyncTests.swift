import Foundation

private struct FileSyncFailure: Error { let message: String }

private func require(_ condition: @autoclosure () throws -> Bool, _ message: String) throws {
  if try !condition() { throw FileSyncFailure(message: message) }
}

func testFileSync(root: URL) throws {
  let manager = FileManager.default
  let base = root.appendingPathComponent("file-sync")
  let source = base.appendingPathComponent("Documents/data")
  let target = base.appendingPathComponent("AppGroup/data")
  let nested = "inputmethod/customized.conf"
  func write(_ text: String, to file: URL) throws {
    try manager.createDirectory(
      at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data(text.utf8).write(to: file)
  }

  var changed = false
  try require(!sync(source, target, changed: &changed), "Missing source fails")
  try require(!changed, "Missing source reports no file changes")
  try write("Name=Custom", to: source.appendingPathComponent(nested))
  try require(sync(source, target, changed: &changed), "Initial nested copy succeeds")
  try require(changed, "Initial copy reports a change")

  let oldDate = Date(timeIntervalSince1970: 1_000_000)
  try manager.setAttributes(
    [.modificationDate: oldDate], ofItemAtPath: target.appendingPathComponent(nested).path)
  changed = false
  try require(sync(source, target, changed: &changed), "Unchanged recursive copy still succeeds")
  try require(!changed, "Success does not imply a file changed")
  try require(
    try manager.attributesOfItem(atPath: target.appendingPathComponent(nested).path)[
      .modificationDate]
      as? Date == oldDate, "Unchanged file is not rewritten")

  try write("Name=Updated", to: source.appendingPathComponent(nested))
  try require(sync(source, target, changed: &changed), "Changed recursive copy succeeds")
  try require(changed, "A nested edit is reported to the caller")
  try require(
    try String(contentsOf: target.appendingPathComponent(nested), encoding: .utf8)
      == "Name=Updated",
    "Changed contents reach the target")
  try require(sync(source, target, changed: &changed), "A second unchanged root succeeds")
  try require(changed, "An unchanged copy must not clear an earlier change")

  try write("runtime only", to: target.appendingPathComponent("runtime-only"))
  changed = false
  try require(sync(source, target, changed: &changed), "Destination-only files are allowed")
  try require(!changed, "Destination-only files do not trigger a reload")
  try require(
    try String(contentsOf: target.appendingPathComponent("runtime-only"), encoding: .utf8)
      == "runtime only", "Preserve destination-only files")

  let blocker = base.appendingPathComponent("blocked")
  try write("not a directory", to: blocker)
  changed = false
  try require(
    !sync(source, blocker.appendingPathComponent("data"), changed: &changed),
    "Copy failure is reported")
  try require(!changed, "A failed file copy does not report a successful change")

  // Data can succeed before config fails; callers must require both success and a change.
  try write("Name=Partial", to: source.appendingPathComponent(nested))
  var success = sync(source, target, changed: &changed)
  try require(success && changed, "The first directory can change successfully")
  if !sync(source, blocker.appendingPathComponent("config"), changed: &changed) {
    success = false
  }
  try require(
    !success && changed, "Partial failure remains distinguishable from a successful change")
  print("PASS file sync: changed, unchanged, recursive, accumulated and failed-copy results")
}
