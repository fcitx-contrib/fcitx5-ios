import Combine
import Dispatch
import Foundation

private struct ConfigurationSyncFailure: Error { let message: String }

private func require(_ value: @autoclosure () -> Bool, _ message: String) throws {
  if !value() { throw ConfigurationSyncFailure(message: message) }
}

private final class SyncGate: @unchecked Sendable {
  let started = DispatchSemaphore(value: 0)
  let release = DispatchSemaphore(value: 0)

  func block() throws {
    started.signal()
    guard release.wait(timeout: .now() + 10) == .success else {
      throw ConfigurationSyncFailure(message: "Timed out waiting for the test to release work")
    }
  }

  func waitUntilStarted() async throws {
    let result = await Task.detached { self.waitForStart() }.value
    try require(result == .success, "Queued work never started")
  }

  private func waitForStart() -> DispatchTimeoutResult {
    started.wait(timeout: .now() + 10)
  }
}

private final class SyncEvents: @unchecked Sendable {
  private let lock = NSLock()
  private var values = [String]()

  func append(_ value: String) {
    lock.lock()
    defer { lock.unlock() }
    values.append(value)
  }

  var snapshot: [String] {
    lock.lock()
    defer { lock.unlock() }
    return values
  }
}

@MainActor
func testConfigurationSync() async throws {
  let events = SyncEvents()
  let sync = ConfigurationSync(onReload: { events.append("notify") })
  let copy = SyncGate()
  let reload = SyncGate()
  let queued = SyncGate()
  var enabled = ["A"]
  var available = ["B", "C"]
  var saved: [String]?
  var refreshesWhileBusy = 0
  let subscription = sync.didFinish.sink {
    if sync.isSynchronizing { refreshesWhileBusy += 1 }
    enabled = ["A", "B"]
    available = ["C"]
    events.append("refresh")
  }
  defer { subscription.cancel() }

  let first = sync.start {
    try copy.block()
    events.append("copy")
    try reload.block()
    events.append("reload completed")
    return true
  }
  try require(sync.isSynchronizing, "Editing is paused before background work is dispatched")
  sync.whenReady {
    saved = enabled + ["C"]
    events.append("edit")
  }
  try await copy.waitUntilStarted()
  try require(saved == nil, "An edit must not run during the copy")
  copy.release.signal()
  try await reload.waitUntilStarted()
  try require(
    sync.isSynchronizing && enabled == ["A"], "Keep editing paused through runtime reload")

  let second = sync.start {
    events.append("second copy")
    try queued.block()
    return false
  }
  reload.release.signal()
  _ = try await first.value
  try await queued.waitUntilStarted()
  try require(sync.isSynchronizing && saved == nil, "Queued work must not briefly enable editing")
  try require(enabled == ["A", "B"] && available == ["C"], "Refresh both input-method lists")
  try require(
    events.snapshot == ["copy", "reload completed", "notify", "refresh", "second copy"],
    "Refresh must finish before the next copy begins")
  queued.release.signal()
  _ = try await second.value
  try require(!sync.isSynchronizing, "Editing resumes after all queued operations finish")
  try require(saved == ["A", "B", "C"], "The deferred edit must preserve synchronized methods")
  try require(
    refreshesWhileBusy == 2, "Refresh views before allowing edits, even after unchanged work")
  try require(
    events.snapshot.filter { $0 == "notify" }.count == 1, "Unchanged work needs no reload")

  var resumedAfterFailure = false
  let failed = sync.start { throw ConfigurationSyncFailure(message: "Expected copy failure") }
  sync.whenReady { resumedAfterFailure = true }
  if case .success = await failed.result {
    throw ConfigurationSyncFailure(message: "Expected operation failure")
  }
  try require(!sync.isSynchronizing && resumedAfterFailure, "Failure must release pending edits")

  let holding = SyncGate()
  let beforeCancellation = sync.start {
    try holding.block()
    return false
  }
  try await holding.waitUntilStarted()
  let cancelled = sync.start {
    events.append("cancelled work ran")
    return true
  }
  cancelled.cancel()
  holding.release.signal()
  _ = try await beforeCancellation.value
  switch await cancelled.result {
  case .failure(is CancellationError): break
  default: throw ConfigurationSyncFailure(message: "Queued cancellation was not propagated")
  }
  try require(!sync.isSynchronizing, "Cancelled queued work must release the editing gate")
  try require(!events.snapshot.contains("cancelled work ran"), "Do not run cancelled queued work")

  let importing = SyncGate()
  let caller = Task {
    try await sync.perform {
      try importing.block()
      try Task.checkCancellation()
      return true
    }
  }
  try await importing.waitUntilStarted()
  caller.cancel()
  importing.release.signal()
  switch await caller.result {
  case .failure(is CancellationError): break
  default: throw ConfigurationSyncFailure(message: "Import cancellation did not reach file work")
  }
  try require(!sync.isSynchronizing, "Cancelled imports must not leave editing disabled")
  print(
    "PASS configuration sync serialization, reload completion, refreshed edits, failure and cancellation"
  )
}
