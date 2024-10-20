add_executable(
    ${BUNDLE_NAME}
    MACOSX_BUNDLE
    ContentView.swift
    App.swift
)

add_custom_command(
    TARGET ${BUNDLE_NAME}
    POST_BUILD COMMAND /bin/sh -c
    \"
    ${CMAKE_COMMAND} -E copy
        ${PROJECT_SOURCE_DIR}/assets/${ICON_FILE}
        ${PROJECT_BINARY_DIR}/src/$<CONFIG>${CMAKE_XCODE_EFFECTIVE_PLATFORMS}/${BUNDLE_NAME}.app
    \"
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
