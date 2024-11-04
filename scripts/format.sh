find common src keyboard iosfrontend iosnotifications uipanel -name '*.cpp' -o -name '*.h' | xargs clang-format -i
swift-format format --in-place $(find src keyboard iosfrontend iosnotifications uipanel protocol ipc -name '*.swift')
