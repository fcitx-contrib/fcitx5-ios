# AI Agent Instructions

## Project Overview

fcitx5-ios is an iOS input method built with CMake + Ninja (not managed by Xcode). Targets iOS ≥ 16.3 with three build platforms: `SIMULATORARM64` (Apple Silicon simulator), `SIMULATOR64` (Intel simulator), and `OS64` (device). This machine is Apple Silicon (`arm64`).

## Keyboard Runtime Architecture

- `KeyboardViewController` is the iOS lifecycle/composition layer. Each controller creates one immutable Swift UUID when it is initialized and uses that UUID as the fcitx `program` value for its entire lifetime. Never derive this identity from the object's memory address because a later controller may reuse the address.
- `iosfrontend` owns iOS document routing and the lifecycle of `IosInputContext`. A live input context corresponds to `(program, documentIdentifier)`, where `documentIdentifier` comes from `UITextDocumentProxy`. Frontend callbacks such as commit, preedit, delete-surrounding-text, and forward-key must continue to validate this pair before modifying the document.
- Each live fcitx `InputContext` also has a C++ UUID assigned by `InputContextManager`. The iOS document identity and the C++ UUID correspond through the live `IosInputContext` object, but they are different identifiers and there is intentionally no persistent mapping after the input context is destroyed.
- `uipanel` is a generic fcitx UI addon and must not include `iosfrontend` headers, cast to `IosInputContext`, or look up the `iosfrontend` addon. It sends the `InputContext` UUID to Swift as an opaque token and resolves UI operations with `InputContextManager::findByUUID()`.
- Every context-specific UI operation, including candidate selection/actions, candidate tab actions, paging, bulk scrolling, and status-area actions, must carry the originating InputContext token. Do not use `mostRecentInputContext()` for these operations because asynchronous UI events can otherwise target a different context.
- UI update callbacks are accepted only when both the controller `program` is current and the InputContext token still resolves to a focused context. In `FcitxProtocol`, `isCurrentDocument` is for frontend document callbacks and `isCurrentProgram` is for UI callback routing.
- Name parameters that carry the C++ UUID `inputContext` or `inputContextToken`, never `documentIdentifier`. Reserve `documentIdentifier` for the identifier supplied by iOS.

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
