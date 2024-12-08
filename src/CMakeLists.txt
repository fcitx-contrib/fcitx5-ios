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

target_link_libraries(${BUNDLE_NAME}
    AlertToast
    SwiftFrontend
    KeyboardUI
    NotifySwift
    FcitxIpc
    FcitxCommon
    SwiftUtil
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
copy_share_to_keyboard(copy fcitx5/spell/en_dict.fscd "share/fcitx5/spell/en_dict.fscd")

if (CHINESE_ADDONS)
    set(CHINESE_ADDONS_BINARY_DIR "${PROJECT_BINARY_DIR}/engines/fcitx5-chinese-addons")

    # Pinyin addon and im
    copy_to_keyboard(copy "${CHINESE_ADDONS_BINARY_DIR}/im/pinyin/pinyin-addon.conf" "${ADDON_PREFIX}/pinyin.conf")
    copy_to_keyboard(copy "${CHINESE_ADDONS_BINARY_DIR}/im/pinyin/pinyin.conf" "${IM_PREFIX}/pinyin.conf")
    copy_to_keyboard(copy "${CHINESE_ADDONS_BINARY_DIR}/im/pinyin/shuangpin.conf" "${IM_PREFIX}/shuangpin.conf")

    # Table addon, im and dict
    copy_to_keyboard(copy "${CHINESE_ADDONS_BINARY_DIR}/im/table/table.conf" "share/fcitx5/addon/table.conf")
    # Filter out wanfeng, erbi, cangjie and qxm.
    copy_share_to_keyboard(copy "fcitx5/inputmethod/db.conf")
    copy_share_to_keyboard(copy "libime/db.main.dict")
    copy_share_to_keyboard(copy "fcitx5/inputmethod/wbx.conf")
    copy_share_to_keyboard(copy "libime/wbx.main.dict")
    copy_share_to_keyboard(copy "fcitx5/inputmethod/wbpy.conf")
    copy_share_to_keyboard(copy "libime/wbpy.main.dict")
    copy_share_to_keyboard(copy "fcitx5/inputmethod/zrm.conf")
    copy_share_to_keyboard(copy "libime/zrm.main.dict")

    # Module addons
    copy_to_keyboard(copy "${CHINESE_ADDONS_BINARY_DIR}/modules/pinyinhelper/pinyinhelper.conf" "share/fcitx5/addon/pinyinhelper.conf")
    copy_to_keyboard(copy "${CHINESE_ADDONS_BINARY_DIR}/modules/fullwidth/fullwidth.conf" "share/fcitx5/addon/fullwidth.conf")
    copy_to_keyboard(copy "${CHINESE_ADDONS_BINARY_DIR}/modules/punctuation/punctuation.conf" "share/fcitx5/addon/punctuation.conf")
    copy_to_keyboard(copy "${CHINESE_ADDONS_BINARY_DIR}/modules/chttrans/chttrans.conf" "share/fcitx5/addon/chttrans.conf")

    # Shared resources
    copy_to_keyboard(copy_directory "${PREBUILDER_LIB_DIR}/libime" "lib/libime")
    copy_share_to_keyboard(copy_directory "fcitx5/pinyin")
    copy_share_to_keyboard(copy_directory "fcitx5/pinyinhelper")
    copy_share_to_keyboard(copy_directory "fcitx5/punctuation")
    copy_share_to_keyboard(copy "libime/sc.dict")
    copy_share_to_keyboard(copy "libime/extb.dict")
    copy_share_to_keyboard(copy_directory "fcitx5/chttrans")
    copy_share_to_keyboard(copy_directory "opencc")
endif()

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

fcitx5_import_addons(${BUNDLE_NAME}
    REGISTRY_VARNAME getStaticAddon
    ADDONS ${ADDON_TARGETS}
)
