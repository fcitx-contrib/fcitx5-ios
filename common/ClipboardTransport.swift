import Foundation

public enum ClipboardTransport {
  public enum Failure: Error {
    case serverRejected(Int)
    case invalidResponse
  }

  /// Independent of the Sync config UI so future clipboard editing can reuse it.
  public static func synchronize(store: ClipboardStore, endpoint: URL) async throws {
    repeat {
      try Task.checkCancellation()
      let request = try await Task.detached { try store.prepareSync() }.value
      var http = URLRequest(url: endpoint)
      http.httpMethod = "POST"
      http.timeoutInterval = 30
      http.setValue("application/json", forHTTPHeaderField: "Content-Type")
      http.httpBody = try JSONEncoder().encode(request)
      let (data, response) = try await URLSession.shared.data(for: http)
      guard let response = response as? HTTPURLResponse else { throw Failure.invalidResponse }
      guard response.statusCode == 200 else { throw Failure.serverRejected(response.statusCode) }
      let result = try JSONDecoder().decode(ClipboardSyncResponse.self, from: data)
      try Task.checkCancellation()
      try await Task.detached { try store.apply(result) }.value
      // Local edits made while the request was in flight have been rebased, not lost.
      if try await Task.detached(operation: { try store.hasPendingChanges() }).value == false {
        return
      }
    } while !Task.isCancelled
    throw CancellationError()
  }
}
