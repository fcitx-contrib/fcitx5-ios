import Foundation
import GRDB
import Swifter
import ZIPFoundation

private struct CheckFailure: Error { let message: String }

private func check(_ value: @autoclosure () throws -> Bool, _ message: String) throws {
  if try !value() { throw CheckFailure(message: message) }
}

@main
private struct ClipboardTests {
  static var manager: FileManager { .default }

  static func main() async throws {
    if CommandLine.arguments.count == 4, CommandLine.arguments[1] == "--writer" {
      let store = ClipboardStore(directory: URL(fileURLWithPath: CommandLine.arguments[2]))
      for index in 0..<20 {
        try store.capture("shared text")
        try store.capture("\(CommandLine.arguments[3])-\(index)")
      }
      return
    }
    let root = manager.temporaryDirectory.appendingPathComponent("clipboard-tests-\(UUID())")
    try manager.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? manager.removeItem(at: root) }
    try testClipboardSuggestions(root)
    try testSensitiveClipboard(root)
    try testCRUD(root)
    try testHistoryLimit(root)
    try testHistoryLimitSyncAndImport(root)
    try testUnsupportedVersions(root)
    try testLegacy(root)
    try testMerge(root)
    try testImportAndRetry(root)
    try testInFlightChanges(root)
    try testReset(root)
    try testSharedImport(root)
    try await testDeletedDatabase(root)
    try testProcesses(root)
    try await testHTTP(root)
    print("All clipboard tests passed")
  }

  static func active(_ store: ClipboardStore) throws -> [ClipboardSyncEntry] {
    try store.entries().filter { !$0.record.deleted }
  }

  static func item(_ text: String, in store: ClipboardStore) throws -> ClipboardSyncEntry {
    guard let entry = try active(store).first(where: { $0.record.text == text }) else {
      throw CheckFailure(message: "Missing \(text)")
    }
    return entry
  }

  static func sync(_ keyboard: ClipboardStore, _ main: ClipboardStore) throws {
    let request = try keyboard.prepareSync()
    // Exercise the actual Codable wire format, including UUID dictionary aliases.
    let encoded = try JSONEncoder().encode(request)
    let decoded = try JSONDecoder().decode(ClipboardSyncRequest.self, from: encoded)
    let response = try main.merge(decoded)
    let result = try JSONDecoder().decode(
      ClipboardSyncResponse.self, from: JSONEncoder().encode(response))
    try keyboard.apply(result)
  }

  static func testClipboardSuggestions(_ root: URL) throws {
    let start = Date(timeIntervalSince1970: 0)
    var suggestion = ClipboardSuggestionState()
    let fullText = String(repeating: "完整文本🐧", count: 30)
    suggestion.capture(fullText, now: start)
    // The capture is decades old relative to the real clock, but an already visible
    // target must stay pasteable until an explicit reevaluation, even after timeout.
    try check(suggestion.presentedText == fullText, "Expiry does not remove the visible target")
    try check(suggestion.takePresentedText() == fullText, "Paste full content after timeout")
    suggestion.refresh(now: start.addingTimeInterval(1))
    try check(suggestion.presentedText == nil, "Pasted suggestions do not reappear")

    suggestion.capture("old", now: start)
    suggestion.hide()
    suggestion.refresh(now: start.addingTimeInterval(29))
    try check(suggestion.presentedText == "old", "Reopening before expiry restores the suggestion")
    suggestion.refresh(now: start.addingTimeInterval(30))
    try check(suggestion.presentedText == nil, "Next reevaluation removes expired suggestions")

    suggestion.capture("new", now: start.addingTimeInterval(31))
    suggestion.refresh(now: start.addingTimeInterval(32))
    try check(suggestion.presentedText == "new", "New copies get their own timeout")
    suggestion.dismiss()
    suggestion.refresh(now: start.addingTimeInterval(33))
    try check(suggestion.presentedText == nil, "Showing the toolbar dismisses the suggestion")

    suggestion.configure(enabled: true, timeout: 0, now: start)
    suggestion.capture("zero", now: start)
    try check(suggestion.presentedText == nil, "Zero timeout does not show a suggestion")
    suggestion.configure(enabled: true, timeout: -1, now: start)
    suggestion.capture("forever", now: start)
    suggestion.hide()
    suggestion.refresh(now: start.addingTimeInterval(1_000_000))
    try check(suggestion.presentedText == "forever", "Negative timeout does not expire")
    suggestion.configure(enabled: false, timeout: 30, now: start)
    try check(suggestion.presentedText == nil, "Disabling suggestions hides the target")
    suggestion.capture("disabled", now: start)
    suggestion.configure(enabled: true, timeout: 30, now: start)
    try check(suggestion.presentedText == nil, "Disabled captures are not offered later")

    suggestion.capture("valid", now: start)
    suggestion.capture(" \n\t", now: start)
    try check(suggestion.presentedText == nil, "Blank content clears the suggestion")

    let store = ClipboardStore(directory: root.appendingPathComponent("suggestion-no-history"))
    try store.setHistoryLimit(0)
    suggestion.capture("not retained", now: start)
    try store.capture("not retained")
    try check(active(store).isEmpty, "Zero history limit stores no active entry")
    try check(
      suggestion.takePresentedText() == "not retained", "Suggestions work without retained history")
    print("PASS clipboard suggestions, delayed expiry, full-text paste, lifecycle and zero history")
  }

  static func testSensitiveClipboard(_ root: URL) throws {
    let text = "test-password🐧"
    let masked = String(repeating: "•", count: text.count)
    try check(
      clipboardDisplayText(text, sensitive: true, maskSensitive: true) == masked,
      "Sensitive history previews are masked")
    try check(
      clipboardDisplayText(text, sensitive: true, maskSensitive: false) == text,
      "Disabling masking reveals the original preview")
    try check(
      clipboardDisplayText(text, sensitive: false, maskSensitive: true) == text,
      "Ordinary text remains visible")
    try check(
      clipboardDisplayText(text, sensitive: true, maskSensitive: true, limit: 5) == "•••••",
      "Suggestion previews respect the character limit")

    var suggestion = ClipboardSuggestionState()
    suggestion.capture(text, sensitive: true)
    suggestion.hide()
    suggestion.refresh()
    try check(suggestion.presentedSensitive, "Reopening retains suggestion sensitivity")
    try check(suggestion.takePresentedText() == text, "Masked suggestions paste the original text")
    try check(!suggestion.presentedSensitive, "Consuming clears suggestion sensitivity")
    suggestion.capture(text, sensitive: true)
    suggestion.capture("ordinary")
    try check(!suggestion.presentedSensitive, "Ordinary captures do not inherit sensitivity")

    let directory = root.appendingPathComponent("sensitive")
    let store = ClipboardStore(directory: directory)
    try store.capture(text)
    let identity = try item(text, in: store).id
    try store.togglePin(identity)
    try store.capture(text, sensitive: true)
    let entry = try item(text, in: store)
    try check(
      active(store).count == 1 && entry.id == identity && entry.record.pinned
        && entry.record.sensitive,
      "Recopying as sensitive updates the flag without duplicating text or losing pins")
    let reopened = ClipboardStore(directory: directory)
    try check(item(text, in: reopened).record.sensitive, "Sensitivity persists across reopen")
    let deleted = try store.delete(identity)
    try store.restore(deleted)
    try check(item(text, in: store).record.sensitive, "Undo preserves sensitivity")
    let main = ClipboardStore(directory: root.appendingPathComponent("sensitive-main"))
    try sync(store, main)
    try check(item(text, in: main).record.sensitive, "Synchronization preserves sensitivity")
    try store.capture(text)
    try check(!item(text, in: store).record.sensitive, "Recopying updates source sensitivity")
    print(
      "PASS sensitive clipboard previews, original paste, persistence, deduplication, undo and sync"
    )
  }

  static func testCRUD(_ root: URL) throws {
    let directory = root.appendingPathComponent("crud")
    let store = ClipboardStore(directory: directory)
    try store.capture(" \n\t")
    try check(store.entries().isEmpty, "Ignore whitespace")
    try store.capture("text ' SQL 中文 🐧")
    try store.capture("text ' SQL 中文 🐧")
    try check(active(store).count == 1, "Text deduplication")
    let first = try active(store)[0]
    try store.togglePin(first.id)
    try store.capture("other")
    try check(active(store)[0].record.pinned, "Pinned first")
    let removed = try store.delete(first.id)
    try store.capture(first.record.text)
    try store.restore(removed)
    try check(active(store).count == 2, "Undo deduplicates new capture")
    try check(item(first.record.text, in: store).record.pinned, "Undo keeps pin")
    let unpinned = try store.clear(includePinned: false)
    try check(unpinned.count == 1 && active(store).count == 1, "Clear preserves pins")
    try store.restore(unpinned)
    let reopened = ClipboardStore(directory: directory)
    try check(reopened.entries() == store.entries(), "Persistent identities, fields and ordering")
    try reopened.database().read { db in
      let columns = try db.columns(in: "clipboard")
      try check(
        columns.map(\.name) == [
          "id", "text", "pinned", "timestamp", "type", "deleted", "sensitive",
        ], "Android columns")
      try check(columns.allSatisfy(\.isNotNull), "Android NOT NULL constraints")
      try check(
        columns.map(\.defaultValueSQL) == [nil, nil, nil, "-1", "'text/plain'", "0", "0"],
        "Android default values")
      try check(Int.fetchOne(db, sql: "PRAGMA user_version") == 4, "Android version")
    }
    print("PASS persistent CRUD, text deduplication, undo and Android v4 schema")
  }

  static func historyFixture(
    _ root: URL, _ name: String, timestamps: [Int64], pinned: Set<Int> = [], deleted: Set<Int> = []
  ) throws -> ClipboardStore {
    let store = ClipboardStore(directory: root.appendingPathComponent(name))
    try store.database().write { db in
      for (index, timestamp) in timestamps.enumerated() {
        var record = ClipboardRecord(text: "\(index)", timestamp: timestamp)
        record.pinned = pinned.contains(index)
        record.deleted = deleted.contains(index)
        try ClipboardStore.insert(ClipboardSyncEntry(id: UUID(), record: record), in: db)
      }
    }
    return store
  }

  static func testHistoryLimit(_ root: URL) throws {
    // Android's regressions: A, B, C, B, D with limit 3; A, B, A, C with limit 2.
    let middle = try historyFixture(root, "limit-recopy-middle", timestamps: [1, 2, 3])
    try middle.setHistoryLimit(3)
    let identity = try item("1", in: middle).id
    try middle.capture("1")
    try middle.capture("3")
    try check(
      Set(active(middle).map { $0.record.text }) == ["1", "2", "3"],
      "Recopying a middle entry must not delete too many entries")
    try check(item("1", in: middle).id == identity, "Recopy retains identity")
    try check(
      middle.entries().first { $0.record.text == "0" }?.record.deleted == true,
      "Overflow remains a sync tombstone")

    let oldest = try historyFixture(root, "limit-recopy-oldest", timestamps: [1, 2])
    try oldest.setHistoryLimit(2)
    try oldest.capture("0")
    try oldest.capture("2")
    try check(
      Set(active(oldest).map { $0.record.text }) == ["0", "2"],
      "Recopying the oldest entry must not exceed the limit")

    let ties = try historyFixture(root, "limit-ties", timestamps: [1, 1, 1])
    try ties.setHistoryLimit(2)
    try check(
      active(ties).map { $0.record.text } == ["2", "1"],
      "Equal timestamps keep newest IDs deterministically")

    let excluded = try historyFixture(
      root, "limit-exclusions", timestamps: [1, 2, 3], pinned: [0], deleted: [2])
    try excluded.setHistoryLimit(1)
    try check(
      Set(active(excluded).map { $0.record.text }) == ["0", "1"],
      "Pinned and deleted entries do not consume the limit")

    let zero = try historyFixture(
      root, "limit-zero", timestamps: [1, .max, 3], pinned: [0], deleted: [2])
    try zero.setHistoryLimit(0)
    try zero.capture("new")
    try zero.capture("0")
    try check(
      active(zero).map { $0.record.text } == ["0"],
      "Zero retains only pins, including after new captures and future timestamps")
    try check(item("0", in: zero).record.pinned, "Recopy keeps pin state")

    let reduced = try historyFixture(root, "limit-reduction", timestamps: [1, 2, 3])
    try reduced.setHistoryLimit(10)
    try check(active(reduced).count == 3, "Below-limit entries are unchanged")
    try reduced.setHistoryLimit(1)
    try check(
      active(reduced).map { $0.record.text } == ["2"], "Reducing the limit prunes immediately")
    try reduced.setHistoryLimit(10)
    try check(active(reduced).count == 1, "Increasing the limit does not resurrect expired entries")
    let reopened = ClipboardStore(directory: reduced.databaseURL.deletingLastPathComponent())
    try reopened.setHistoryLimit(0)
    try check(active(reduced).isEmpty, "A second connection applies the limit to the shared store")
    print("PASS clipboard history limits, recopy regressions, ties, pins, zero and live changes")
  }

  static func testHistoryLimitSyncAndImport(_ root: URL) throws {
    let main = try historyFixture(root, "limit-main", timestamps: [1, 2])
    try main.setHistoryLimit(2)
    let keyboard = ClipboardStore(directory: root.appendingPathComponent("limit-keyboard"))
    try sync(keyboard, main)
    try keyboard.capture("new A")
    try keyboard.capture("new B")
    try sync(keyboard, main)
    try check(
      Set(active(main).map { $0.record.text }) == ["new A", "new B"],
      "Main enforces its limit when merging private keyboard history")
    try check(
      Set(active(keyboard).map { $0.record.text }) == ["new A", "new B"],
      "Keyboard receives main's pruned history")
    try check(!keyboard.hasPendingChanges(), "Retention converges through normal sync")
    try sync(keyboard, main)
    try check(active(main).count == 2, "Another sync cannot resurrect expired history")

    let imported = try historyFixture(
      root, "limit-import-source", timestamps: [1, 2, 3, 4], pinned: [0])
    try main.importDatabase(from: imported.databaseURL)
    try check(
      Set(active(main).map { $0.record.text }) == ["0", "2", "3"],
      "Import obeys the configured limit while preserving pins")
    try check(active(imported).count == 4, "Archive readers do not prune the source database")
    print("PASS history retention during private-store merge and authoritative import")
  }

  static func testUnsupportedVersions(_ root: URL) throws {
    for version in [0, 1, 2, 3, 5] {
      let directory = root.appendingPathComponent("unsupported-\(version)")
      let store = ClipboardStore(directory: directory)
      try store.capture("existing")
      let queue = try store.database()
      try queue.write { try $0.execute(sql: "PRAGMA user_version = \(version)") }
      do {
        _ = try ClipboardStore(directory: directory).entries()
        throw CheckFailure(message: "Unsupported schema must fail")
      } catch ClipboardStore.Failure.unsupportedVersion(let rejected) {
        try check(rejected == version, "Report unsupported version")
      }
      try queue.read { db in
        try check(Int.fetchOne(db, sql: "PRAGMA user_version") == version, "Version unchanged")
        try check(ClipboardRecord.fetchAll(db).map(\.text) == ["existing"], "Records unchanged")
      }
      try queue.close()
    }
    print("PASS unsupported schema rejection without migration or data loss")
  }

  static func testLegacy(_ root: URL) throws {
    let privateDirectory = root.appendingPathComponent("private")
    let legacy = ClipboardStore(directory: privateDirectory)
    try legacy.capture("legacy")
    let directory = root.appendingPathComponent("app-group")
    let shared = ClipboardStore(directory: directory, legacyDirectory: privateDirectory)
    try check(
      active(shared).map { $0.record.text } == ["legacy"], "Migrate main's legacy private database")
    try shared.capture("shared")
    try legacy.capture("do not seed again")
    let reopened = ClipboardStore(directory: directory, legacyDirectory: privateDirectory)
    try check(active(reopened).count == 2, "Existing shared database takes priority")
    let keyboardFirstDirectory = root.appendingPathComponent("keyboard-created-group")
    let keyboardFirst = ClipboardStore(directory: keyboardFirstDirectory)
    try keyboardFirst.capture("legacy")
    try keyboardFirst.togglePin(item("legacy", in: keyboardFirst).id)
    let mainLater = ClipboardStore(
      directory: keyboardFirstDirectory, legacyDirectory: privateDirectory)
    try check(
      active(mainLater).count == 2,
      "Main migrates legacy-only entries even when a keyboard opened shared first")
    try check(
      item("legacy", in: mainLater).record.pinned, "Existing shared fields win over legacy values")
    print("PASS private-to-App-Group migration without overwriting shared data")
  }

  static func testMerge(_ root: URL) throws {
    let main = ClipboardStore(directory: root.appendingPathComponent("merge-main"))
    let keyboard = ClipboardStore(directory: root.appendingPathComponent("merge-keyboard"))
    try main.capture("same")
    try main.togglePin(item("same", in: main).id)
    try keyboard.capture("same")
    try keyboard.capture("keyboard-only")
    try check(
      item("same", in: main).record.id == item("same", in: keyboard).record.id,
      "Independent ID collision fixture")
    try sync(keyboard, main)
    try check(active(main).count == 2 && active(keyboard).count == 2, "Union, not file overwrite")
    try check(item("same", in: keyboard).record.pinned, "Main wins first-sync text conflict")
    let removed = try keyboard.delete(item("keyboard-only", in: keyboard).id)
    try sync(keyboard, main)
    try check(active(main).count == 1, "Keyboard-only delete reaches main")
    try keyboard.restore(removed)
    try sync(keyboard, main)
    try check(active(main).count == 2, "Undo synchronizes")
    _ = try keyboard.delete(item("keyboard-only", in: keyboard).id)
    try sync(keyboard, main)
    try keyboard.capture("keyboard-only")
    try sync(keyboard, main)
    try check(active(main).count == 2, "Explicit recapture after acknowledged deletion")
    try main.togglePin(item("keyboard-only", in: main).id)
    _ = try keyboard.delete(item("keyboard-only", in: keyboard).id)
    try sync(keyboard, main)
    try check(
      item("keyboard-only", in: keyboard).record.pinned, "Main wins concurrent pin vs delete")
    let second = ClipboardStore(directory: root.appendingPathComponent("merge-second"))
    try sync(second, main)
    _ = try main.clear(includePinned: true)
    try second.capture("another keyboard")
    try sync(second, main)
    try check(
      active(main).map { $0.record.text } == ["another keyboard"],
      "Stale peers cannot resurrect main deletions")
    print(
      "PASS bidirectional three-way merge, text/ID conflicts, pins, deletions and multiple peers")
  }

  static func testImportAndRetry(_ root: URL) throws {
    let main = ClipboardStore(directory: root.appendingPathComponent("retry-main"))
    let keyboardDirectory = root.appendingPathComponent("retry-keyboard")
    let keyboard = ClipboardStore(directory: keyboardDirectory)
    try main.capture("before import")
    try main.capture("same text")
    try sync(keyboard, main)
    try keyboard.capture("new keyboard text")
    let pending = try keyboard.prepareSync()
    _ = try main.merge(pending)  // Simulate response lost after main committed.
    let imported = ClipboardStore(directory: root.appendingPathComponent("imported"))
    try imported.capture("same text")
    try imported.togglePin(item("same text", in: imported).id)
    try main.importDatabase(from: imported.databaseURL)
    let reopened = ClipboardStore(directory: keyboardDirectory)
    try check(reopened.prepareSync() == pending, "Pending request survives restart")
    let replay = try main.merge(pending)
    try reopened.apply(replay)
    try check(
      active(main).count == 1 && active(reopened).count == 1,
      "Retry cannot undo a subsequent import")
    try check(item("same text", in: reopened).record.pinned, "Imported main pin wins")
    try reopened.capture("captured after import")
    try sync(reopened, main)
    try check(active(main).count == 2, "New capture merges with imported content")
    let offline = ClipboardStore(directory: root.appendingPathComponent("offline-import-keyboard"))
    try sync(offline, main)
    try offline.capture("offline capture")
    try offline.togglePin(item("same text", in: offline).id)
    try main.importDatabase(from: imported.databaseURL)
    try sync(offline, main)
    try check(
      active(main).count == 2, "Offline capture survives while stale pre-import rows disappear")
    try check(
      item("same text", in: offline).record.pinned,
      "Import wins even if imported values match old baseline")
    try check(
      item("offline capture", in: main).record.text == "offline capture",
      "Offline capture is merged, not overwritten")
    print("PASS authoritative import, persisted retry, idempotency and main-first conflicts")
  }

  static func testInFlightChanges(_ root: URL) throws {
    let main = ClipboardStore(directory: root.appendingPathComponent("flight-main"))
    let keyboard = ClipboardStore(directory: root.appendingPathComponent("flight-keyboard"))
    try keyboard.capture("first")
    let sent = try keyboard.prepareSync()
    let response = try main.merge(sent)
    try keyboard.togglePin(item("first", in: keyboard).id)
    try keyboard.capture("during HTTP")
    try keyboard.apply(response)
    try check(item("first", in: keyboard).record.pinned, "In-flight pin preserved")
    try check(
      active(keyboard).count == 2 && keyboard.hasPendingChanges(), "In-flight capture stays pending"
    )
    try sync(keyboard, main)
    try check(
      active(main).count == 2 && item("first", in: main).record.pinned,
      "Rebased edits synchronize on next pass")
    try check(!keyboard.hasPendingChanges(), "Sync converges without ID-related false changes")
    print("PASS writes during HTTP transfer are rebased and eventually synchronized")
  }

  static func testReset(_ root: URL) throws {
    let main = ClipboardStore(directory: root.appendingPathComponent("reset-main"))
    let directory = root.appendingPathComponent("reset-keyboard")
    let keyboard = ClipboardStore(directory: directory)
    let reader = ClipboardStore(directory: directory)
    try main.capture("from main")
    try sync(keyboard, main)
    let authoritative = try main.entries()
    _ = try keyboard.delete(item("from main", in: keyboard).id)
    try keyboard.capture("discard local pin")
    try keyboard.togglePin(item("discard local pin", in: keyboard).id)
    let pending = try keyboard.prepareSync()
    _ = try reader.entries()

    try keyboard.reset()
    try check(reader.entries().isEmpty, "Reset removes pinned entries and tombstones")
    let fresh = try reader.prepareSync()
    try check(fresh.baseline.isEmpty && fresh.entries.isEmpty, "Reset discards the old baseline")
    try check(
      fresh.id != pending.id && fresh.clientID != pending.clientID,
      "Reset discards pending requests and the previous client identity")
    try sync(reader, main)
    try check(main.entries() == authoritative, "Reset does not send discarded edits to main")
    let restored = try keyboard.entries()
    try check(
      restored.count == 1 && restored[0].id == authoritative[0].id
        && restored[0].hasSameContent(as: authoritative[0]) && !keyboard.hasPendingChanges(),
      "Full resync repopulates the existing connection from main and converges")
    print("PASS explicit reset clears local clipboard and sync state before full resync")
  }

  static func testSharedImport(_ root: URL) throws {
    let directory = root.appendingPathComponent("live-import")
    let main = ClipboardStore(directory: directory.appendingPathComponent("databases"))
    let otherProcess = ClipboardStore(directory: directory.appendingPathComponent("databases"))
    try main.capture("old shared content")
    try main.capture("imported")
    _ = try active(otherProcess)
    let old = try main.clear(includePinned: true)
    let incomingDirectory = root.appendingPathComponent("live-import-source")
    let incoming = ClipboardStore(directory: incomingDirectory.appendingPathComponent("databases"))
    try incoming.capture("imported")
    try incoming.togglePin(item("imported", in: incoming).id)
    let export = BackupArchive(
      configDirectory: incomingDirectory.appendingPathComponent("config"),
      dataDirectory: incomingDirectory.appendingPathComponent("data"),
      databasesDirectory: incomingDirectory.appendingPathComponent("databases"),
      clipboardStore: incoming)
    let zip = root.appendingPathComponent("clipboard.zip")
    try export.export(to: zip, date: Date())
    let restore = BackupArchive(
      configDirectory: directory.appendingPathComponent("config"),
      dataDirectory: directory.appendingPathComponent("data"),
      databasesDirectory: directory.appendingPathComponent("databases"), clipboardStore: main)
    try restore.importData(from: zip, source: .fcitx5)
    try check(
      active(otherProcess).map { $0.record.text } == ["imported"],
      "Open connection sees imported contents")
    try otherProcess.restore(old)
    try check(active(otherProcess).count == 1, "Old undo cannot resurrect entries after import")
    try check(
      item("imported", in: otherProcess).record.pinned,
      "Old undo cannot change an imported entry with the same text")
    try otherProcess.capture("other connection")
    try check(active(main).count == 2, "Both open connections still write same inode")
    let plain = root.appendingPathComponent("plain-snapshot")
    try DatabaseBackup.snapshotDirectory(from: restore.databasesDirectory, to: plain)
    let reader = try DatabaseQueue(
      path: plain.appendingPathComponent(ClipboardStore.databaseFileName).path)
    try reader.read { db in
      try check(!db.tableExists("ios_clipboard_identity"), "No iOS identity metadata in export")
      try check(!db.tableExists("ios_clipboard_state"), "No iOS sync state in export")
      try check(ClipboardRecord.fetchCount(db) == 2, "Export includes committed WAL")
    }
    try reader.close()
    print("PASS live shared import, stale undo isolation and standalone Android-format export")
  }

  static func testDeletedDatabase(_ root: URL) async throws {
    for deleteDirectory in [false, true] {
      let directory = root.appendingPathComponent("deleted-main-\(deleteDirectory)")
      let main = ClipboardStore(directory: directory)
      let keyboard = ClipboardStore(
        directory: root.appendingPathComponent("deleted-keyboard-\(deleteDirectory)"))
      try keyboard.capture("already synced")
      try sync(keyboard, main)
      try keyboard.capture("captured since last sync")
      try keyboard.togglePin(item("captured since last sync", in: keyboard).id)
      // Deleting Documents' database does not close the main app's cached connection.
      try manager.removeItem(at: deleteDirectory ? directory : main.databaseURL)
      let server = HttpServer()
      server.listenAddressIPv4 = "127.0.0.1"
      server.POST["/clipboard/sync"] = { ClipboardSyncServer.handle($0, store: main) }
      try server.start(0, forceIPv4: true)
      defer { server.stop() }
      let url = URL(string: "http://127.0.0.1:\(try server.port())/clipboard/sync")!
      try await ClipboardTransport.synchronize(store: keyboard, endpoint: url)
      try check(!keyboard.hasPendingChanges(), "Sync converges after main database is deleted")
      try check(
        item("captured since last sync", in: main).record.pinned,
        "New keyboard captures and their pin state reach the recreated main database")
      let reopened = ClipboardStore(directory: directory)
      try check(reopened.entries() == main.entries(), "Recreated data is persisted, not unlinked")
      try keyboard.capture("next sync")
      try await ClipboardTransport.synchronize(store: keyboard, endpoint: url)
      try check(!keyboard.hasPendingChanges(), "Subsequent synchronization also converges")
      try check(active(reopened).count == 2, "Subsequent sync writes to the recreated database")
    }
    print("PASS HTTP synchronization after deleting an open database file or directory")
  }

  private final class HTTPAttempt: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    func next() -> Int {
      lock.lock()
      defer { lock.unlock() }
      count += 1
      return count
    }
  }

  static func testHTTP(_ root: URL) async throws {
    let main = ClipboardStore(directory: root.appendingPathComponent("http-main"))
    let keyboard = ClipboardStore(directory: root.appendingPathComponent("http-keyboard"))
    try main.capture("main over HTTP")
    try keyboard.capture("keyboard over HTTP")
    let attempts = HTTPAttempt()
    let server = HttpServer()
    server.listenAddressIPv4 = "127.0.0.1"
    server.POST["/clipboard/sync"] = { request in
      let result = ClipboardSyncServer.handle(request, store: main)
      switch attempts.next() {
      case 1: return .raw(503, "Lost response", nil, nil)
      case 2:
        do { try keyboard.capture("captured during HTTP") } catch {
          return .internalServerError(nil)
        }
      default: break
      }
      return result
    }
    try server.start(0, forceIPv4: true)
    defer { server.stop() }
    let url = URL(string: "http://127.0.0.1:\(try server.port())/clipboard/sync")!
    do {
      try await ClipboardTransport.synchronize(store: keyboard, endpoint: url)
      throw CheckFailure(message: "Failed HTTP must not report success")
    } catch ClipboardTransport.Failure.serverRejected(503) {}
    try await ClipboardTransport.synchronize(store: keyboard, endpoint: url)
    try check(
      active(main).count == 3 && active(keyboard).count == 3,
      "HTTP retry merges both sides and drains in-flight writes")
    try check(!keyboard.hasPendingChanges(), "HTTP success means local changes acknowledged")
    var invalid = URLRequest(url: url)
    invalid.httpMethod = "POST"
    invalid.httpBody = Data("not JSON".utf8)
    let (_, response) = try await URLSession.shared.data(for: invalid)
    try check((response as? HTTPURLResponse)?.statusCode == 400, "Malformed HTTP request rejected")
    print("PASS HTTP server/client integration, failed response retry and in-flight writes")
  }

  static func testProcesses(_ root: URL) throws {
    let directory = root.appendingPathComponent("processes")
    let store = ClipboardStore(directory: directory)
    // Let all five processes race to initialize the initially absent database.
    var children = [Foundation.Process]()
    for index in 0..<5 {
      let process = Foundation.Process()
      process.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
      process.arguments = ["--writer", directory.path, String(index)]
      try process.run()
      children.append(process)
    }
    for process in children {
      process.waitUntilExit()
    }
    try check(
      children.allSatisfy { $0.terminationStatus == 0 }, "Concurrent writers exited successfully")
    let entries = try active(store)
    try check(entries.count == 101, "Five processes preserve all unique captures")
    try check(
      entries.filter { $0.record.text == "shared text" }.count == 1,
      "Cross-process transactional text deduplication")
    print(
      "PASS five concurrent processes share one WAL database without lost or duplicate captures")
  }
}
