import Combine
import Foundation

/// Keeps configuration editing paused until queued file work, runtime reloads and UI refreshes finish.
@MainActor
final class ConfigurationSync: ObservableObject {
  @Published private(set) var isSynchronizing = false
  let didFinish = PassthroughSubject<Void, Never>()

  private let onReload: () -> Void
  private var tail: Task<Void, Never>?
  private var pending = 0
  private var deferredActions = [() -> Void]()

  init(onReload: @escaping () -> Void = {}) {
    self.onReload = onReload
  }

  /// Work returns true only after its changed files have been loaded by the runtime.
  func start(_ work: @escaping @Sendable () throws -> Bool) -> Task<Bool, Error> {
    pending += 1
    isSynchronizing = true
    let previous = tail
    let worker = Task.detached(priority: .userInitiated) {
      await previous?.value
      try Task.checkCancellation()
      return try work()
    }
    let completion = Task {
      defer {
        pending -= 1
        if pending == 0 {
          tail = nil
          isSynchronizing = false
          let actions = deferredActions
          deferredActions.removeAll()
          for action in actions { whenReady(action) }
        }
      }
      let result = await withTaskCancellationHandler {
        await worker.result
      } onCancel: {
        worker.cancel()
      }
      if case .success(true) = result {
        onReload()
      }
      // Also initialize views opened while an unchanged or failed operation was pending.
      // Subscribers refresh synchronously on the main actor before editing resumes.
      didFinish.send()
      return try result.get()
    }
    tail = Task { _ = await completion.result }
    return completion
  }

  func perform(_ work: @escaping @Sendable () throws -> Bool) async throws {
    let operation = start(work)
    _ = try await withTaskCancellationHandler {
      try await operation.value
    } onCancel: {
      operation.cancel()
    }
  }

  func whenReady(_ action: @escaping () -> Void) {
    if isSynchronizing {
      deferredActions.append(action)
    } else {
      action()
    }
  }
}
