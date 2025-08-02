function(generate_profile keyboard relative_path input_methods)
    set(file_path "${PROJECT_BINARY_DIR}/${relative_path}/profile")
    add_custom_command(
        OUTPUT "${file_path}"
        COMMAND python scripts/configure.py "${file_path}" ${input_methods}
        WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}"
        COMMENT "Generating profile"
    )
    add_custom_target("${keyboard}Profile" DEPENDS "${file_path}")
endfunction()

function(add_keyboard_extension keyboard language targets)
    set(extension "${keyboard}Extension")
    add_executable(${extension} MACOSX_BUNDLE
        "${PROJECT_SOURCE_DIR}/keyboard/KeyboardViewController.swift"
        "${PROJECT_SOURCE_DIR}/keyboard/util.swift"
        "${PROJECT_SOURCE_DIR}/keyboard/fcitx.cpp"
        "${PROJECT_SOURCE_DIR}/keyboard/keycode.cpp"
    )

    configure_file("${PROJECT_SOURCE_DIR}/keyboard/Info.plist.in" "${PROJECT_BINARY_DIR}/${keyboard}.plist" @ONLY)
    set_target_properties(${extension} PROPERTIES
        MACOSX_BUNDLE_INFO_PLIST "${PROJECT_BINARY_DIR}/${keyboard}.plist"
        XCODE_PRODUCT_TYPE "com.apple.product-type.app-extension"
        OUTPUT_NAME "${keyboard}"
    )

    set_xcode_property(${extension} CODE_SIGN_ENTITLEMENTS ${PROJECT_SOURCE_DIR}/assets/keyboard.entitlements All)

    target_include_directories(${extension} PRIVATE
        "${PROJECT_SOURCE_DIR}/keyboard"
        "${PROJECT_BINARY_DIR}/common/$<CONFIG>-${SDK_NAME}"
        "${PROJECT_BINARY_DIR}/uipanel/$<CONFIG>-${SDK_NAME}"
    )

    target_compile_options(${extension} PUBLIC
        "$<$<COMPILE_LANGUAGE:Swift>:-cxx-interoperability-mode=default>"
    )

    target_link_libraries(${extension}
        SwiftFrontend
        KeyboardUI
        NotifySwift
        FcitxCommon
        SwiftUtil
    )

    add_dependencies(${extension} "${keyboard}Profile")

    fcitx5_import_addons(${extension}
        REGISTRY_VARNAME getStaticAddon
        ADDONS ${COMMON_TARGETS} ${targets}
    )

    copy_to_keyboard(${keyboard} copy "${PROJECT_BINARY_DIR}/iosfrontend/iosfrontend.conf" "${ADDON_PREFIX}/iosfrontend.conf")
    copy_to_keyboard(${keyboard} copy "${PROJECT_BINARY_DIR}/iosnotifications/notifications.conf" "${ADDON_PREFIX}/notifications.conf")
    copy_to_keyboard(${keyboard} copy "${PROJECT_BINARY_DIR}/uipanel/uipanel.conf" "${ADDON_PREFIX}/uipanel.conf")
    copy_to_keyboard(${keyboard} copy_directory "${PROJECT_SOURCE_DIR}/fcitx5-keyboard-layouts/layout" "share/layout")
endfunction()
