file(GLOB CONFIG_UI_FILES CONFIGURE_DEPENDS config/*.swift)

add_executable(
    ${BUNDLE_NAME}
    MACOSX_BUNDLE
    ContentView.swift
    InputMethodsView.swift
    ConfigView.swift
    App.swift
    AppDelegate.swift
    SceneDelegate.swift
    ${CONFIG_UI_FILES}
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

# Make main app the last target so that keyboard can be copied into it.
add_dependencies(${BUNDLE_NAME} keyboard)

set_target_properties(${BUNDLE_NAME} PROPERTIES
    XCODE_EMBED_APP_EXTENSIONS keyboard
)

set_xcode_property(${BUNDLE_NAME} CODE_SIGN_ENTITLEMENTS ${PROJECT_SOURCE_DIR}/assets/app.entitlements)

set(ADDON_PREFIX "share/fcitx5/addon")
set(IM_PREFIX "share/fcitx5/inputmethod")

copy_to_keyboard(copy "${PROJECT_BINARY_DIR}/profile" profile)
copy_to_keyboard(copy "${PROJECT_BINARY_DIR}/iosfrontend/iosfrontend.conf" "${ADDON_PREFIX}/iosfrontend.conf")
copy_to_keyboard(copy "${PROJECT_BINARY_DIR}/iosnotifications/notifications.conf" "${ADDON_PREFIX}/notifications.conf")
copy_to_keyboard(copy "${PROJECT_BINARY_DIR}/uipanel/uipanel.conf" "${ADDON_PREFIX}/uipanel.conf")

set(FCITX5_MODULE_BINARY_DIR "${PROJECT_BINARY_DIR}/fcitx5/src/modules")
copy_to_keyboard(copy "${FCITX5_MODULE_BINARY_DIR}/spell/spell.conf" "${ADDON_PREFIX}/spell.conf")

if (HALLELUJAH)
    set(HALLELUJAH_SOURCE_DIR "${PROJECT_SOURCE_DIR}/engines/fcitx5-hallelujah")
    set(HALLELUJAH_BINARY_DIR "${PROJECT_BINARY_DIR}/engines/fcitx5-hallelujah")
    copy_to_keyboard(copy "${HALLELUJAH_BINARY_DIR}/data/google_227800_words.bin" "share/hallelujah/google_227800_words.bin")
    copy_to_keyboard(copy "${HALLELUJAH_SOURCE_DIR}/data/words.json" "share/hallelujah/words.json")
    copy_to_keyboard(copy "${HALLELUJAH_SOURCE_DIR}/data/cedict.json" "share/hallelujah/cedict.json")
    copy_to_keyboard(copy "${HALLELUJAH_BINARY_DIR}/src/hallelujah-addon.conf" "${ADDON_PREFIX}/hallelujah.conf")
    copy_to_keyboard(copy "${HALLELUJAH_BINARY_DIR}/src/hallelujah.conf" "${IM_PREFIX}/hallelujah.conf")
endif()

if (RIME)
    set(RIME_BINARY_DIR "${PROJECT_BINARY_DIR}/engines/fcitx5-rime")
    copy_to_keyboard(copy "${RIME_BINARY_DIR}/src/rime-addon.conf" "${ADDON_PREFIX}/rime.conf")
    copy_to_keyboard(copy "${RIME_BINARY_DIR}/src/rime.conf" "${IM_PREFIX}/rime.conf")
    copy_share_to_keyboard(copy_directory "rime-data")
endif()

# Embed keyboard.appex in app.
copy_to_app(copy_directory "${PROJECT_BINARY_DIR}/keyboard/$<CONFIG>${CMAKE_XCODE_EFFECTIVE_PLATFORMS}/keyboard.appex" "PlugIns/keyboard.appex")
# Copy share directory, icon and profile.
copy_to_app(copy_directory "${PROJECT_BINARY_DIR}/keyboard/$<CONFIG>${CMAKE_XCODE_EFFECTIVE_PLATFORMS}/keyboard.appex/share" "share")
copy_to_app(copy "${PROJECT_SOURCE_DIR}/assets/${ICON_FILE}" "${ICON_FILE}")
copy_to_app(copy "${PROJECT_BINARY_DIR}/profile" profile)
