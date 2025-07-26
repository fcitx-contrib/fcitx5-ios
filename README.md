English
|
[中文](README.zh-CN.md)

# Fcitx5 iOS

[Fcitx5](https://github.com/fcitx/fcitx5) input method framework ported to iOS.

Currently developer beta. Please download [IPA](https://github.com/fcitx-contrib/fcitx5-ios/releases/tag/latest) and install with [SideStore](https://github.com/SideStore/SideStore).

Note: Without developer account, certain features won't work, such as configuring keyboard in main app.

## Build for simulator
This project is NOT managed by Xcode,
but Xcode is needed for iOS SDK.

Below assumes Apple Silicon.
For Intel, replace all `SIMULATORARM64` with `SIMULATOR64`.

### Install dependencies
```sh
brew install cmake gettext pkg-config
./scripts/install-deps.sh SIMULATORARM64
```

### Apply patches
```sh
git apply --directory=fcitx5 patches/fcitx5.patch
git apply --directory=engines/libime/src/libime/core/kenlm patches/kenlm.patch
git apply --directory=engines/fcitx5-rime patches/rime.patch # if building with Rime
git clone https://github.com/google/mozc engines/fcitx5-mozc/mozc --depth=1 --recurse-submodules # if building with Mozc
```

### Build with CMake
```sh
cmake -B build/SIMULATORARM64 -G Xcode \
  -DURL_SCHEME=fcitx \
  -DCHINESE_ADDONS=ON \
  -DHALLELUJAH=ON \
  -DMOZC=ON \
  -DRIME=ON \
  -DPLATFORM=SIMULATORARM64
cmake --build build --config Debug
```

You can also use `Cmd+Shift+B` in VSCode to execute a task.

### Play with simulator
```sh
xcrun simctl list devices
xcrun simctl boot UUID
open /Applications/Xcode.app/Contents/Developer/Applications/Simulator.app
xcrun simctl install booted build/SIMULATORARM64/src/Debug-iphonesimulator/Fcitx5.app
```
After the first time you execute `xcrun simctl install`,
you need to add Fcitx5 in Settings -> General -> Keyboard -> Keyboards -> Add New Keyboard.

* Simulator is not emulator (virtual machine). Simulator file system is mapped from host filesystem. A process in simulator is a process in macOS.
* App and input method (custom keyboard extension) are different programs. They share a directory (via App Group) in ~/Library/Developer/CoreSimulator/Devices/UUID/data/Containers/Shared/AppGroup.
* Simulator doesn't have memory limit for keyboard extension.

## Build for iOS device
Generate an unsigned IPA and install it with SideStore.

Below assumes you've already done with simulator.

```sh
./scripts/install-deps.sh OS64
# By default enable chinese-addons only, as there is a 77 MB memory limit for keyboard process.
cmake -B build/OS64 -G Xcode -DURL_SCHEME=fcitx -DPLATFORM=OS64
cmake --build build/OS64 --config Debug -- CODE_SIGNING_ALLOWED=NO
cd build/OS64/src/Debug-iphoneos && rm -rf Payload Fcitx5.ipa && mkdir Payload
cp -r Fcitx5.app Payload && zip -r Fcitx5.ipa Payload
```

## Real device debug

### OOM
There is a 77 MB memory limit for keyboard extension.
When memory approaches the limit, you will see in Console.app like `Received memory warning.` for the process.
Later if memory exceeds the limit, you will see
```
memorystatus: keyboard [14871] exceeded mem limit: ActiveHard 77 MB (fatal)
memorystatus: killing process 14871 [keyboard] in high band FOREGROUND (100) - memorystatus_available_pages: 121469
keyboard[14871] Corpse allowed 1 of 5
1817600.392 memorystatus: killing_specific_process pid 14871 [keyboard] (per-process-limit 100 16s rf:-) 78848KB - memorystatus_available_pages: 121472
```

### Memory monitor
Use `/Applications/Xcode.app/Contents/Applications/Instruments.app`'s `Activity Monitor`.

### Crash
Crash reports are available in `Settings` -> `Privacy & Security` -> `Analytics & Improvements` -> `Analytics Data`.
Send them to mac and open with Console.app.

## Credits
* [fcitx5](https://github.com/fcitx/fcitx5): LGPL-2.1-or-later
* [fcitx5-android](https://github.com/fcitx5-android/fcitx5-android): LGPL-2.1-or-later
* [ios-cmake](https://github.com/leetal/ios-cmake): BSD-3-Clause
* [swift-cmake-examples](https://github.com/apple/swift-cmake-examples): Apache-2.0
* [AlertToast](https://github.com/elai950/AlertToast): MIT
