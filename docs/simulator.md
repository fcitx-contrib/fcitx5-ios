# Differences between simulator and real device

## Memory limit
Simulator doesn't have the 77MB memory limit for keyboard extension.

## Clipboard
To access system clipboard, full access is needed on real device but not on simulator.

## Log level
Simulator's debug level log doesn't show on Console.app, so we lift all debug logs to info.

## Log string interpolation
Simulator's log string interpolation visibility defaults to public, while real device defaults to private. We make it public on real device as well, otherwise it's completely useless.

## App Group
App Group is available on simulator, while on real device it needs a paid developer account (i.e., unavailable for side load).

When unavailable, main app and keyboard extensions can's share file system, so they have separate storages in their Documents directories.
In that case, we start an HTTP server to sync files.

To test the HTTP server on simulator, set `useAppGroup = false`.

## Jump to app settings
An app can't jump to its settings on simulator, while it does work on real device.

## Directories
Simulator directories all have prefix `~/Library/Developer/CoreSimulator/Devices/DEVICE_UUID/data/Containers/`.

-|Simulator|Real device
-|-|-
App Bundle|Bundle/Application/APP_BUNDLE_UUID/Fcitx5.app|/private/var/containers/Bundle/Application/APP_BUNDLE_UUID/App.app
App documents|Containers/Data/Application/APP_UUID/Documents|/private/var/mobile/Containers/Data/Application/APP_UUID/Documents
Keyboard documents|Containers/Data/PluginKitPlugin/PLUGIN_UUID/Documents|/private/var/mobile/Containers/Data/PluginKitPlugin/PLUGIN_UUID/Documents
App Group|Containers/Shared/AppGroup/GROUP_UUID
