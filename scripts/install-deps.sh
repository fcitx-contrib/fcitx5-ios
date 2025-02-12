deps=(
  boost
  curl
  fmt
  glog
  json-c
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

EXTRACT_DIR=build/sysroot/usr
SPELL_DICT_DIR=$EXTRACT_DIR/share/fcitx5/spell
mkdir -p $SPELL_DICT_DIR

if [[ $IOS_PLATFORM == "SIMULATOR" ]]; then
  POSTFIX=-$(uname -m)
else
  POSTFIX=""
fi

for dep in "${deps[@]}"; do
  file=$dep$POSTFIX.tar.bz2
  [[ -f cache/$file ]] || wget -P cache https://github.com/fcitx-contrib/fcitx5-prebuilder/releases/download/ios/$file
  tar xjvf cache/$file -C $EXTRACT_DIR
done

file=Fcitx5-arm64.tar.bz2
[[ -f cache/$file ]] || wget -P cache https://github.com/fcitx-contrib/fcitx5-macos/releases/download/latest/$file
tar xjvf cache/$file -C $SPELL_DICT_DIR --strip-components=5 Fcitx5.app/Contents/share/fcitx5/spell/en_dict.fscd

plugins=(
  chinese-addons
  rime
)

for plugin in "${plugins[@]}"; do
  file=$plugin-any.tar.bz2
  [[ -f cache/$file ]] || wget -P cache https://github.com/fcitx-contrib/fcitx5-plugins/releases/download/macos/$file
  tar xjvf cache/$file -C $EXTRACT_DIR
done
