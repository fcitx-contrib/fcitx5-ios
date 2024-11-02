find common src keyboard iosfrontend uipanel -name '*.cpp' -o -name '*.h' | xargs clang-format -i
swift-format format --in-place $(find src keyboard iosfrontend uipanel protocol ipc -name '*.swift')
