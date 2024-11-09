add_executable(keyboard MACOSX_BUNDLE
    KeyboardViewController.swift
    fcitx.cpp
)

set_target_properties(keyboard PROPERTIES
    MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_SOURCE_DIR}/Info.plist"
    XCODE_PRODUCT_TYPE "com.apple.product-type.app-extension"
)

set_xcode_property(keyboard CODE_SIGN_ENTITLEMENTS ${PROJECT_SOURCE_DIR}/assets/keyboard.entitlements)

target_include_directories(keyboard PRIVATE
    "${CMAKE_CURRENT_SOURCE_DIR}"
    "${CMAKE_CURRENT_BINARY_DIR}/../fcitx5"
    "${PROJECT_BINARY_DIR}/common/$<CONFIG>${CMAKE_XCODE_EFFECTIVE_PLATFORMS}"
)

target_compile_options(keyboard PUBLIC
    "$<$<COMPILE_LANGUAGE:Swift>:-cxx-interoperability-mode=default>"
)

target_link_libraries(keyboard PRIVATE
    iosfrontend
    SwiftFrontend
    KeyboardUI
    uipanel
    iosnotifications
    NotifySwift
    FcitxIpc
    FcitxCommon
    SwiftUtil
    ${ADDONS}
)

add_dependencies(keyboard gen_profile)
add_custom_command(
    TARGET keyboard
    POST_BUILD COMMAND /bin/sh -c
    \"
    ${CMAKE_COMMAND} -E copy
        ${PROJECT_BINARY_DIR}/profile
        ${CMAKE_CURRENT_BINARY_DIR}/$<CONFIG>${CMAKE_XCODE_EFFECTIVE_PLATFORMS}/keyboard.appex/profile
    \"
)
