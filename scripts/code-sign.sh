set -e

platform=$1
app="build/$platform/src/Fcitx5.app"
plugins="$app/PlugIns"

for appex in $(ls $plugins); do
  /usr/bin/codesign --force --sign - --entitlements assets/keyboard.entitlements --deep "$plugins/$appex"
done

/usr/bin/codesign --force --sign - --entitlements assets/app.entitlements --deep "$app"
