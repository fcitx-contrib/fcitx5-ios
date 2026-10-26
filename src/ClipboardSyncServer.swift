import Foundation
import Swifter

// The app imports these types from SwiftUtil; macOS tests compile their source
// files directly into the test module, where no SwiftUtil import is needed.
#if canImport(SwiftUtil)
  import SwiftUtil
#endif

enum ClipboardSyncServer {
  static func handle(_ request: HttpRequest, store: ClipboardStore) -> HttpResponse {
    guard
      let changes = try? JSONDecoder().decode(ClipboardSyncRequest.self, from: Data(request.body))
    else {
      return .badRequest(nil)
    }
    do {
      let result = try store.merge(changes)
      let data = try JSONEncoder().encode(result)
      return .raw(200, "OK", ["Content-Type": "application/json"], { try $0.write(data) })
    } catch ClipboardStore.Failure.invalidSync {
      return .badRequest(nil)
    } catch {
      return .internalServerError(nil)
    }
  }
}
