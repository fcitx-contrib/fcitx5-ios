set -e

find common src keyboard iosfrontend iosnotifications uipanel -name '*.cpp' -o -name '*.h' | xargs clang-format -Werror --dry-run
swift-format lint -rs common src keyboard iosfrontend iosnotifications uipanel protocol ipc

ruff check appium
ruff format --check appium

localizables=$(find assets -name 'Localizable.strings')
for localizable in $localizables; do
  file $localizable | grep UTF-16
done
