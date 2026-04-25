set -e

platform=$1
app="build/$platform/src/Fcitx5.app"

for appex in "$app/PlugIns"/*.appex; do
  /usr/bin/codesign --force --sign - --entitlements assets/keyboard.entitlements --deep "$appex"
done

/usr/bin/codesign --force --sign - --entitlements assets/app.entitlements --deep "$app"
