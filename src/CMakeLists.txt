add_executable(
    ${BUNDLE_NAME}
    MACOSX_BUNDLE
    ContentView.swift
    InputMethodsView.swift
    ConfigView.swift
    App.swift
    AppDelegate.swift
    SceneDelegate.swift
    fcitx.cpp
    config.cpp
)

target_include_directories(${BUNDLE_NAME} PRIVATE
    "${CMAKE_CURRENT_SOURCE_DIR}"
    "${PROJECT_SOURCE_DIR}/common"
    "${PROJECT_BINARY_DIR}/common/$<CONFIG>${CMAKE_XCODE_EFFECTIVE_PLATFORMS}"
    "${PROJECT_BINARY_DIR}/ipc/$<CONFIG>${CMAKE_XCODE_EFFECTIVE_PLATFORMS}"
    "${PROJECT_BINARY_DIR}/iosnotifications/$<CONFIG>${CMAKE_XCODE_EFFECTIVE_PLATFORMS}"
    "${PROJECT_BINARY_DIR}/deps/AlertToast/$<CONFIG>${CMAKE_XCODE_EFFECTIVE_PLATFORMS}"
)

target_link_libraries(${BUNDLE_NAME} PRIVATE
    AlertToast
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

add_dependencies(${BUNDLE_NAME} keyboard)

set_target_properties(${BUNDLE_NAME} PROPERTIES
    XCODE_EMBED_APP_EXTENSIONS keyboard
)

set_xcode_property(${BUNDLE_NAME} CODE_SIGN_ENTITLEMENTS ${PROJECT_SOURCE_DIR}/assets/app.entitlements)

add_custom_command(
    TARGET ${BUNDLE_NAME}
    POST_BUILD COMMAND /bin/sh -c
    \"
    ${CMAKE_COMMAND} -E copy_directory
        ${PROJECT_BINARY_DIR}/keyboard/$<CONFIG>${CMAKE_XCODE_EFFECTIVE_PLATFORMS}/keyboard.appex
        ${PROJECT_BINARY_DIR}/src/$<CONFIG>${CMAKE_XCODE_EFFECTIVE_PLATFORMS}/${BUNDLE_NAME}.app/PlugIns/keyboard.appex
    \"
)

# Embed keyboard.appex in app.
# Copy share directory, icon and profile.
add_custom_command(
    TARGET ${BUNDLE_NAME}
    POST_BUILD COMMAND /bin/sh -c
    \"
    ${CMAKE_COMMAND} -E copy_directory
        ${PROJECT_BINARY_DIR}/keyboard/$<CONFIG>${CMAKE_XCODE_EFFECTIVE_PLATFORMS}/keyboard.appex
        ${PROJECT_BINARY_DIR}/src/$<CONFIG>${CMAKE_XCODE_EFFECTIVE_PLATFORMS}/${BUNDLE_NAME}.app/PlugIns/keyboard.appex
    \;
    ${CMAKE_COMMAND} -E copy_directory
        ${PROJECT_BINARY_DIR}/keyboard/$<CONFIG>${CMAKE_XCODE_EFFECTIVE_PLATFORMS}/keyboard.appex/share
        ${PROJECT_BINARY_DIR}/src/$<CONFIG>${CMAKE_XCODE_EFFECTIVE_PLATFORMS}/${BUNDLE_NAME}.app/share
    \;
    ${CMAKE_COMMAND} -E copy
        ${PROJECT_SOURCE_DIR}/assets/${ICON_FILE}
        ${PROJECT_BINARY_DIR}/src/$<CONFIG>${CMAKE_XCODE_EFFECTIVE_PLATFORMS}/${BUNDLE_NAME}.app
    \;
    ${CMAKE_COMMAND} -E copy
        ${PROJECT_BINARY_DIR}/profile
        ${PROJECT_BINARY_DIR}/src/$<CONFIG>${CMAKE_XCODE_EFFECTIVE_PLATFORMS}/${BUNDLE_NAME}.app/profile
    \"
)
