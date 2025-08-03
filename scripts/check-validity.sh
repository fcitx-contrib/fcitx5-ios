set -e

platform=$1

has_dl=0

if [[ "$platform" == "OS64" ]]; then
  postfix=os
else
  postfix=simulator
fi

executables=(
  build/$1/src/Release-iphone$postfix/Fcitx5.app/Fcitx5
  build/$1/src/Release-iphone$postfix/Fcitx5.app/PlugIns/Chinese.appex/Chinese
  build/$1/src/Release-iphone$postfix/Fcitx5.app/PlugIns/Hallelujah.appex/Hallelujah
  build/$1/src/Release-iphone$postfix/Fcitx5.app/PlugIns/Mozc.appex/Mozc
  build/$1/src/Release-iphone$postfix/Fcitx5.app/PlugIns/Rime.appex/Rime
)

for executable in "${executables[@]}"; do  
  if nm $executable | grep dlopen; then
    has_dl=1
  fi
done

exit $has_dl
