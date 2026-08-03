# AI Agent Instructions

## Project Overview

fcitx5-ios is an iOS input method built with CMake + Ninja (not managed by Xcode). Targets iOS ≥ 16.3 with three build platforms: `SIMULATORARM64` (Apple Silicon simulator), `SIMULATOR64` (Intel simulator), and `OS64` (device). This machine is Apple Silicon (`arm64`).

## Build

After changing code, always build for the arm64 simulator to verify the change compiles:

```sh
./scripts/patch.sh
cmake -B build/SIMULATORARM64 -G Ninja -DCMAKE_BUILD_TYPE=Debug -DPLATFORM=SIMULATORARM64
cmake --build build/SIMULATORARM64 && ./scripts/code-sign.sh SIMULATORARM64
```

If the change targets the device build (`OS64`, Release), build it in addition to the required simulator build:

```sh
cmake -B build/OS64 -G Ninja -DCMAKE_BUILD_TYPE=Release -DPLATFORM=OS64
cmake --build build/OS64
```

## Lint

Run the same lint/format checks as CI after changing code:

```sh
./scripts/lint.sh
./scripts/format.sh
```
