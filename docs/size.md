# Default keyboard size

Simulator|Screen height|Screen width|Portrait height|Landscape height|Floating height
-|-|-|-|-|-
iPhone 16e|844|390|260|198|-
iPhone 16|852|393|260|198|-
iPhone 16 Pro|874|402|260|198|-
iPhone 16 Plus|932|430|270|198|-
iPhone 16 Pro Max|956|440|270|198|-
iPad mini (A17 Pro)|1133|744|260|348|255
iPad (A16)|1180|820|255|342|255
iPad Air 11-inch (M3)|1180|820|255|342|255
iPad Pro 11-inch (M4)|1210|834|260|348|255
iPad Air 13-inch (M3)|1366|1024|325|420|260*
iPad Pro 13-inch (M4)|1376|1032|325|420|255

\* Context menu mask shows that there is no padding top, which may not be the case for real device, so use 255 to unify.

## Xcode 26.6 / iOS 26.5 survey (2026-10-19)

The installed iOS 26.5 runtime (23F77) supports 65 device profiles. All profiles were audited; one representative of each of the 21 distinct physical screen, render-canvas, and scale combinations was measured in the simulator. Other profiles in the same row reuse that representative's result, rather than being counted as separate screenshot measurements. These combinations cover 20 distinct logical screen sizes.

The table below uses portrait UIKit screen dimensions in points. Physical pixel dimensions come from the SDK device profiles. The earlier keyboard-height records above are retained separately; a system keyboard's full frame also contains system-owned regions and should not be substituted directly for `totalHeight`.

| Measured representative | Other SDK profiles with the same screen/render configuration | Screen height (pt) | Screen width (pt) | UIKit scale | Physical height × width (px) | Fcitx height P / L / F (pt) |
|---|---|---:|---:|---:|---:|---:|
| iPhone 17 Pro | iPhone 17; iPhone 16 Pro | 874 | 402 | 3 | 2622 × 1206 | 260 / 198 / — |
| iPhone 17 Pro Max | iPhone 16 Pro Max | 956 | 440 | 3 | 2868 × 1320 | 270 / 198 / — |
| iPhone 17e | iPhone 16e; iPhone 14; iPhone 13 Pro; iPhone 13; iPhone 12 Pro; iPhone 12 | 844 | 390 | 3 | 2532 × 1170 | 260 / 198 / — |
| iPhone Air | — | 912 | 420 | 3 | 2736 × 1260 | 270 / 198 / — |
| iPhone 16 | iPhone 15 Pro; iPhone 15; iPhone 14 Pro | 852 | 393 | 3 | 2556 × 1179 | 260 / 198 / — |
| iPhone 16 Plus | iPhone 15 Pro Max; iPhone 15 Plus; iPhone 14 Pro Max | 932 | 430 | 3 | 2796 × 1290 | 270 / 198 / — |
| iPhone 14 Plus | iPhone 13 Pro Max; iPhone 12 Pro Max | 926 | 428 | 3 | 2778 × 1284 | 270 / 198 / — |
| iPhone SE (3rd generation) | iPhone SE (2nd generation) | 667 | 375 | 2 | 1334 × 750 | 260 / 198 / — |
| iPhone 13 mini | iPhone 12 mini | 812 | 375 | 3 | 2340 × 1080 | 260 / 198 / — |
| iPhone 11 Pro | — | 812 | 375 | 3 | 2436 × 1125 | 260 / 198 / — |
| iPhone 11 Pro Max | — | 896 | 414 | 3 | 2688 × 1242 | 270 / 198 / — |
| iPhone 11 | — | 896 | 414 | 2 | 1792 × 828 | 270 / 198 / — |
| iPad Pro 13-inch (M5) (16GB) | iPad Pro 13-inch (M5); iPad Pro 13-inch (M4) (16GB); iPad Pro 13-inch (M4) | 1376 | 1032 | 2 | 2752 × 2064 | 325 / 420 / 255 |
| iPad Pro 11-inch (M5) (16GB) | iPad Pro 11-inch (M5); iPad Pro 11-inch (M4) (16GB); iPad Pro 11-inch (M4) | 1210 | 834 | 2 | 2420 × 1668 | 260 / 348 / 255 |
| iPad Air 13-inch (M4) | iPad Air 13-inch (M3); iPad Air 13-inch (M2); iPad Pro (12.9-inch) (6th generation) (16GB); iPad Pro (12.9-inch) (6th generation); iPad Pro (12.9-inch) (5th generation); iPad Pro (12.9-inch) (4th generation); iPad Pro (12.9-inch) (3rd generation) | 1366 | 1024 | 2 | 2732 × 2048 | 325 / 420 / 255 |
| iPad Air 11-inch (M4) | iPad (A16); iPad Air 11-inch (M3); iPad Air 11-inch (M2); iPad (10th generation); iPad Air (5th generation); iPad Air (4th generation) | 1180 | 820 | 2 | 2360 × 1640 | 255 / 342 / 255 |
| iPad mini (A17 Pro) | iPad mini (6th generation) | 1133 | 744 | 2 | 2266 × 1488 | 260 / 348 / 255 |
| iPad Pro (11-inch) (4th generation) (16GB) | iPad Pro (11-inch) (4th generation); iPad Pro (11-inch) (3rd generation); iPad Pro (11-inch) (2nd generation); iPad Pro (11-inch) (1st generation) | 1194 | 834 | 2 | 2388 × 1668 | 260 / 348 / 255 |
| iPad (9th generation) | iPad (8th generation) | 1080 | 810 | 2 | 2160 × 1620 | 260 / 348 / 255 |
| iPad Air (3rd generation) | — | 1112 | 834 | 2 | 2224 × 1668 | 260 / 342 / 255 |
| iPad mini (5th generation) | — | 1024 | 768 | 2 | 2048 × 1536 | 260 / 348 / 255 |

The iPhone 17 uses 874 × 402 pt, compared with the iPhone 16's 852 × 393 pt. The iPhone Air adds 912 × 420 pt. The 17 Pro, Pro Max, and 17e share the recorded sizes of the 16 Pro, Pro Max, and 16e respectively. The M5 iPad Pro and M4 iPad Air profiles share the recorded dimensions of their M4 and M3 predecessors.

The iPhone 12/13 mini render a 375 × 812 pt UIKit canvas into a 1080 × 2340 px display. Their effective screenshot scale is approximately 2.88 px/pt, despite `UIScreen.scale` reporting 3. Both axes are normalized independently when comparing glyphs; dividing these screenshots by 3 would incorrectly suggest smaller labels.

The 414 × 896 pt iPhone 11 / 11 Pro Max class now uses a 270 pt portrait content height, matching the larger phone keyboard rather than the former 260 pt bucket. The 834 × 1194 pt 11-inch iPad Pro class now uses 260 / 348 pt for portrait / landscape, matching the other 11-inch Pro class rather than the former 255 / 342 pt Air bucket. The 834 × 1112 pt iPad Air (3rd generation) uses the compact 342 pt landscape height instead of 348 pt. Other historical default content heights are retained.

### Key-label calibration

Measurements use lowercase system Simplified Chinese Pinyin in a plain text field, with light appearance. iPad captures use a full-screen scene and actual device rotation. Portrait and landscape were captured for every measured screen class; every iPad class also has a floating capture.

| Keyboard state | iPhone label size | iPad label size |
|---|---:|---:|
| Portrait | 24.5 pt | 22 pt |
| Landscape | 21.5 pt | 27 pt |
| Floating | — | 24.5 pt |

These are the public system-font sizes selected for Fcitx5, using regular weight; they are not font properties read from Apple's private keyboard implementation. Label sizing is independent of the keyboard-height buckets. Unusually short custom rows may still reduce the font to 70% of row height.

The previous width threshold incorrectly selected 27 pt for 13-inch iPads in portrait. Phone landscape labels were also reduced to 19.8 pt by the old half-row-height limit. The measured state-based sizes above address both cases.

The [complete profile-to-measurement mapping and glyph measurements](keyboard-survey-ios26.5.csv) include the representative used for every profile. `p` bounds use a 50% grayscale threshold; stem thickness integrates antialiasing coverage over the lower straight section (78–90% of glyph height), with a 2 px margin. Screenshot dimensions are normalized to the measured UIKit viewport. The CSV distinguishes measured representatives from same-screen mappings.

Screenshots, accessibility snapshots for iPad, and the glyph contact sheet are retained in the worktree's ignored `build/native-label-survey/` directory.
