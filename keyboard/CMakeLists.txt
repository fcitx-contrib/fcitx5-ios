add_executable(keyboard MACOSX_BUNDLE KeyboardViewController.swift fcitx.cpp)

set_target_properties(keyboard PROPERTIES
    MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_SOURCE_DIR}/Info.plist"
    XCODE_PRODUCT_TYPE "com.apple.product-type.app-extension"
)

target_include_directories(keyboard PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}")
target_compile_options(keyboard PUBLIC
    "$<$<COMPILE_LANGUAGE:Swift>:-cxx-interoperability-mode=default>"
)
