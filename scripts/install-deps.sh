deps=(
  boost
  curl
  ecm
  fmt
  glog
  json
  leveldb
  libintl
  libmozc
  librime
  libuv
  lua
  marisa
  opencc
  yaml-cpp
  zstd
)

PLATFORM=$1

EXTRACT_DIR=build/$PLATFORM/usr
SPELL_DICT_DIR=$EXTRACT_DIR/share/fcitx5/spell
mkdir -p $SPELL_DICT_DIR

if [[ $PLATFORM == "SIMULATORARM64" ]]; then
  POSTFIX=-arm64
elif [[ $PLATFORM == "SIMULATOR64" ]]; then
  POSTFIX=-x86_64
elif [[ $PLATFORM == "OS64" ]]; then
  POSTFIX=""
else
  echo "Unknown platform: $PLATFORM"
  exit 1
fi

for dep in "${deps[@]}"; do
  file=$dep$POSTFIX.tar.bz2
  [[ -f cache/$file ]] || wget -P cache https://github.com/fcitx-contrib/fcitx5-prebuilder/releases/download/ios/$file
  tar xf cache/$file -C $EXTRACT_DIR
done

file=Fcitx5-arm64.tar.bz2
[[ -f cache/$file ]] || wget -P cache https://github.com/fcitx-contrib/fcitx5-macos/releases/download/latest/$file
tar xf cache/$file -C $SPELL_DICT_DIR --strip-components=5 Fcitx5.app/Contents/share/fcitx5/spell/en_dict.fscd

plugins=(
  chinese-addons
  rime
)

for plugin in "${plugins[@]}"; do
  file=$plugin-any.tar.bz2
  [[ -f cache/$file ]] || wget -P cache https://github.com/fcitx-contrib/fcitx5-plugins/releases/download/macos-latest/$file
  tar xf cache/$file -C $EXTRACT_DIR
done
