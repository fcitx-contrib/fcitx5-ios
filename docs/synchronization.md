# Synchronization without App Group

This is an implementation guide for AI agents extending synchronization between the main app and keyboard extensions, especially future bidirectional datasets. It describes the working-tree implementation as of 2026-10-30, not a claim that every behavior below has shipped. Read the linked code before changing it, and update this document when the protocol changes.

The clipboard is the first bidirectional dataset. Its transport and merge code are reusable, but there is not yet a generic synchronization framework. Configuration-file downloads remain a separate, mostly one-way mechanism.

**Known unresolved data-loss case:** the protocol cannot distinguish an authoritative import from loss and recreation of the main database. Previously synchronized keyboard entries can therefore be discarded after main's database is recreated. See [Database loss is not an import](#database-loss-is-not-an-import) before reusing the current merge algorithm.

## Essential rules

- With App Group, use the shared store directly. Without it, each process owns its private store; the main app is the merge hub, not a file source that blindly overwrites every keyboard.
- Merge bidirectional data in the main app. Preserve contributions from both sides; for the clipboard, genuine conflicts are resolved in favor of main's current record.
- Separate stable entity identity, local SQLite row ID, sync-client identity, request identity, and database generation. They solve different problems.
- Persist a request before sending it. Apply its acknowledgement, the new baseline, and removal of the pending request in one local transaction.
- An HTTP response must not overwrite changes made locally while that request was in flight. Rebase those changes, then synchronize again.
- Deletion must survive offline peers and retries. Do not infer that every absent record was intentionally deleted, or garbage-collect deletion history without a protocol for stale peers.
- Do not replace an open SQLite file or its directory. Use database transactions for live import, replacement of records, and explicit reset.
- A completed exchange covers one keyboard at one point in time. It does not instantly synchronize all keyboard processes or future writes.
- Keep merge, persistence, and transport independent of a particular SwiftUI screen. Future editing/navigation flows should call the same synchronization API.

## Storage modes and process boundaries

[common/util.swift](../common/util.swift) defines `documents`, `appGroup`, `appGroupAvailable`, `clipboardDatabases`, and the process-local `clipboardStore` object. When the App Group container is unavailable, `appGroup` falls back to that process's `Documents` directory. Use `appGroupAvailable`; do not invent another availability check in each feature.

| Mode | Clipboard storage | Coordination |
|---|---|---|
| App Group available | Main and the four keyboard extensions use the same `databases/clbdb` in the group container. | SQLite transactions coordinate writers across processes; each process has its own GRDB connection. Clipboard HTTP synchronization is not used. |
| App Group unavailable | Main and each keyboard extension have their own `Documents/databases/clbdb`: five private stores with the current four extensions. | Each keyboard exchanges logical records with main through the foreground main app's local HTTP server. |

The existing `useAppGroup` switch in `common/util.swift` can simulate private-storage mode on the simulator. Restore it after an experiment. Full Access is separately required for the keyboard's local-network requests; lack of App Group does not remove that requirement. See [full-access.md](full-access.md).

Configuration and data use the same relative paths in both modes: `Documents/config/` and `Documents/data/`, including `Documents/data/rime/`, `Documents/data/inputmethod/`, and `Documents/data/table/`. With App Group available, the main app copies its `Documents/data/` and `Documents/config/` into the corresponding App Group directories at startup, before initializing the profile and starting fcitx, and when the app becomes active. Existing source files overwrite differing destination files; destination-only files are preserved, so removing a file from Documents does not delete it from App Group. Missing source directories are skipped. Without App Group, this copy is skipped because the runtime already uses the process's own Documents directory; keyboard file synchronization retains these relative paths through the HTTP workflow below.

There is no direct keyboard-to-keyboard exchange. If A synchronizes and then B contributes new data, A receives B's contribution only when A synchronizes again.

For UI freshness, the supported workflow assumes one active keyboard and does not require observing main-app edits while the clipboard page remains open. Refresh on keyboard appearance, after local clipboard operations, and after synchronization; do not add periodic database polling for that unsupported case. This UI assumption does not remove the need for transactional access to the shared database or imply that iOS immediately terminates every inactive extension process.

## Code map

| Responsibility | Entry point |
|---|---|
| Private/group storage selection and HTTP address constants | [common/util.swift](../common/util.swift) |
| Main Documents-to-App-Group configuration/data copy | [src/AppDelegate.swift](../src/AppDelegate.swift), [src/App.swift](../src/App.swift) |
| SQLite schema, CRUD, identities, live import, and reset | [common/ClipboardStore.swift](../common/ClipboardStore.swift) |
| Request preparation, main-side merge, response application, and convergence check | [common/ClipboardSync.swift](../common/ClipboardSync.swift) |
| Reusable asynchronous HTTP client and repeat-until-converged loop | [common/ClipboardTransport.swift](../common/ClipboardTransport.swift) |
| Clipboard HTTP decode/merge/encode adapter | [src/ClipboardSyncServer.swift](../src/ClipboardSyncServer.swift) |
| Main server lifecycle, endpoint registration, file enumeration/download, and completion reporting | [src/SyncConfigView.swift](../src/SyncConfigView.swift) |
| Clipboard edit URL payload and transactional main-side save | [common/ClipboardEdit.swift](../common/ClipboardEdit.swift) |
| Focused clipboard editor and save-to-sync navigation | [src/ClipboardEditView.swift](../src/ClipboardEditView.swift), [src/ContentView.swift](../src/ContentView.swift) |
| Keyboard file-download workflow and invocation of bidirectional synchronization | [keyboard/SyncConfig.swift](../keyboard/SyncConfig.swift) |
| Keyboard entry into private-mode synchronization and Full Access check | [keyboard/KeyboardViewController.swift](../keyboard/KeyboardViewController.swift) |
| Serialized clipboard UI operations and the explicit clear/resync button | [uipanel/VirtualKeyboard.swift](../uipanel/VirtualKeyboard.swift), [uipanel/Sync.swift](../uipanel/Sync.swift) |
| Archive import/export and normalized SQLite snapshots | [src/BackupArchive.swift](../src/BackupArchive.swift), [src/DatabaseBackup.swift](../src/DatabaseBackup.swift) |
| Persistence, merge, process-concurrency, reset, and real HTTP regression tests | [tests/backup/ClipboardTests.swift](../tests/backup/ClipboardTests.swift) |

## Current Sync config session

1. Main's `SyncConfigView` starts `ServerManager` and focuses a hidden text field containing the synchronization marker. The server currently listens on `127.0.0.1:32489`, using constants from `common/util.swift`; do not duplicate these constants in new clients.
2. A keyboard recognizes the marker on appearance. In private-storage mode, with Full Access, it starts `doSyncConfig`. The main screen must stay active for its server to remain available; this is not an always-running background service.
3. The keyboard obtains `/list?keyboard=...`, then downloads changed files through `/download`. `tmp/checksums.json` tracks previously downloaded hashes. The main app selects applicable config/data paths; this is not a bidirectional merge of all files under `Documents`.
4. After the file phase, the keyboard calls `ClipboardTransport.synchronize` against `POST /clipboard/sync`. The database directory is deliberately not transferred through the file-download endpoints.
5. Once the clipboard exchange converges, the keyboard refreshes its clipboard UI, reloads configuration, and reports `/done?keyboard=...`. Main marks that keyboard complete; the keyboard shows `.syncDone`.

`ServerManager.clipboardHandler` rejects clipboard HTTP synchronization when App Group is available. The adapter returns 400 for malformed requests or invalid sync data, 500 for other merge failures, and 200 with a JSON response on success. The client accepts only 200.

`SyncState` manages cancellation of the previous keyboard sync task. Clipboard HTTP failures currently cause the outer workflow to wait one second and restart from the file phase, while preserving the pending clipboard request. Thus a display such as `20/20` can repeat even though the failure is in the later clipboard phase. The displayed count measures files, not committed bidirectional datasets.

Do not add a new bidirectional dataset to `/list` or copy its database wholesale through `/download`. Give it a logical merge/apply stage before reporting completion. These stages are not currently one transaction across all files and datasets; do not imply global atomicity in UI or tests.

## Clipboard identities, content, and durable state

The Android-compatible `clipboard` table uses schema version 4 and fields `id`, `text`, `pinned`, `timestamp`, `type`, `deleted`, and `sensitive`. Only version 4 is supported for existing clipboard databases and backups; other versions are rejected without migration or replacement of existing data. A new database is initialized directly at version 4. Keep that model compatible with Android. `PRAGMA user_version` is the database schema version, not a synchronization protocol version or a database-generation identifier.

Identity has several layers:

- `ClipboardRecord.id` is an auto-incremented numeric primary key local to one SQLite database. Independent stores can assign the same number to unrelated records, or different numbers to the same synchronized record. Never use it as the cross-process sync identity.
- `ClipboardSyncEntry.id` is a stable entity UUID, mapped to the local row by `ios_clipboard_identity`. Logical edits retain it. Main's import deliberately gives imported rows new entity UUIDs.
- `clientID` identifies a keyboard store's synchronization history. It is persisted, not derived from a view controller, process ID, fcitx program, input-context UUID, or keyboard display name.
- Request `id` identifies a persisted outbound snapshot and is echoed as response `requestID`. A retry of that snapshot uses the same ID and payload.
- There is currently **no main-database generation ID**. Do not mistake one of the preceding IDs for that missing concept.

Clipboard equality for merge/convergence compares all record fields except the local numeric row ID. Timestamps are part of content and ordering, not a global last-writer-wins clock. Main wins conflicts for the entire record; this is not field-by-field merging.

Clipboard capture deduplicates active entries by exact text. Main merges by stable UUID first, then matching active text, then matching text in deleted rows. The response's `aliases` maps incoming UUIDs to main's canonical UUIDs when independent captures of the same text coalesce. Preserve pin state and prevent duplicate active text when merging, rebasing, or undoing. Other future datasets need their own explicit identity and equivalence rules; do not assume clipboard text matching generalizes to them.

`ios_clipboard_state` stores JSON-encoded values in the same SQLite database:

| Key | Meaning |
|---|---|
| `baseline` | The main snapshot last successfully applied by this keyboard, before rebasing still-unsent local changes. Includes deleted records. |
| `pending` | The exact request persisted before HTTP, retained until its matching response is applied. |
| `clientID` | This store's persistent sync-client UUID. |
| `client-<UUID>` | Main's most recent completed response for that client, used to recognize a retry. |
| `legacyMigrated` | One-time private-to-group migration bookkeeping; unrelated to HTTP progress. |

The wire request contains `id`, `clientID`, `baseline`, and `entries`. The wire response contains `requestID`, `entries`, and `aliases`. Both sides currently exchange full snapshots, including tombstones, rather than a paged change log. Do not promise bounded payload size or automatic deletion-history compaction.

## One bidirectional exchange

### 1. Prepare and persist on the keyboard

`prepareSync()` returns the existing `pending` request if present. Otherwise, in one transaction it reads the baseline and current entries, creates or loads `clientID`, assigns a request UUID, and persists the complete request. It must not rebuild an outstanding request from newer local data merely because HTTP failed.

This makes a response-lost-after-commit retry different from a new edit. A process restart can retry the same request. Local edits after preparation remain in the store but do not change that pending snapshot.

### 2. Merge in main

`merge()` runs in one database transaction, including storage of the completed response. Its normal rules are:

| Situation | Current result |
|---|---|
| Incoming record has no main match and was not in the keyboard's baseline | Insert it as a new contribution, preserving its entity UUID and assigning a main-local row ID. |
| Main's matching record still equals the baseline, with the same stable identity | Accept the keyboard's record, including pin changes or deletion, unless that would introduce duplicate active text. |
| Main has changed the record since the baseline, or an initial text match has a different identity | Keep main's record and return its canonical identity. |
| Baseline contains a record no longer present in the keyboard snapshot | Treat the omission as a deletion candidate; normal local deletion should already be a tombstone. |
| Incoming identity was in the baseline but no matching main record remains | Do not restore it; current code assumes it was removed by an authoritative import. This assumption causes the database-loss bug described below. |

This is a three-way merge between baseline, main, and keyboard, not unconditional main-to-keyboard copying. In particular, main priority must not erase unrelated new keyboard captures.

If the request matches the client's latest completed request, main does not reapply its writes. It returns the request acknowledgement and aliases with **main's current entries**, not a cached snapshot from before a later import or edit. This prevents a lost response from undoing a subsequent authoritative import.

Only the latest response per client is retained. This is not an arbitrary request-history journal. Keep exchanges serialized per store; GRDB thread safety alone does not make overlapping transports, out-of-order requests, or concurrent reset/sync sessions protocol-safe.

### 3. Apply and rebase on the keyboard

`apply()` validates that the response matches the persisted pending request, then performs all of the following in one transaction:

1. Start with the returned main snapshot.
2. Compare current local entries with the snapshot actually sent, not just with the old baseline. Rebase edits made while HTTP was in flight onto the result, translating identities through `aliases` and deduplicating active text. Do not resurrect a known identity removed by main's authoritative import.
3. Replace local records and identity mappings without replacing the SQLite file. Surviving identities retain their local numeric row IDs; new ones get local IDs.
4. Save the **returned main snapshot** as the baseline, not the locally rebased result. Otherwise unsent edits would appear acknowledged.
5. Delete `pending`.

`hasPendingChanges()` compares current content with that baseline while ignoring numeric row IDs and array order. `ClipboardTransport.synchronize()` repeats the exchange if rebased changes remain. Receiving HTTP 200 alone is not its completion condition. Cancellation or network failure must not falsely acknowledge or discard pending changes; already committed database work is not rolled back just because a task is cancelled.

## Deletion, import, reset, and database loss

These are different operations and must not share an undocumented "missing means deleted" rule.

### Normal deletion

Clipboard delete and clear set `deleted = true`. Tombstones remain in synchronization snapshots so an offline keyboard cannot resurrect a deleted entry. They are not visible clipboard items. The current implementation has no tombstone garbage-collection protocol.

The frontend's `[Clipboard] HistoryLimit` setting defaults to 10 and limits active unpinned entries; pinned and deleted entries do not consume the limit, and zero retains only pins. Loading or saving frontend configuration applies the limit to the process-local `ClipboardStore` and prunes immediately. Capture, main-side merge, and authoritative import also prune in their write transaction. Pruning selects the exact overflow IDs ordered by timestamp descending, then numeric ID descending, and marks them deleted so expiration participates in normal synchronization. Recopying updates timestamps without changing IDs, so deleting a numeric ID range would be incorrect. Archive readers leave retention unconfigured and never prune the backup source. The limit remains a configuration-file setting, not an additional synchronization protocol field.

Undo reactivates appropriate local data and retains pin state; an old undo must not restore an identity removed by import. If matching active text was captured after deletion, undo must not create another active copy.

### Main-app clipboard editing

The keyboard's Edit action opens `fcitx://clipboard/edit` through the shared Full Access check in `ipc.swift`. The query includes the stable entity UUID as `id` and the original `text`, plus timestamp, pin, sensitivity, and type metadata. Local numeric SQLite IDs are not cross-process identities. The main editor starts with the passed text and focuses its text view automatically. Cancel does not write anything.

`ClipboardStore.edit` saves in one database transaction. Shared mode requires an existing live UUID and updates only its text, preserving identity, pin, sensitivity, and ordering. Missing or deleted entries are rejected. Blank edits and edits that would duplicate another active text are also rejected without modifying the database.

In private mode, main may never have received the selected entry. If no matching live record exists, saving inserts the edited record under the source UUID using the passed metadata. If main already has the original text under a different UUID, it edits main's canonical record and retains main's metadata. It also inserts a deleted copy under the source UUID: otherwise the first sync would see the keyboard's old text as a new contribution and restore it. These tombstones use the existing schema and normal merge/apply protocol; do not add a database-file download or a second synchronization channel for editing.

Saving unchanged text only closes the editor, without writing the database or starting synchronization. After a changed shared save the editor closes. After a changed private save it closes and automatically navigates to `SyncConfigView`, which runs the existing file and clipboard synchronization workflow. Main's edit wins conflicts with the old keyboard snapshot; other keyboards receive it on their next sync. This does not change the database-generation limitation below.

### Authoritative archive import

`BackupArchive` normalizes a staged database through SQLite so committed WAL content is included; Android's disposable SHM index is rebuilt locally. It then calls `ClipboardStore.importDatabase` to replace live clipboard rows in a transaction. Do not replace the live inode, especially when App Group makes it shared with running extensions.

Imported rows receive new stable entity UUIDs, even when their content matches an old baseline. Main's acknowledgement state is retained, so a retried pre-import request cannot replay old writes over the import. Stale previously synchronized rows must not return, but unrelated newly captured keyboard rows can still merge.

Exports use a standalone committed SQLite snapshot and omit the private `ios_clipboard_identity` and `ios_clipboard_state` tables. A portable Android-format backup is not an HTTP synchronization checkpoint; restoring it does not restore a client's pending requests or baseline.

### Explicit keyboard clear and resync

The `.syncDone` button "Clear data and sync again" calls `resetClipboard()` before removing private `config`, `data`, and `tmp/checksums.json` and restarting synchronization. `ClipboardStore.reset()` clears all clipboard records, identity mappings, and sync state transactionally, including pins, tombstones, baseline, pending request, and client ID. The database file itself remains open; this is not deletion of the whole `databases` directory.

This action deliberately discards this keyboard's local clipboard history and edits. It does not send those discarded edits as deletions to main. The next exchange starts without a baseline and pulls main's contents. It does not clear main or another keyboard.

Because the button is shown after a successful sync, both sides normally already agree. Clearing and downloading that same data again cannot recover entries that an earlier exchange already discarded. Do not present this button as recovery from main-database loss.

### Database loss is not an import

The following remains an unresolved semantic bug:

1. Keyboard A synchronizes, retaining a baseline containing its entries.
2. Main's private database is deleted and recreated, losing records and sync metadata.
3. A synchronizes again. Its old entries are still in its baseline but absent from main, so `merge()` treats them as intentionally removed and skips them.
4. A applies main's snapshot and loses those entries. If B contributed to main first, A may end up with B's contents instead of a union.

`ClipboardStore.database()` now closes a cached connection when its file is missing and recreates the database. That fixes the SQLite `disk I/O error` / HTTP 500 / repeated file-progress loop, **not** the preceding data-loss bug. `testDeletedDatabase` covers I/O recovery and newly captured data, not recovery of all previously synchronized entries. Do not cite its success as proof that generation handling exists.

The intended future distinction is a persisted main-database instance/generation UUID: generate a new one on database creation, preserve it across normal launches and authoritative imports, and have each keyboard retain which generation its baseline belongs to. A generation change should trigger a fresh full merge of each keyboard's current data with main's current data, still resolving actual conflicts in favor of main. B synchronizing first must not prevent A from detecting that its own baseline belongs to the old generation.

This generation protocol is **not implemented**. A future change must specify how generation travels in requests/responses, how it is committed atomically with baseline/pending state, how outstanding old-generation requests are handled, and how existing stores/messages without generation migrate. Do not implement the distinction by ignoring all baselines unconditionally: that would let stale keyboards undo intentional imports and deletions. Keep schema version, wire-protocol version, and database generation separate.

## Adding another bidirectional dataset

Use the clipboard as a reference for transaction and retry structure, not as a drop-in policy for every dataset.

1. Define the dataset's storage in both modes, stable entity identity, logical equality, deduplication rules, deletion representation, and import/reset semantics. State whether conflicts resolve per record or per field. Keep the clipboard's main-wins policy unless the requested dataset explicitly needs another rule.
2. Define the baseline/change model and main-generation handling before implementing the merge. Decide what must survive a process kill and what constitutes an acknowledged change. If record counts can grow, design payload limits, paging, retention, and resynchronization together rather than silently relying on full snapshots forever.
3. Separate persistence, pure or transaction-scoped merge logic, and the HTTP adapter/client. Prefer the existing GRDB typed records and query APIs for SQLite; do not build a second handwritten-SQL storage layer or put networking inside a SwiftUI view.
4. Register a dataset-specific endpoint with the existing `ServerManager`, and invoke a reusable transport from the keyboard workflow before `/done`. Do not create another server or a peer-to-peer path without a requirement for it. Recheck App Group routing, Full Access, path/payload validation, and malformed-request behavior; localhost binding is not by itself a client-authentication mechanism.
5. Serialize exchanges per dataset/store and define interaction with cancellation, reset, imports, and writes during HTTP. Persist acknowledgements and applied state atomically. If future datasets must commit together, design an explicit cross-dataset protocol; sequential calls alone are not atomic.
6. Reuse the existing clipboard edit/save and merge/apply APIs for "open main app to edit, then sync back" navigation. Preserve source metadata for unsynchronized records and account for independent UUIDs when deduplicating original text. Do not simulate editing by replacing a keyboard's database file.
7. Preserve module ownership. Shared implementations are statically linked once into the existing `FcitxRuntime`, while executables consume module interfaces without linking duplicate Swift classes. Do not add frameworks just to share a sync helper. Host tests compile selected common sources directly; this is why the app-side adapters use documented `#if canImport(SwiftUtil)` imports.
8. Add regression tests and update this document and the source map together. Do not copy the current database-loss assumption into a new dataset as if it were a desired contract.

## Verification checklist

Use [tests/backup/CMakeLists.txt](../tests/backup/CMakeLists.txt) to build macOS-host tests alongside the iOS targets, following the same approach as `UndoRedoSwift`. `ClipboardTests.swift` already covers record persistence/version validation, legacy private-to-group migration, text/ID collisions, main-first conflicts, deletion/undo, multiple peers, import and lost-response retry, in-flight changes, explicit reset, live shared import/export, deleted-file I/O recovery, concurrent processes, and real HTTP transport.

For a new dataset or protocol change, cover at least:

- Initial union of main-only and keyboard-only data, independent local numeric ID collisions, and every field that must survive synchronization.
- Unilateral local and main edits, concurrent conflicts, delete versus edit, stale peers, and multiple keyboards synchronizing in different orders.
- Main commits but the response is lost; client/server restart; retries with the same request ID; cancellation before/after commit; malformed or mismatched responses; and idempotency across imports.
- Local writes while HTTP is in flight, identity canonicalization, persistence after applying, and eventual convergence without numeric-ID or ordering false positives.
- Explicit reset with pending requests and open readers, followed by a full resync that does not propagate deliberately discarded local edits.
- Main database loss/recreation **after an earlier successful sync**, both A-first and B-first orderings, and verification that already-synchronized entries are not lost. These are required new generation tests, not guarantees of the current implementation.
- Shared-mode concurrency without HTTP; private-mode HTTP with separate stores; live imports without inode replacement; and standalone exports that do not depend on WAL files.

Run the build/sign and lint/format commands from the root [AGENTS.md](../AGENTS.md) after code changes. Run the existing tests with:

```sh
ctest --test-dir build/SIMULATORARM64 --output-on-failure
```

`ClipboardSwift` starts a real localhost HTTP server, so the test environment must allow loopback binds. Its executable uses temporary stores: do not delete a user's simulator databases merely to reproduce a regression. Where platform lifecycle or Full Access behavior changes, verify the real extension flow as well; host tests and compilation do not exercise it.
