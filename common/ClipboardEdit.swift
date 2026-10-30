import Foundation
import GRDB

public struct ClipboardEditRequest: Identifiable, Sendable {
  public let entry: ClipboardSyncEntry
  public var id: UUID { entry.id }
  public var text: String { entry.record.text }

  public init(entry: ClipboardSyncEntry) {
    self.entry = entry
  }

  public init?(url: URL) {
    guard url.scheme == "fcitx", url.host == "clipboard", url.path == "/edit",
      let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
    else { return nil }
    func value(_ name: String) -> String? {
      components.queryItems?.first(where: { $0.name == name })?.value
    }
    guard let identity = value("id").flatMap(UUID.init(uuidString:)), let text = value("text")
    else { return nil }
    var record = ClipboardRecord(text: text)
    // Metadata is needed when the private main database has never received this entry.
    if let timestamp = value("timestamp") {
      guard let timestamp = Int64(timestamp) else { return nil }
      record.timestamp = timestamp
    }
    for name in ["pinned", "sensitive"] {
      if let flag = value(name), flag != "0" && flag != "1" { return nil }
    }
    record.pinned = value("pinned") == "1"
    record.sensitive = value("sensitive") == "1"
    record.type = value("type") ?? record.type
    entry = ClipboardSyncEntry(id: identity, record: record)
  }

  public var url: URL {
    var components = URLComponents()
    components.scheme = "fcitx"
    components.host = "clipboard"
    components.path = "/edit"
    components.queryItems = [
      URLQueryItem(name: "id", value: id.uuidString),
      URLQueryItem(name: "text", value: text),
      URLQueryItem(name: "timestamp", value: String(entry.record.timestamp)),
      URLQueryItem(name: "pinned", value: entry.record.pinned ? "1" : "0"),
      URLQueryItem(name: "sensitive", value: entry.record.sensitive ? "1" : "0"),
      URLQueryItem(name: "type", value: entry.record.type),
    ]
    return components.url!
  }
}

extension ClipboardStore {
  public enum EditFailure: Error {
    case missingEntry
    case emptyText
    case duplicateText
  }

  /// Save in main's transaction; private stores reconcile through the normal sync protocol.
  public func edit(_ request: ClipboardEditRequest, text: String, allowInsert: Bool) throws {
    guard text.contains(where: { !$0.isWhitespace }) else { throw EditFailure.emptyText }
    try database().write { db in
      let entries = try Self.entries(db)
      let identified = entries.first { $0.id == request.id }
      if identified?.record.deleted == true { throw EditFailure.missingEntry }
      let current =
        identified
        ?? (allowInsert
          ? entries.first { !$0.record.deleted && $0.record.text == request.text } : nil)
      guard current != nil || allowInsert else { throw EditFailure.missingEntry }
      guard
        !entries.contains(where: {
          !$0.record.deleted && $0.id != current?.id && $0.record.text == text
        })
      else { throw EditFailure.duplicateText }

      if let current {
        var record = current.record
        record.text = text
        try record.update(db)
        if current.id != request.id {
          // The first sync may deduplicate by text under main's different UUID.
          // Keep a tombstone for the source UUID so its old text cannot reappear.
          var original = request.entry
          original.record.deleted = true
          try Self.insert(original, in: db)
        }
      } else {
        var edited = request.entry
        edited.record.text = text
        edited.record.deleted = false
        try Self.insert(edited, in: db)
      }
      try pruneHistory(in: db)
    }
  }
}
