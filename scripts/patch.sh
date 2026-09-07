#!/bin/zsh
set -e

# Apply multiple patches to the given directory if it has no uncommitted changes.
apply_patch() {
    local dir="$1"
    shift
    if [ -z "$(git -C "$dir" status --porcelain --ignore-submodules=all)" ]; then
        git apply --directory="$dir" "$@"
        echo "Applied patches to $dir"
    else
        echo "Skipping $dir: has uncommitted changes"
    fi
}

apply_patch fcitx5 patches/fcitx5.patch
apply_patch deps/swifter patches/swifter.patch
apply_patch deps/ZIPFoundation patches/ZIPFoundation.patch
apply_patch engines/libime/src/libime/core/kenlm patches/kenlm.patch
apply_patch engines/fcitx5-hallelujah patches/hallelujah.patch
apply_patch engines/fcitx5-rime patches/rime.patch
apply_patch ios-cmake patches/ios-cmake.patch
