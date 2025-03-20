add_executable(keyboard MACOSX_BUNDLE
    KeyboardViewController.swift
    util.swift
    fcitx.cpp
)

set_target_properties(keyboard PROPERTIES
    MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_SOURCE_DIR}/Info.plist"
    XCODE_PRODUCT_TYPE "com.apple.product-type.app-extension"
)

set_xcode_property(keyboard CODE_SIGN_ENTITLEMENTS ${PROJECT_SOURCE_DIR}/assets/keyboard.entitlements All)

target_include_directories(keyboard PRIVATE
    "${CMAKE_CURRENT_SOURCE_DIR}"
    "${CMAKE_CURRENT_BINARY_DIR}/../fcitx5"
    "${PROJECT_BINARY_DIR}/common/$<CONFIG>-${SDK_NAME}"
    "${PROJECT_BINARY_DIR}/uipanel/$<CONFIG>-${SDK_NAME}"
)

target_compile_options(keyboard PUBLIC
    "$<$<COMPILE_LANGUAGE:Swift>:-cxx-interoperability-mode=default>"
)

target_link_libraries(keyboard
    SwiftFrontend
    KeyboardUI
    NotifySwift
    FcitxIpc
    FcitxCommon
    SwiftUtil
)

add_dependencies(keyboard gen_profile)

fcitx5_import_addons(keyboard
    REGISTRY_VARNAME getStaticAddon
    ADDONS ${ADDON_TARGETS}
)
