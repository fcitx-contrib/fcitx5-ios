# Fcitx5 iOS

[Fcitx5](https://github.com/fcitx/fcitx5) input method framework ported to iOS.

## Build
This project is NOT managed by Xcode,
but Xcode is needed for iOS SDK.

### Install dependencies
```sh
brew install cmake extra-cmake-modules gettext
IOS_PLATFORM=SIMULATOR ./scripts/install-deps.sh
```

### Apply patches
```sh
git apply --directory=fcitx5 patches/fcitx5.patch
git apply --directory=engines/fcitx5-rime patches/rime.patch # if building with Rime
```

### Build with CMake
```sh
cmake -B build -G Xcode \
  -DRIME=ON \
  -DCMAKE_TOOLCHAIN_FILE=cmake/ios.cmake \
  -DIOS_PLATFORM=SIMULATOR
cmake --build build --config Debug
```

You can also use `Cmd+Shift+B` in VSCode to execute a task.

### Play with simulator
```sh
xcrun simctl list devices
xcrun simctl boot UUID
open /Applications/Xcode.app/Contents/Developer/Applications/Simulator.app
xcrun simctl install booted build/src/Debug-iphonesimulator/Fcitx5.app
```
After the first time you execute `xcrun simctl install`,
you need to add Fcitx5 in Settings -> General -> Keyboard -> Keyboards -> Add New Keyboard.

* Simulator is not emulator (virtual machine). Simulator file system is mapped from host filesystem. A process in simulator is a process in macOS.
* App and input method (custom keyboard extension) are different programs. They share a directory (via App Group) in ~/Library/Developer/CoreSimulator/Devices/UUID/data/Containers/Shared/AppGroup.

## Credits
* [fcitx5](https://github.com/fcitx/fcitx5): LGPL-2.1-or-later
* [fcitx5-android](https://github.com/fcitx5-android/fcitx5-android): LGPL-2.1-or-later
* [ios-cmake](https://github.com/sheldonth/ios-cmake): MIT
* [swift-cmake-examples](https://github.com/apple/swift-cmake-examples): Apache-2.0
* [AlertToast](https://github.com/elai950/AlertToast): MIT
