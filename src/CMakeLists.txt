add_executable(
    ${BUNDLE_NAME}
    MACOSX_BUNDLE
    ContentView.swift
    App.swift
)

add_custom_command(
    TARGET ${BUNDLE_NAME}
    POST_BUILD COMMAND /bin/sh -c
    \"COMMAND_DONE=0 \;
    if ${CMAKE_COMMAND} -E copy
        ${PROJECT_SOURCE_DIR}/assets/${ICON_FILE}
        ${PROJECT_BINARY_DIR}/src/$<CONFIG>${CMAKE_XCODE_EFFECTIVE_PLATFORMS}/${BUNDLE_NAME}.app
        \&\>/dev/null \; then
        COMMAND_DONE=1 \;
    fi \;
    if [ \\$$COMMAND_DONE -eq 0 ] \; then
        echo Failed to copy the icon into the app bundle \;
        exit 1 \;
    fi\"
)
