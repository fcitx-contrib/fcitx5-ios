set -e

git apply --directory=fcitx5 patches/fcitx5.patch
git apply --directory=deps/swifter patches/swifter.patch
git apply --directory=deps/ZIPFoundation patches/ZIPFoundation.patch
git apply --directory=engines/libime/src/libime/core/kenlm patches/kenlm.patch
git apply --directory=engines/fcitx5-hallelujah patches/hallelujah.patch
git apply --directory=engines/fcitx5-rime patches/rime.patch
