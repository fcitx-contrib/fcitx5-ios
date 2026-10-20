# Keyboard size and typography measurement workflow

Use this workflow when updating the native keyboard comparison, adding simulator models, changing label size or weight, or changing default keyboard heights. Start with [size.md](size.md), the applicable `keyboard-survey-ios*.csv`, `uipanel/height.swift`, and `uipanel/Key.swift`. The iOS 26.5 survey is an example of a completed experiment, not a permanent list of supported devices or font values.

## Prepare and inventory

1. Work in the relevant worktree. Record the project commit and local changes before building; preserve unrelated edits and existing simulator data. Generated screenshots, probe apps, measurements, and logs belong under the ignored `build/native-label-survey/` directory. Do not depend on a previous agent's `/private/tmp` scripts, simulator UUIDs, Appium sessions, WDA ports, or Xcode cache paths; retain any new helper source and invocation with the experiment artifacts.
2. Record the selected Xcode, simulator SDK, runtime version/build, host macOS, and measurement date. The SDK and the booted runtime can have different versions. Discover the currently installed runtime instead of hard-coding the previous survey's version.
3. Inventory every iPhone/iPad profile supported by that runtime, including profiles without an existing simulator instance. `simctl list devices available` alone is insufficient. Join the runtime's `supportedDeviceTypes` with device type metadata and read each device type's `Contents/Resources/profile.plist` through its discovered bundle path.
4. Record `mainScreenWidth`, `mainScreenHeight`, `mainScreenScale`, `defaultCanvasWidth`, `defaultCanvasHeight`, product family, device type identifier, and model name. Keep missing canvas fields explicit; verify the logical viewport at runtime. Group by product family, physical dimensions, scale, and render-canvas dimensions. Logical dimensions alone would incorrectly combine mini's downsampled display with a different phone display.
5. Measure one representative of each group in portrait and landscape, plus floating for each iPad group. Other profiles may reuse the representative's result only with an explicit `same-screen mapping` designation and representative name. Investigate model-specific differences or outliers separately. Report inventory, representative, and captured-state counts separately; never describe a mapping as an individually booted and measured device.

Useful inventory commands, run from the worktree:

```sh
mkdir -p build/native-label-survey
xcode-select -p
xcodebuild -version
xcrun --sdk iphonesimulator --show-sdk-version
xcrun simctl list runtimes -j > build/native-label-survey/runtimes.json
xcrun simctl list devicetypes -j > build/native-label-survey/devicetypes.json
xcrun simctl list devices available -j > build/native-label-survey/devices-before.json
git rev-parse HEAD
```

Save the joined inventory with the selected runtime's identifier, version, and build. In the 2026-10 experiment, 65 profiles formed 21 physical/render/scale groups, covering 20 logical sizes: 12 phone representatives × 2 states + 9 iPad representatives × 3 states = 51 native captures. Recompute these numbers on each run.

On a 16 GB host, keep at most two simulators booted during the survey; three caused severe memory pressure and launch stalls in the original experiment. Reuse existing devices without erasing them, and delete only temporary devices created by the current survey. Record and restore changed keyboard preferences. Build and sign the ARM64 simulator app using the commands in the root `AGENTS.md`, then install `build/SIMULATORARM64/src/Fcitx5.app` with `simctl install`.

## Use a controlled input host

Use the same plain UIKit `UITextField` for native and project captures. A small diagnostic app is useful: use `UIApplicationSceneManifest`, a `UIWindowSceneDelegate`, a full-screen window, and orientation support for portrait and both landscape directions. Keep it outside the product. Fix light appearance, record the content size category and display zoom, and disable field autocapitalization, autocorrection, and spell checking. Start with empty text, no preedit/candidates, and lowercase keys.

Observe `UIResponder.keyboardDidChangeFrameNotification`; record the end frame, host window bounds, screen bounds/scale, safe-area insets, and actual field input mode identifier. `UITextInputMode.activeInputModes` lists available modes; it does not prove which mode is selected. Do not override `UITextField.textInputMode` to pretend a keyboard was selected. Read the active mode from the real field, and confirm the displayed keys in the screenshot/accessibility tree.

For the native reference, select system Simplified Chinese Pinyin, whose mode identifier starts with `zh_Hans-Pinyin`. For the project, enable and select `org.fcitx.Fcitx5.Chinese`; use the extension's internal globe menu to select Pinyin and confirm the space label `拼音`. The system globe switches keyboard extensions; the project's globe selects an fcitx engine. Do not compare native Pinyin with an English keyboard, Hallelujah, or a different project engine. Full Access is not required for this simulator experiment; leave its setting unchanged.

Switch keyboards through the system UI when possible. If a probe uses private input-mode selectors for automation, keep them in the diagnostic app and retain the probe source as evidence. Never add these APIs to production code. Avoid Ctrl-Space as a measurement shortcut: it can insert text or hide the software keyboard.

## Capture valid states

Use actual simulator device rotation through XCTest/Appium (`driver.orientation = "PORTRAIT"` / `"LANDSCAPE"`) or the Simulator UI. A probe's orientation request alone is insufficient evidence that the device rotated. A legacy iPad host and `UIDevice` orientation overrides produced a compatibility-sized, scaled window in the original experiment; those captures were excluded.

Before accepting each native or project capture:

- Confirm the host's window dimensions and screenshot orientation agree with the expected screen class. For a full-screen scene, verify the viewport covers the device's logical screen instead of an iPhone compatibility window or a resized iPad app window.
- Wait for the keyboard to finish appearing and for its frame and key layout to stabilize. Reacquire focus if starting WDA interrupted the host. Wait on observable geometry/input mode, with a bounded timeout; a fixed delay alone is not validation.
- Confirm the actual keyboard/engine, lowercase state, and absence of first-use dialogs, candidate overlays, selection menus, or animations. The original native accessibility tree exposed `p` as a key and the project exposed it as static text; this is a useful corroborating check, not a universal API guarantee.
- Capture the raw PNG, accessibility XML, and measurement JSON together. Record device/profile, state, keyboard identity, viewport in points, screenshot dimensions in pixels, notification frame, accessible keyboard/container frame, safe areas, appearance, and source commit. Save the crop bounding box and analysis parameters with derived metrics.
- Inspect every representative's glyph crop in a contact sheet. Automated shape matching must not silently select another letter, a numeric hint, toolbar text, or a glyph in the host app. Exclude failed or ambiguous captures from completed results.

Appium screenshots normally follow device orientation. `simctl io <udid> screenshot <path>` can produce a portrait-oriented framebuffer during landscape; rotate by an exact multiple of 90 degrees before locating glyphs. Preserve the raw file and the transform, and do not resize measurement images. Thumbnail and nearest-neighbor enlarged crops are for visual review only.

Project SwiftUI accessibility frames can be local to the keyboard, while ancestors use screen coordinates or rotated coordinates. Resolve the coordinate spaces before tapping or measuring; do not treat a key's local `y` as a screen `y`. Verify taps with the resulting UI state.

On iPad, also capture floating mode. Use the system floating-keyboard UI, or a documented preference change on a temporary survey simulator. The original runtime accepted `com.apple.keyboard.preferences` → `KeyboardIsFloating`, applied before relaunching the host; this is a private simulator detail that must be revalidated for another runtime. Save and restore its prior value. Verify the actual floating keyboard frame in the accessibility tree: the original runtime used approximately 320 pt width. Floating frame notifications sometimes reported zero height or a stale docked frame, so those notifications alone cannot validate floating geometry.

## Quantify label size and weight

Use lowercase `p` as the primary reference because its descending straight stem makes thickness measurable. Also inspect the complete keyboard and a few other labels so one glyph cannot hide a poor overall match. Compare native and project screenshots from the same device, state, host, appearance, and capture path.

Normalize using the actual oriented screenshot and host viewport, independently on both axes:

```text
scale_x = screenshot_width_px / viewport_width_pt
scale_y = screenshot_height_px / viewport_height_pt
glyph_width_pt = glyph_width_px / scale_x
glyph_height_pt = glyph_height_px / scale_y
stem_width_pt = stem_width_px / scale_x
```

Do not assume `UIScreen.scale` is the capture scale. The iPhone 12/13 mini reported 375 × 812 pt at scale 3 but produced 1080 × 2340 px screenshots: effective scale was about 2.88 px/pt. On iPad floating captures, use the full host viewport to normalize the full screenshot; do not divide full-screen screenshot width by floating keyboard width.

The original metric uses Pillow grayscale conversion and these conventions:

1. Locate the `p` component using pixels with grayscale `< 128` (50% threshold); use eight-connected components or a reviewed crop to isolate it. Record its exclusive bounding box `(x0, y0, x1, y1)` and dimensions `w = x1 - x0`, `h = y1 - y0`.
2. Take a crop extending 2 raw pixels beyond every side of the bounding box. On its white key background, compute antialiasing coverage `ink = 1 - grayscale / 255`. Exclude other labels and key borders from this crop.
3. For each row in `[2 + round(0.78*h), 2 + round(0.90*h))`, sum coverage across the crop width. The median row sum is stem thickness in pixels. This lower stem band avoids the bowl; inspect the band if a new font changes the shape. The 2 px margin, band fractions, threshold, and rounding convention must be retained for comparable results.
4. Normalize the raw dimensions and stem thickness to points, then calculate project-minus-native differences. Report width, height, and stem error separately; do not turn a thickness match into a claim that the entire glyph matches.

Do not measure after resizing crops. Template matching can resize a copy for locating a glyph, but the accepted bounds and all metrics must come from the original pixels. A high match score does not replace visual inspection. If appearance, background, threshold, or metric changes, document it and remeasure the comparison pair; do not mix incompatible series.

For reference, the final iPhone 17 landscape comparison in iOS 26.5 measured native `p` at 29 × 45 px, stem 5.361 px, and project `p` at 31 × 45 px, stem 5.482 px (about +2.26%) at 3 px/pt. The selected project font was system regular, 21.5 pt. These are reproducibility examples, not exact targets for future runtimes or a claim that Apple's private keyboard font properties were read.

## Separate content height from system regions

Keep screen dimensions, the full system keyboard frame, the project's UIKit container, and the SwiftUI content height as separate measurements. The full frame can include the system assistant bar, safe area, globe/dictation region, and padding. Do not copy its height directly into `getDefaultTotalHeight()`.

Infer the comparable content region from screenshot/key-row geometry and the accessibility hierarchy, then verify it against an actual project capture. Record system padding and any assumptions. Different device classes can share font sizes but need different content heights. Compare new models with their predecessors using both SDK profile dimensions and measured UIKit viewports; do not infer geometry from product names alone.

The code divides content height into a 20% toolbar and 80% keyboard. Check the row geometry and clipping as well as the outer frame. For historical context, the old iPad Air 13-inch M3 floating record is 260 pt, while the configured default is 255 pt because of the observed padding difference. Preserve that observation and explanation; a configured CSV value must not overwrite the original measurement.

## Update documents and code together

| Location | What to maintain |
|---|---|
| `docs/size.md` | Human-readable tables, experiment versions/dates, measurement conditions, generational screen changes, historical observations, padding exceptions, and the reasons for code changes. Retain earlier records; add a clearly dated survey or comparison instead of silently rewriting history. |
| `docs/keyboard-survey-ios<runtime>.csv` | One row per supported profile: representative/mapping status, portrait screen dimensions, physical dimensions, reported scale, configured content heights, native `p` metrics and effective capture scales for each measured state, and selected project font sizes. Use a new versioned file for a new runtime; document additional metadata/schema changes in `size.md`. |
| `uipanel/height.swift` | `getDefaultTotalHeight()` height buckets and `getKeyLabelFontSize(_:)` font targets. Use measured geometry and keyboard state; document exceptions and check neighboring buckets. Keep font size independent of total content height except for the short-row cap. |
| `uipanel/Key.swift` | The system-font weight and application of the calibrated label size. Changing weight should be justified by measured stem coverage as well as the full-keyboard comparison. |

In the current CSV, `*_p_*` values describe the native reference, `*_fcitx_font_pt` is the selected public font size for the project, and `default_*_height_pt` is the configured project content height. Same-screen rows copy the representative's native metrics and must identify it. Keep project comparison metrics separately in the experiment artifacts unless the CSV schema explicitly adds corresponding columns. Blank phone floating fields mean not applicable; they are not zero-height measurements. The CSV does not contain all the historical and methodological information in `size.md`.

Check that every supported profile appears exactly once, every mapping points to an actual measured representative, every representative has all required states, and the Markdown table agrees with CSV dimensions and configured heights. Recompute point metrics from raw pixels and per-axis scales. Serialize CSV with `lineterminator="\n"`; CRLF was flagged by `git diff --check` in the original run. Preserve prose paragraphs without fixed-width hard wrapping.

Change only the buckets or font rules supported by evidence. Recheck affected neighbors: small/large phones, mini downsampling, old 11-inch Pros versus Air, 13-inch iPad portrait versus landscape, and iPad floating. If an apparent height failure is clipping or stale layout, investigate the lifecycle separately instead of compensating with a different default height.

## Verify and hand off

After code changes, run the ARM64 simulator build/sign and lint/format commands from the root `AGENTS.md`. Install the final build and capture the actual project keyboard for changed states; a SwiftUI preview or standalone font sample cannot prove extension layout. Check `git diff --check` and ensure only intended files are staged; submodule patch changes and spreadsheet lock files are not survey changes.

Include this minimal lifecycle regression test on iPhone 17: show the Chinese keyboard in landscape, dismiss it with its toolbar chevron, rotate to normal portrait, tap the text field to reopen it, and verify that the toolbar and bottom row are fully visible. The original failure kept a 198 pt container around 260 pt portrait content, clipping 31 pt from each end. The regression was introduced by `25bb499` (#140) and fixed by `f5201fc` (#154) using intrinsic content size invalidation on the hosting controller. Also check the reverse direction and rotation with the keyboard visible when changing height/layout behavior. On iPad, include docked and floating transitions for changes that affect them.

When attributing a new failure, run the same host and actions against the pre-change code. If needed, isolate a suspected historical change while keeping the other code and dependencies constant. Retain the comparison patches/commits and screenshots, distinguish such an isolated reversal from running the entire historical checkout, and keep an unrelated regression fix separate from typography calibration.

Hand off the exact commit, Xcode/runtime versions, representative and mapping counts, verified states, artifact paths, changed font/height rules, remaining discrepancies, and build/check results. Do not claim all profiles were screenshot-tested, exact parity with native rendering, or real-device behavior based only on simulator evidence.
