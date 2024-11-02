set -e

find src keyboard iosfrontend uipanel -name '*.cpp' -o -name '*.h' | xargs clang-format -Werror --dry-run
swift-format lint -rs src keyboard iosfrontend uipanel protocol ipc
