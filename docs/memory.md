# Keyboard extension memory profiling

This document describes a repeatable process for investigating memory growth in the keyboard extensions. It focuses on distinguishing live-heap growth from one-time initialization, allocator high-water marks, file mappings, and lifecycle-scoped UI state.

See [Chinese keyboard memory investigation, September 2026](memory-investigations/chinese-2026-09.md) for a worked example using this process.

## Memory constraints

Keyboard extensions have a much smaller memory budget than ordinary applications. The current observed on-device limit is approximately 77 MB, and iOS may terminate an extension that exceeds it.

The simulator does not enforce this limit. Simulator measurements are useful for attribution and comparing builds, but the final memory budget must be verified with a Release build on a real device.

Debug and Release builds, different engines, model files, OS versions, and device architectures can have substantially different baselines. Always record the environment with the measurements.

## Use the right measurement

No single number explains memory behavior.

| Measurement | Best use | Important limitation |
|---|---|---|
| `footprint` Physical footprint | Estimate the memory pressure relevant to jetsam and extension OOM | Can remain high after objects are freed because malloc retains dirty pages |
| `heap` node and byte totals | Measure currently live malloc allocations and compare allocation-size histograms | Does not identify `non-object` call stacks unless malloc stack logging was enabled at process launch |
| `vmmap -summary` | Separate anonymous malloc regions from file-backed mappings and inspect dirty versus clean pages | Virtual size alone is not resident memory |
| `ps` RSS | Quick process discovery and coarse observation | Includes shared simulator and framework pages and can greatly overstate extension-owned memory |
| Instruments Allocations/Leaks | Attribute allocations to code paths and inspect generations | More intrusive and should be used after a smaller command-line test has isolated the phase |

Treat `footprint` as the primary OOM signal and `heap` as the primary live-allocation signal. A rising footprint with a stable live heap usually indicates allocator high-water behavior, fragmentation, or newly dirtied pages rather than a classic leak.

## Standard simulator procedure

Build, sign, and install the exact build under test. Terminate the existing extension before each cold-start run so that process-lifetime state is not carried into the next sample.

Find the extension process:

```sh
ps ax -o pid=,etime=,command= | rg '/Chinese\.appex/Chinese'
```

Capture the same set of measurements at every checkpoint:

```sh
footprint <pid>
heap <pid>
vmmap -summary <pid>
```

Record at least the following phases:

1. Extension preloaded but not visible.
2. First time the keyboard is visible.
3. Visible and untouched for a fixed interval.
4. First key press.
5. First candidate commit.
6. A fixed number of additional commits.
7. Another untouched interval.
8. After switching to another keyboard.
9. After terminating and relaunching the extension.

The distinction between preload and first display matters. Selecting a keyboard can start its extension before its UI is actually visible.

Keep the foreground application, document contents, keyboard layout, engine, model files, build type, and sampling intervals constant across an A/B comparison. Memory tools can perturb timing, so compare repeated tests with the same sequence rather than isolated absolute values.

## Classify the observed pattern

| Pattern | Likely interpretation |
|---|---|
| Live heap grows approximately linearly while untouched | Timer, polling callback, notification, or unbounded cache |
| Live heap grows with every user operation | Retained operation state, history, cache, or leak in the operation path |
| A large increase occurs on first use and then stabilizes | Lazy initialization or a model loaded on demand |
| Live heap stabilizes but footprint rises and later plateaus | Malloc high-water mark, fragmentation, or dirty pages retained by the allocator |
| Memory falls when switching keyboards | UI or controller-lifecycle state |
| Memory is released only when the process exits | Process-level engine, model, or cache state |
| A model appears as a file-backed mapping | The loader may allow clean pages to be reclaimed and may fault pages lazily |
| A model appears only in anonymous malloc regions | The loader copied or transformed it into heap memory |

Do not label a footprint increase as a leak without also checking the live heap. Conversely, a small but linear live-heap slope is important even when footprint changes only in occasional page-sized steps.

## High-frequency observable state

Assignments to `@Published` properties are observable events, even when the new value equals the old value. `@Published` does not automatically perform an equality check.

Code called from a timer, document poll, layout callback, or candidate update should avoid publishing unchanged values:

```swift
if property != newValue {
  property = newValue
}
```

An unchanged assignment can still invoke `objectWillChange`, invalidate SwiftUI views, and create Combine, SwiftUI, or AttributeGraph update work. Multiple publications in the same run-loop turn may be coalesced, so the allocation rate may follow callback frequency rather than the number of assigned properties.

Apply equality guards at the state-owner boundary rather than relying only on individual callers. Also avoid invoking the entire update path when the source state is unchanged.

## Models and file loading

Model file size is not the same as runtime cost. A loader may map a file, read it into an anonymous buffer, create decoded data structures, or temporarily hold both the source and destination.

For every model-related change, record:

- Model file sizes.
- File-backed mappings visible in `vmmap`.
- Anonymous `MALLOC_LARGE` allocation sizes.
- Physical footprint before initialization, after initialization, and after first use.
- Whether the pages are clean, dirty, or reclaimable.

A lazy file mapping is useful only if the access pattern leaves a meaningful portion of the file untouched or allows clean pages to be reclaimed. Verify the result with `vmmap` and footprint measurements rather than assuming `mmap` alone reduces memory pressure.

## Timers, autosave, and logs

To attribute periodic growth, temporarily shorten one timer at a time and confirm execution through existing logs. Restore the user configuration and terminate the test process after the experiment so that a temporary interval does not remain active in memory.

File-backed logging does not imply that the entire log is retained in process memory. Check how the file is opened and written before attributing growth to its length. In this project, the keyboard redirects standard error to the App Group log file; the file is truncated on process launch and appended through the file descriptor during that process lifetime.

When the keyboard extension is suspended in the background, Swift timers and the fcitx event loop do not continue running. A test that switches away from the keyboard is therefore a lifecycle test, not an active-idle timer test.

## Regression checklist

Use the same checklist after a memory-related change:

- Keep the keyboard visible and untouched for at least 10 minutes; the live-heap slope should be approximately zero.
- Observe at least one autosave before and after the change.
- Record the first-input and first-commit one-time increases separately from the idle baseline.
- Perform 50 to 100 commits and verify that footprint approaches a plateau.
- Stop interacting and verify that the live heap no longer grows.
- Switch to another keyboard and record which UI and session allocations are released.
- Relaunch the extension to distinguish process-lifetime state from persistent files.
- Repeat the final test on a real device with an OS64 Release build and retain headroom below the device memory limit.

## Reporting template

Every investigation should record:

```text
Date:
Commit and local changes:
Platform and OS:
Build type:
Extension and engine:
Model file sizes:
Configuration changes:
Foreground application and document state:
Automation or manual input sequence:

Checkpoint | Elapsed time | Physical footprint | Peak footprint | Live nodes | Live bytes | Relevant allocation sizes

Conclusion:
Confirmed cause:
Inferences still requiring attribution:
Configuration restored:
Test process terminated:
```

Keep exact experiment results in a dated investigation note. Keep this document limited to procedures and conclusions that remain useful across investigations.
