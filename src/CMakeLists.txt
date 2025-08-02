set(ADDON_PREFIX "share/fcitx5/addon")
set(IM_PREFIX "share/fcitx5/inputmethod")
set(ENGINES_SOURCE_DIR "${PROJECT_SOURCE_DIR}/engines")
set(FCITX5_MODULE_BINARY_DIR "${PROJECT_BINARY_DIR}/fcitx5/src/modules")

set(KEYBOARDS)
set(DEFAULT_INPUT_METHODS)
set(ENGINE_TARGETS)

if (CHINESE_ADDONS)
    list(APPEND KEYBOARDS Chinese)
    list(APPEND DEFAULT_INPUT_METHODS pinyin shuangpin wbx)
    generate_profile(Chinese "src/$<CONFIG>-${SDK_NAME}/Chinese.appex" "pinyin;shuangpin;wbx")
    fcitx5_get_addon_targets(CHINESE_TARGETS "${ENGINES_SOURCE_DIR}/fcitx5-chinese-addons" "${ENGINES_SOURCE_DIR}/fcitx5-lua")
    add_keyboard_extension(Chinese "zh-Hans" "${CHINESE_TARGETS}")
    list(APPEND ENGINE_TARGETS ${CHINESE_TARGETS})

    # quickphrase
    copy_to_keyboard(Chinese copy "${FCITX5_MODULE_BINARY_DIR}/quickphrase/quickphrase.conf" "${ADDON_PREFIX}/quickphrase.conf")
    copy_to_keyboard(Chinese copy_directory "${PROJECT_SOURCE_DIR}/fcitx5/src/modules/quickphrase/quickphrase.d" "share/fcitx5/data/quickphrase.d")

    # spell
    copy_to_keyboard(Chinese copy "${FCITX5_MODULE_BINARY_DIR}/spell/spell.conf" "${ADDON_PREFIX}/spell.conf")
    copy_share_to_keyboard(Chinese copy fcitx5/spell/en_dict.fscd "share/fcitx5/spell/en_dict.fscd")

    # unicode
    copy_to_keyboard(Chinese copy "${FCITX5_MODULE_BINARY_DIR}/unicode/unicode.conf" "${ADDON_PREFIX}/unicode.conf")

    set(LUA_BINARY_DIR "${PROJECT_BINARY_DIR}/engines/fcitx5-lua")
    copy_to_keyboard(Chinese copy "${LUA_BINARY_DIR}/src/addonloader/luaaddonloader.conf" "${ADDON_PREFIX}/luaaddonloader.conf")
    copy_to_keyboard(Chinese copy "${LUA_BINARY_DIR}/src/imeapi/imeapi.conf" "${ADDON_PREFIX}/imeapi.conf")
    copy_to_keyboard(Chinese copy "${ENGINES_SOURCE_DIR}/fcitx5-lua/src/imeapi/imeapi.lua" "share/fcitx5/lua/imeapi/imeapi.lua")

    set(CHINESE_ADDONS_BINARY_DIR "${PROJECT_BINARY_DIR}/engines/fcitx5-chinese-addons")

    # Pinyin addon, im and lua
    copy_to_keyboard(Chinese copy "${CHINESE_ADDONS_BINARY_DIR}/im/pinyin/pinyin-addon.conf" "${ADDON_PREFIX}/pinyin.conf")
    copy_to_keyboard(Chinese copy "${CHINESE_ADDONS_BINARY_DIR}/im/pinyin/pinyin.conf" "${IM_PREFIX}/pinyin.conf")
    copy_to_keyboard(Chinese copy "${CHINESE_ADDONS_BINARY_DIR}/im/pinyin/shuangpin.conf" "${IM_PREFIX}/shuangpin.conf")
    copy_to_keyboard(Chinese copy "${ENGINES_SOURCE_DIR}/fcitx5-chinese-addons/im/pinyin/pinyin.lua" "share/fcitx5/lua/imeapi/extensions/pinyin.lua")

    # Table addon, im and dict
    copy_to_keyboard(Chinese copy "${CHINESE_ADDONS_BINARY_DIR}/im/table/table.conf" "share/fcitx5/addon/table.conf")
    # Filter out wanfeng, erbi, cangjie and qxm.
    copy_share_to_keyboard(Chinese copy "fcitx5/inputmethod/db.conf")
    copy_share_to_keyboard(Chinese copy "libime/db.main.dict")
    copy_share_to_keyboard(Chinese copy "fcitx5/inputmethod/wbx.conf")
    copy_share_to_keyboard(Chinese copy "libime/wbx.main.dict")
    copy_share_to_keyboard(Chinese copy "fcitx5/inputmethod/wbpy.conf")
    copy_share_to_keyboard(Chinese copy "libime/wbpy.main.dict")
    copy_share_to_keyboard(Chinese copy "fcitx5/inputmethod/zrm.conf")
    copy_share_to_keyboard(Chinese copy "libime/zrm.main.dict")

    # Module addons
    copy_to_keyboard(Chinese copy "${CHINESE_ADDONS_BINARY_DIR}/modules/pinyinhelper/pinyinhelper.conf" "share/fcitx5/addon/pinyinhelper.conf")
    copy_to_keyboard(Chinese copy "${CHINESE_ADDONS_BINARY_DIR}/modules/fullwidth/fullwidth.conf" "share/fcitx5/addon/fullwidth.conf")
    copy_to_keyboard(Chinese copy "${CHINESE_ADDONS_BINARY_DIR}/modules/punctuation/punctuation.conf" "share/fcitx5/addon/punctuation.conf")
    copy_to_keyboard(Chinese copy "${CHINESE_ADDONS_BINARY_DIR}/modules/chttrans/chttrans.conf" "share/fcitx5/addon/chttrans.conf")
    copy_to_keyboard(Chinese copy "${CHINESE_ADDONS_BINARY_DIR}/modules/cloudpinyin/cloudpinyin.conf" "share/fcitx5/addon/cloudpinyin.conf")

    # Shared resources
    copy_to_keyboard(Chinese copy_directory "${PREBUILDER_LIB_DIR}/libime" "lib/libime")
    copy_share_to_keyboard(Chinese copy_directory "fcitx5/pinyin")
    copy_share_to_keyboard(Chinese copy_directory "fcitx5/pinyinhelper")
    copy_share_to_keyboard(Chinese copy_directory "fcitx5/punctuation")
    copy_share_to_keyboard(Chinese copy "libime/sc.dict")
    copy_share_to_keyboard(Chinese copy "libime/extb.dict")
    copy_share_to_keyboard(Chinese copy_directory "fcitx5/chttrans")
    copy_share_to_keyboard(Chinese copy_directory "opencc")

    # Assets
    add_dependencies(ChineseExtension png_images)
    copy_to_keyboard(Chinese copy "${PROJECT_BINARY_DIR}/full-punc.png" "share/png/full-punc.png")
    copy_to_keyboard(Chinese copy "${PROJECT_BINARY_DIR}/half-punc.png" "share/png/half-punc.png")
endif()

if (HALLELUJAH)
    list(APPEND KEYBOARDS Hallelujah)
    list(APPEND DEFAULT_INPUT_METHODS hallelujah)
    generate_profile(Hallelujah "src/$<CONFIG>-${SDK_NAME}/Hallelujah.appex" "hallelujah")
    fcitx5_get_addon_targets(HALLELUJAH_TARGETS "${ENGINES_SOURCE_DIR}/fcitx5-hallelujah")
    add_keyboard_extension(Hallelujah "en-US" "${HALLELUJAH_TARGETS}")
    list(APPEND ENGINE_TARGETS ${HALLELUJAH_TARGETS})

    set(HALLELUJAH_SOURCE_DIR "${ENGINES_SOURCE_DIR}/fcitx5-hallelujah")
    set(HALLELUJAH_BINARY_DIR "${PROJECT_BINARY_DIR}/engines/fcitx5-hallelujah")
    copy_to_keyboard(Hallelujah copy "${HALLELUJAH_BINARY_DIR}/data/google_227800_words.bin" "share/hallelujah/google_227800_words.bin")
    copy_to_keyboard(Hallelujah copy "${HALLELUJAH_SOURCE_DIR}/data/words.json" "share/hallelujah/words.json")
    copy_to_keyboard(Hallelujah copy "${HALLELUJAH_SOURCE_DIR}/data/cedict.json" "share/hallelujah/cedict.json")
    copy_to_keyboard(Hallelujah copy "${HALLELUJAH_BINARY_DIR}/src/hallelujah-addon.conf" "${ADDON_PREFIX}/hallelujah.conf")
    copy_to_keyboard(Hallelujah copy "${HALLELUJAH_BINARY_DIR}/src/hallelujah.conf" "${IM_PREFIX}/hallelujah.conf")

    # spell
    copy_to_keyboard(Hallelujah copy "${FCITX5_MODULE_BINARY_DIR}/spell/spell.conf" "${ADDON_PREFIX}/spell.conf")
    copy_share_to_keyboard(Hallelujah copy fcitx5/spell/en_dict.fscd "share/fcitx5/spell/en_dict.fscd")
endif()

if (MOZC)
    list(APPEND KEYBOARDS Mozc)
    list(APPEND DEFAULT_INPUT_METHODS mozc)
    generate_profile(Mozc "src/$<CONFIG>-${SDK_NAME}/Mozc.appex" "mozc")
    fcitx5_get_addon_targets(MOZC_TARGETS "${ENGINES_SOURCE_DIR}/fcitx5-mozc")
    add_keyboard_extension(Mozc "ja-JP" "${MOZC_TARGETS}")
    list(APPEND ENGINE_TARGETS ${MOZC_TARGETS})

    set(MOZC_BINARY_DIR "${PROJECT_BINARY_DIR}/engines/fcitx5-mozc")
    copy_to_keyboard(Mozc copy "${MOZC_BINARY_DIR}/src/unix/fcitx5/mozc-addon.conf" "${ADDON_PREFIX}/mozc.conf")
    copy_to_keyboard(Mozc copy "${ENGINES_SOURCE_DIR}/fcitx5-mozc/src/unix/fcitx5/mozc.conf" "${IM_PREFIX}/mozc.conf")
endif()

if (RIME)
    list(APPEND KEYBOARDS Rime)
    list(APPEND DEFAULT_INPUT_METHODS rime)
    generate_profile(Rime "src/$<CONFIG>-${SDK_NAME}/Rime.appex" "rime")
    fcitx5_get_addon_targets(RIME_TARGETS "${ENGINES_SOURCE_DIR}/fcitx5-rime")
    add_keyboard_extension(Rime "mul" "${RIME_TARGETS}")
    list(APPEND ENGINE_TARGETS ${RIME_TARGETS})

    set(RIME_BINARY_DIR "${PROJECT_BINARY_DIR}/engines/fcitx5-rime")
    copy_to_keyboard(Rime copy "${RIME_BINARY_DIR}/src/rime-addon.conf" "${ADDON_PREFIX}/rime.conf")
    copy_to_keyboard(Rime copy "${RIME_BINARY_DIR}/src/rime.conf" "${IM_PREFIX}/rime.conf")
    copy_share_to_keyboard(Rime copy_directory "rime-data")
endif()

file(GLOB CONFIG_UI_FILES CONFIGURE_DEPENDS config/*.swift)

add_executable(
    ${BUNDLE_NAME}
    MACOSX_BUNDLE
    ContentView.swift
    InputMethodsView.swift
    AddonConfigView.swift
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
    "${PROJECT_BINARY_DIR}/common/$<CONFIG>-${SDK_NAME}"
    "${PROJECT_BINARY_DIR}/ipc/$<CONFIG>-${SDK_NAME}"
    "${PROJECT_BINARY_DIR}/iosnotifications/$<CONFIG>-${SDK_NAME}"
    "${PROJECT_BINARY_DIR}/deps/AlertToast/$<CONFIG>-${SDK_NAME}"
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

list(TRANSFORM KEYBOARDS APPEND "Extension" OUTPUT_VARIABLE EXTENSIONS)
# Make main app the last target so that keyboard can be copied into it.
add_dependencies(${BUNDLE_NAME} ${EXTENSIONS})

set_target_properties(${BUNDLE_NAME} PROPERTIES
    XCODE_EMBED_APP_EXTENSIONS "${EXTENSIONS}"
)

set_xcode_property(${BUNDLE_NAME} CODE_SIGN_ENTITLEMENTS ${PROJECT_SOURCE_DIR}/assets/app.entitlements All)

foreach(Keyboard ${KEYBOARDS})
    # Embed keyboard.appex in app.
    copy_to_app(copy_directory "${CMAKE_CURRENT_BINARY_DIR}/$<CONFIG>-${SDK_NAME}/${Keyboard}.appex" "PlugIns/${Keyboard}.appex")
    # Copy share directory.
    copy_to_app(copy_directory "${CMAKE_CURRENT_BINARY_DIR}/$<CONFIG>-${SDK_NAME}/${Keyboard}.appex/share" "share")
endforeach()

generate_profile(App "." "${DEFAULT_INPUT_METHODS}")
add_dependencies(${BUNDLE_NAME} AppProfile)

# Copy icon and profile
copy_to_app(copy "${PROJECT_SOURCE_DIR}/assets/${ICON_FILE}" "${ICON_FILE}")
copy_to_app(copy "${PROJECT_BINARY_DIR}/profile" profile)

fcitx5_import_addons(${BUNDLE_NAME}
    REGISTRY_VARNAME getStaticAddon
    ADDONS ${COMMON_TARGETS} ${ENGINE_TARGETS}
)
