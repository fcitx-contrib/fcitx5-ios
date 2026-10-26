import Foundation
import GRDB

public struct ClipboardSyncRequest: Codable, Sendable, Equatable {
  public let id: UUID
  public let clientID: UUID
  public let baseline: [ClipboardSyncEntry]
  public let entries: [ClipboardSyncEntry]
}

public struct ClipboardSyncResponse: Codable, Sendable {
  public let requestID: UUID
  public let entries: [ClipboardSyncEntry]
  public let aliases: [UUID: UUID]
}

extension ClipboardStore {
  /// Persist before sending: a killed process retries exactly the same request.
  public func prepareSync() throws -> ClipboardSyncRequest {
    try database().write { db in
      if let pending: ClipboardSyncRequest = try Self.state("pending", in: db) { return pending }
      let baseline: [ClipboardSyncEntry] = try Self.state("baseline", in: db) ?? []
      let clientID: UUID = try Self.state("clientID", in: db) ?? UUID()
      try Self.saveState(clientID, key: "clientID", in: db)
      let request = ClipboardSyncRequest(
        id: UUID(), clientID: clientID, baseline: baseline, entries: try Self.entries(db))
      try Self.saveState(request, key: "pending", in: db)
      return request
    }
  }

  /// Main-app authority: accept unilateral edits; resolve concurrent changes in favor of main.
  public func merge(_ request: ClipboardSyncRequest) throws -> ClipboardSyncResponse {
    guard Set(request.entries.map(\.id)).count == request.entries.count,
      Set(request.baseline.map(\.id)).count == request.baseline.count
    else { throw Failure.invalidSync }
    return try database().write { db in
      let requestKey = "client-\(request.clientID)"
      if let completed: ClipboardSyncResponse = try Self.state(requestKey, in: db),
        completed.requestID == request.id
      {
        // Replay the acknowledgement, not stale data from before a subsequent import/edit.
        return ClipboardSyncResponse(
          requestID: request.id, entries: try Self.entries(db), aliases: completed.aliases)
      }
      var main = try Self.entries(db)
      let baseline = Dictionary(uniqueKeysWithValues: request.baseline.map { ($0.id, $0) })
      var incoming = request.entries
      let incomingIDs = Set(incoming.map(\.id))
      // Usually deletion is a tombstone. Also accept removal relative to a known baseline.
      for var removed in request.baseline where !incomingIDs.contains(removed.id) {
        removed.record.deleted = true
        incoming.append(removed)
      }
      var aliases = [UUID: UUID]()
      for entry in incoming {
        let index =
          main.firstIndex { $0.id == entry.id }
          ?? main.firstIndex { $0.record.text == entry.record.text && !$0.record.deleted }
          ?? main.firstIndex { $0.record.text == entry.record.text }
        if let index {
          let current = main[index]
          aliases[entry.id] = current.id
          if let base = baseline[entry.id] ?? baseline[current.id], current.id == base.id,
            current.hasSameContent(as: base)
          {
            // An edit must not introduce duplicate active text either.
            if !entry.record.deleted,
              main.contains(where: {
                $0.id != current.id && !$0.record.deleted && $0.record.text == entry.record.text
              })
            {
              continue
            }
            var changed = entry.record
            changed.id = current.record.id
            try changed.update(db)
            main[index].record = changed
          }
        } else if baseline[entry.id] == nil {
          try Self.insert(entry, in: db)
          main.append(entry)
          aliases[entry.id] = entry.id
        }
        // A known identity absent from main was removed by import: do not resurrect it.
      }
      let response = ClipboardSyncResponse(
        requestID: request.id, entries: try Self.entries(db), aliases: aliases)
      try Self.saveState(response, key: requestKey, in: db)
      return response
    }
  }

  /// Replace from the server, then rebase edits made locally while HTTP was in flight.
  public func apply(_ response: ClipboardSyncResponse) throws {
    guard Set(response.entries.map(\.id)).count == response.entries.count else {
      throw Failure.invalidSync
    }
    try database().write { db in
      guard let request: ClipboardSyncRequest = try Self.state("pending", in: db),
        request.id == response.requestID
      else { throw Failure.invalidSync }
      let sent = Dictionary(uniqueKeysWithValues: request.entries.map { ($0.id, $0) })
      let local = try Self.entries(db)
      var result = response.entries
      for changed in local {
        if let previous = sent[changed.id], changed.hasSameContent(as: previous) { continue }
        let canonicalID = response.aliases[changed.id] ?? changed.id
        if sent[changed.id] != nil,
          response.aliases[changed.id] != nil
            || request.baseline.contains(where: { $0.id == changed.id }),
          !response.entries.contains(where: { $0.id == canonicalID })
        {
          continue
        }  // Main removed this known identity, e.g. by importing another backup.
        if let index = result.firstIndex(where: { $0.id == canonicalID }) {
          result[index].record = changed.record
        } else if let index = result.firstIndex(where: {
          !$0.record.deleted && $0.record.text == changed.record.text
        }) {
          // Preserve local changes without creating duplicate text under a new identity.
          result[index].record = changed.record
        } else {
          result.append(changed)
        }
      }
      try Self.replace(result, in: db)
      try Self.saveState(response.entries, key: "baseline", in: db)
      _ = try ClipboardState.deleteOne(db, key: "pending")
    }
  }

  public func hasPendingChanges() throws -> Bool {
    try database().read { db in
      let baseline: [ClipboardSyncEntry] = try Self.state("baseline", in: db) ?? []
      let entries = try Self.entries(db)
      let base = Dictionary(uniqueKeysWithValues: baseline.map { ($0.id, $0) })
      return base.count != entries.count
        || entries.contains { entry in
          guard let previous = base[entry.id] else { return true }
          return !previous.hasSameContent(as: entry)
        }
    }
  }
}
