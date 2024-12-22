set -e

has_dl=0

executables=(
  build/src/Release-iphonesimulator/Fcitx5.app/Fcitx5
  build/src/Release-iphonesimulator/Fcitx5.app/PlugIns/keyboard.appex/keyboard
)

for executable in "${executables[@]}"; do  
  if nm $executable | grep dlopen; then
    has_dl=1
  fi
done

exit $has_dl
