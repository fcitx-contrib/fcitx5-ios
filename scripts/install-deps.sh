deps=(
  fmt
  glog
  json-c
  leveldb
  libintl
  librime
  libuv
  marisa
  opencc
  yaml-cpp
)

EXTRACT_DIR=build/sysroot/usr
mkdir -p $EXTRACT_DIR

if [[ $IOS_PLATFORM == "SIMULATOR" ]]; then
  POSTFIX=-$(uname -m)
else
  POSTFIX=""
fi

for dep in "${deps[@]}"; do
  file=$dep$POSTFIX.tar.bz2
  [[ -f cache/$file ]] || wget -P cache https://github.com/fcitx-contrib/fcitx5-ios-prebuilder/releases/download/latest/$file
  tar xjvf cache/$file -C $EXTRACT_DIR
done

plugins=(
  rime
)

for plugin in "${plugins[@]}"; do
  file=$plugin-any.tar.bz2
  [[ -f cache/$file ]] || wget -P cache https://github.com/fcitx-contrib/fcitx5-macos-plugins/releases/download/latest/$file
  tar xjvf cache/$file -C $EXTRACT_DIR
done
