deps=(
  fmt
  libintl
  libuv
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

sed -i '' "s|=/usr/include|=$(pwd)/$EXTRACT_DIR/include|" $EXTRACT_DIR/lib/pkgconfig/libuv.pc
sed -i '' "s|-L\${libdir} -luv|$(pwd)/$EXTRACT_DIR/lib/libuv.a|" $EXTRACT_DIR/lib/pkgconfig/libuv.pc
