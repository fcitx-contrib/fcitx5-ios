# Chinese keyboard memory investigation, September 2026

This note preserves the controlled observations from an investigation of Chinese keyboard extension memory growth. The absolute values came from a Debug simulator build and are not device memory budgets.

## Environment

- Date: September 23–24, 2026.
- Host: macOS 26.5.1 on Apple Silicon.
- Simulator: iPhone 17, iOS 26.5.
- Build: `SIMULATORARM64`, Debug.
- Extension: `org.fcitx.Fcitx5.Chinese`.
- Relevant UI: Messages text field with the Chinese keyboard visible.
- Document poll interval: 0.2 seconds.

The installed extension binary was verified against the local build before the initial measurements. Existing unrelated working-tree changes were preserved.

## Initial model observations

The main language model was 10,483,356 bytes and the prediction model was 2,576,105 bytes.

The main model did not appear as a file-backed path in `vmmap`. The live heap contained three notable large allocations:

- 8,016 KiB once.
- 4,096 KiB twice.

Together these anonymous allocations accounted for approximately 15.8 MiB. At the time of the investigation, KenLM's default `Config::load_method` was `POPULATE_OR_READ`, and the libime language-model construction did not override it. This is consistent with reading the model into anonymous memory, but an allocation stack was not captured for the three regions.

A freshly preloaded extension used approximately 50.3 MiB physical footprint. Showing the keyboard for the first time raised it to approximately 70.5–74 MiB. The main model allocations were already present before the first user input.

## Periodic growth reproduction

The fcitx autosave interval was temporarily changed from the default 30 minutes to one minute. The App Group log confirmed each `Running autosave...` and `End autosave` pair. The runtime user dictionary and history files were only hundreds of bytes.

With the keyboard visible and untouched, consecutive samples showed:

| Sample | Live nodes | Live bytes | Change |
|---|---:|---:|---:|
| Foreground baseline | 123,521 | 38,564,132 | — |
| Approximately one minute later | 123,760 | 38,579,428 | +239 nodes, +15,296 bytes |
| Approximately one more minute later | 124,044 | 38,597,604 | +284 nodes, +18,176 bytes |

The new allocations were 64-byte non-objects. The second interval added 284 allocations, close to the 300 document-poll callbacks expected per minute. Autosave completed during the test but did not correlate with a footprint or live-heap jump.

The log file was not retained as an in-memory history. Standard error was redirected to the file descriptor, and the log file was truncated when the extension process started. Log length was therefore not the cause of the linear live-heap growth.

## Polling path

The unchanged-document polling path did the following every 0.2 seconds:

1. Constructed a document-state value, including the document identifier and surrounding text.
2. Called `observeDocumentState` through a `defer`, even when the new state equaled the stored state.
3. Called `updateUndoRedoAvailability`.
4. Assigned `canUndo` and `canRedo`, both `@Published`, without comparing their existing values.

The assignments published SwiftUI state changes even though both Boolean values remained unchanged.

## Root-cause isolation

The first test changed both ends of the path:

- Skip `observeDocumentState` when the document state is unchanged in [`KeyboardViewController.swift`](../../keyboard/KeyboardViewController.swift).
- Assign `canUndo` and `canRedo` only when their values actually change in [`VirtualKeyboard.swift`](../../uipanel/VirtualKeyboard.swift).

After the combined change, a one-minute idle comparison was exactly stable:

| Measurement | Baseline | Later | Change |
|---|---:|---:|---:|
| Physical footprint | 74.6 MiB | 74.6 MiB | 0 |
| Live nodes | 123,717 | 123,717 | 0 |
| Live bytes | 38,517,667 | 38,517,667 | 0 |
| 64-byte nodes | 7,927 | 7,927 | 0 |

A single-variable test then restored the original `defer` behavior while retaining only the equal-value guards in `setUndoRedo`. After approximately one minute:

| Measurement | Baseline | Later | Change |
|---|---:|---:|---:|
| Physical footprint | 63.6 MiB | 63.5 MiB | -0.1 MiB |
| Live nodes | 122,423 | 122,379 | -44 |
| Live bytes | 38,438,787 | 38,430,787 | -8,000 |
| 64-byte nodes | 7,029 | 6,999 | -30 |

This isolated the direct cause to repeated equal-value assignments to `@Published canUndo` and `@Published canRedo`. The `defer` was the 5 Hz trigger and unnecessary work, but it did not cause the retained allocations when the publications were suppressed.

The exact internal owner of the 64-byte blocks was not captured because the process was not launched with malloc stack logging. The rate and the single-variable result are consistent with Combine, SwiftUI, or AttributeGraph update records retained for the visible view lifetime.

Both protections were retained: the state-owner equality guard prevents redundant publications from any caller, and the polling guard avoids unnecessary document-state work.

## Input and commit behavior

The modified build was tested by repeatedly entering `nihao` and committing the first `你好` candidate. The text was not sent and the test draft was removed afterward.

| Checkpoint | Physical footprint | Live nodes | 64-byte nodes | Live bytes when recorded |
|---|---:|---:|---:|---:|
| Before input | 66.4 MiB | 122,717 | 6,907 | — |
| After 10 commits | 77.9 MiB | 216,759 | 8,346 | — |
| After one minute idle | 78.8 MiB | 216,759 | 8,346 | — |
| After 10 more commits | 87.0 MiB | 216,807 | 8,490 | — |
| After another idle interval | 87.2 MiB | 216,367 | 8,050 | 50,632,195 |
| After 20 more commits | 87.4 MiB | 218,205 | 9,577 | 50,746,867 |
| After delayed cleanup | 87.4 MiB | 217,181 | 8,553 | 50,681,331 |
| After switching away from Chinese | 84.6 MiB | 182,886 | 5,826 | 47,335,233 |

The first input batch caused a large one-time increase dominated by tens of thousands of 48-byte and 16-byte allocations. The live heap then remained exactly stable during the first idle interval. This pattern is consistent with lazy initialization of prediction or input data, but the responsible allocation stacks were not captured.

The second input batch raised physical footprint substantially while adding little live heap. After further input, footprint approached a plateau near 87 MiB. This indicates allocator high-water behavior rather than an equivalent amount of newly retained objects.

Switching away from the Chinese keyboard released approximately 3.35 MiB of live heap and 34,295 nodes, showing that a significant portion belonged to the visible UI and document session. Approximately 8–9 MiB above the original live-heap baseline remained for the process lifetime, consistent with first-use engine or prediction data.

## Conclusions

- The untouched foreground growth was not caused by autosave or log-file length.
- The direct cause was publishing unchanged undo/redo state from the document poll.
- Equality guards on high-frequency `@Published` state eliminated the linear 64-byte allocation slope.
- Skipping the unchanged document-state update remains worthwhile because it avoids unnecessary polling work.
- First input has a separate approximately 10 MiB one-time cost that still requires allocation-stack attribution.
- Repeated input raised allocator high-water footprint, but the short controlled test approached a plateau instead of showing the previous time-based linear live-heap growth.
- Simulator footprint exceeded the approximate device keyboard-extension limit during the stress test, so model-loading improvements and real-device Release validation remain necessary.

## Follow-up work

- Repeat the first-input test with prediction disabled to determine whether the prediction model accounts for the one-time increase.
- Launch with malloc stack logging and capture the 16-byte, 48-byte, and large first-use allocation stacks.
- Compare KenLM's current read/populate behavior with a lazy file-backed mapping and verify dirty and resident pages using `vmmap`.
- Repeat the cold-start, first-input, sustained-input, and switch-away sequence on an OS64 Release build and a real device.
- Add a longer idle regression test so future changes can detect a small live-heap slope before it becomes an OOM issue.

The temporary one-minute autosave configuration was restored to the default, the test processes were terminated, and the unsent Messages draft was deleted after the measurements.
