# Chinese keyboard memory investigation, September 2026

This note preserves the controlled observations from an investigation of Chinese keyboard extension memory growth. The absolute values came from a Debug simulator build and are not device memory budgets.

## Environment

- Date: September 23–26, 2026.
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

## Lazy mmap change

On Apple platforms, `StaticLanguageModelFile` now sets KenLM's `load_method` to `util::LAZY`. Other platforms retain KenLM's existing default. This keeps the main binary model file-backed on Darwin without changing its format, lookup structures, or scoring code.

The same simulator, application, document, keyboard, and input sequence were sampled immediately before and after the change:

| Checkpoint | Previous loader | Lazy mmap | Difference |
|---|---:|---:|---:|
| Visible keyboard physical footprint | 74.6 MiB | 66.7 MiB | -7.9 MiB |
| Visible keyboard live heap | 38,478,339 bytes | 30,230,195 bytes | -8,248,144 bytes |
| `MALLOC_LARGE` regions | 15.8 MiB in 3 regions | 8 MiB in 2 regions | One 8,016 KiB region removed |
| After first `nihao` candidate generation, physical footprint | 87.4 MiB | 77.5 MiB | -9.9 MiB |
| After first `nihao` candidate generation, live heap | 50,909,674 bytes | 39,868,288 bytes | -11,041,386 bytes |

Before the change, `vmmap` showed an anonymous 8,016 KiB `MALLOC_LARGE` region and no path for `zh_CN.lm`. After the change, that allocation was replaced by an 8,016 KiB read-only mapping backed by `zh_CN.lm`; the first cold sample reported only 48 KiB resident in that mapping. The two pre-existing 4,096 KiB anonymous regions remained and are outside the part improved by this change.

The mapped runtime region is smaller than the complete model file because KenLM does not map the trailing vocabulary strings when vocabulary enumeration is not requested.

Functional validation produced the same first candidate, `你好`, for `nihao`. With existing context, entering `zhongguo` produced and successfully committed `你好中国`. This exercises model loading, lookup, context scoring, candidate generation, prediction initialization, and continued access to the file-backed model.

The model mapping remained valid for the extension lifetime and was removed when the test process terminated. KenLM's `scoped_memory` owns the mapping and calls `munmap` when the model is destroyed.

## Full model comparison

Commit `779dd3c` changed the packaged Chinese addon data from `chinese-addons-any.tar.bz2` to `chinese-addons-slim.tar.bz2` to reduce OOM frequency. After enabling lazy mmap, the same simulator workflow was repeated with the full model to determine whether the slim model was still needed for runtime memory.

The prediction file was identical in both archives. Only the main KenLM model changed:

| Asset | Slim archive | Full archive | Difference |
|---|---:|---:|---:|
| `zh_CN.lm` | 10,483,356 bytes | 34,736,327 bytes | +24,252,971 bytes |
| `zh_CN.lm.predict` | 2,576,105 bytes | 2,576,105 bytes | 0 |

The full model was tested with the same lazy mmap code, simulator, Messages document, visible keyboard state, and first `nihao` candidate-generation sequence:

| Checkpoint | Slim model with lazy mmap | Full model with lazy mmap | Difference |
|---|---:|---:|---:|
| Visible keyboard physical footprint | 66.7 MiB | 66.5 MiB | -0.2 MiB |
| Visible keyboard live heap | 30,230,195 bytes | 30,289,301 bytes | +59,106 bytes |
| Visible keyboard live nodes | 122,348 | 122,454 | +106 |
| After first `nihao` candidate generation, physical footprint | 77.5 MiB | 76 MiB | -1.5 MiB |
| After first `nihao` candidate generation, live heap | 39,868,288 bytes | 39,811,637 bytes | -56,651 bytes |
| After first `nihao` candidate generation, live nodes | 231,707 | 231,693 | -14 |

These small positive and negative differences are run-to-run noise rather than evidence that the full model uses less memory. The important result is that the additional 24,252,971 file bytes did not become an equivalent anonymous allocation or live-heap increase.

For the full model, `vmmap` showed a 31 MiB read-only file-backed runtime mapping. The cold sample reported no resident pages in that mapping; after generating the first `nihao` candidates, 8,592 KiB was resident. The first candidate remained `你好`. This behavior confirms that lazy mmap faults in the model pages needed by the query rather than making the full model resident at load time.

The full model therefore has approximately the same measured simulator runtime memory as the slim model for cold startup and the first candidate query. Its remaining cost is application and download size: `zh_CN.lm` grows by approximately 23.1 MiB uncompressed, and the downloaded Chinese addon archive grows from approximately 25 MiB to 46 MiB. A real-device OS64 Release run remains necessary to validate memory-pressure behavior before treating the simulator result as a device-memory guarantee.

## Remaining prediction trie risk

The lazy mmap change applies only to the main KenLM binary model. The 2,576,105-byte `zh_CN.lm.predict` file is still loaded by `DATrie<float>::load` into several heap arrays on first prediction and retained by `StaticLanguageModelFile` for the rest of its lifetime. The large first-input increase therefore remains a separate optimization target.

The current lazy initialization uses mutable `predictionLoaded_` and `prediction_` fields without synchronization. The iOS input path currently serializes engine work, but the libime object itself does not make concurrent first prediction safe. Any future change that unloads and reloads the prediction trie on memory warnings must first add explicit synchronization or otherwise guarantee single-thread access.

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
- Lazy mmap removed the main model's 8,016 KiB anonymous allocation and reduced the visible-keyboard simulator footprint by 7.9 MiB in the controlled cold comparison.
- With lazy mmap enabled, restoring the full model did not materially change cold or first-query simulator live heap and footprint compared with the slim model.
- First input still has a separate large one-time cost that requires allocation-stack attribution.
- Repeated input raised allocator high-water footprint, but the short controlled test approached a plateau instead of showing the previous time-based linear live-heap growth.
- Simulator footprint exceeded the approximate device keyboard-extension limit during the stress test, so model-loading improvements and real-device Release validation remain necessary.

## Follow-up work

- Repeat the first-input test with prediction disabled to determine whether the prediction model accounts for the one-time increase.
- Launch with malloc stack logging and capture the 16-byte, 48-byte, and large first-use allocation stacks.
- Repeat the cold-start, first-input, sustained-input, and switch-away sequence on an OS64 Release build and a real device.
- Compare candidate quality and application-size impact of the full and slim models so the packaging decision accounts for more than runtime memory.
- Add a longer idle regression test so future changes can detect a small live-heap slope before it becomes an OOM issue.

The temporary one-minute autosave configuration was restored to the default, the test processes were terminated, and the unsent Messages draft was deleted after the measurements.
