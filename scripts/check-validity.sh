set -e

platform=$1

has_dl=0

executables=(
  build/$1/src/Fcitx5.app/Fcitx5
  build/$1/src/Fcitx5.app/PlugIns/Chinese.appex/Chinese
  build/$1/src/Fcitx5.app/PlugIns/Hallelujah.appex/Hallelujah
  build/$1/src/Fcitx5.app/PlugIns/Mozc.appex/Mozc
  build/$1/src/Fcitx5.app/PlugIns/Rime.appex/Rime
)

for executable in "${executables[@]}"; do  
  output=$(nm "$executable")
  if echo "$output" | grep dlopen; then
    has_dl=1
  fi
done

exit $has_dl
