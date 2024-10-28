set -e

has_dl=0

executable=build/src/Release-iphonesimulator/Fcitx5.app/PlugIns/keyboard.appex/keyboard

if nm $executable | grep dlopen; then
  has_dl=1
fi

exit $has_dl
