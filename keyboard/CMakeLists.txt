add_executable(keyboard MACOSX_BUNDLE KeyboardViewController.swift)

set_target_properties(keyboard PROPERTIES
    MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_SOURCE_DIR}/Info.plist"
    XCODE_PRODUCT_TYPE "com.apple.product-type.app-extension"
)
