#!/bin/zsh
set -e

SVG_ICON="fcitx5/data/icon/scalable/apps/org.fcitx.Fcitx5.svg"
APP_NAME="Fcitx5"
ASSETS_DIR="build/assets"
APPICON_SET="$ASSETS_DIR/AppIcon.appiconset"
ACTOOL_OUT="$ASSETS_DIR/actool_out"

# Format: size scale name
declare -a ICON_SPECS=(
  "20 2 icon-20x2.png"
  "20 3 icon-20x3.png"
  "29 2 icon-29x2.png"
  "29 3 icon-29x3.png"
  "40 2 icon-40x2.png"
  "40 3 icon-40x3.png"
  "60 2 icon-60x2.png"
  "60 3 icon-60x3.png"
  "76 2 icon-76x2.png"
  "83.5 2 icon-83.5x2.png"
  "1024 1 icon-1024x1.png" # App Store icon
)

rm -rf "$ASSETS_DIR"
mkdir -p "$APPICON_SET" "$ACTOOL_OUT"

echo "🖼️  Generating PNG icons from $SVG_ICON"
for spec in "${ICON_SPECS[@]}"; do
  read -r size scale filename <<< "$spec"
  pixel_size=$(awk "BEGIN {printf \"%d\", $size * $scale}")
  echo " → $filename ($pixel_size x $pixel_size)"
  rsvg-convert -w "$pixel_size" -h "$pixel_size" "$SVG_ICON" -o "$APPICON_SET/$filename"
done

echo "📝 Generating Contents.json"

cat > "$APPICON_SET/Contents.json" <<EOF
{
  "images": [
EOF

first=true
for spec in "${ICON_SPECS[@]}"; do
  read -r size scale filename <<< "$spec"
  idiom="iphone"
  if [[ "$size" == "83.5" ]]; then
    idiom="ipad"
  elif [[ "$size" == "76" ]]; then
    idiom="ipad"
  elif [[ "$size" == "1024" ]]; then
    idiom="ios-marketing"
  fi

  [[ "$first" == true ]] && first=false || echo "    }," >> "$APPICON_SET/Contents.json"

  cat >> "$APPICON_SET/Contents.json" <<EOF
    {
      "size": "${size}x${size}",
      "idiom": "$idiom",
      "filename": "$filename",
      "scale": "${scale}x"
EOF
done

cat >> "$APPICON_SET/Contents.json" <<EOF
    }
  ],
  "info": {
    "version": 1,
    "author": "shell"
  }
}
EOF

echo "📦 Compiling .xcassets using actool"

xcrun actool \
  --output-format human-readable-text \
  --notices \
  --warnings \
  --platform iphoneos \
  --minimum-deployment-target 17.0 \
  --app-icon AppIcon \
  --output-partial-info-plist build/partial.plist \
  --compile "$ACTOOL_OUT" \
  "$ASSETS_DIR"
