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
    # Create a new target name RimeExtension not to be conflict with fcitx5-rime's rime target.
    # NSExtensionPrincipalClass is extension.KeyboardViewController for Ninja generator,
    # and keyboard.KeyboardViewController for Xcode generator.
    set(extension "${keyboard}Extension")
    add_executable(${extension} MACOSX_BUNDLE
        "${PROJECT_SOURCE_DIR}/keyboard/KeyboardViewController.swift"
        "${PROJECT_SOURCE_DIR}/keyboard/util.swift"
        "${PROJECT_SOURCE_DIR}/keyboard/SyncConfig.swift"
    )

    configure_file("${PROJECT_SOURCE_DIR}/keyboard/Info.plist.in" "${PROJECT_BINARY_DIR}/${keyboard}.plist" @ONLY)
    set_target_properties(${extension} PROPERTIES
        MACOSX_BUNDLE_INFO_PLIST "${PROJECT_BINARY_DIR}/${keyboard}.plist"
        OUTPUT_NAME "${keyboard}"
    )

    target_include_directories(${extension} PRIVATE
        "${PROJECT_SOURCE_DIR}/keyboard"
        "${PROJECT_SOURCE_DIR}/common"
        "${PROJECT_SOURCE_DIR}/uipanel"
        "${PROJECT_SOURCE_DIR}/fcitx5/src/modules/unicode"
        "${PROJECT_SOURCE_DIR}/fcitx5/src/modules/quickphrase"
        "${PROJECT_BINARY_DIR}/common"
        "${PROJECT_BINARY_DIR}/iosfrontend"
        "${PROJECT_BINARY_DIR}/uipanel"
        "${PROJECT_BINARY_DIR}/protocol"
    )

    target_compile_options(${extension} PUBLIC
        "$<$<COMPILE_LANGUAGE:Swift>:-cxx-interoperability-mode=default>"
    )

    target_link_directories(${extension} PRIVATE
        "${PROJECT_BINARY_DIR}/protocol"
    )
    target_link_libraries(${extension}
        "-Xlinker -e -Xlinker _NSExtensionMain -application-extension"
        "-Xlinker -rpath -Xlinker @executable_path/../../Frameworks"
        FcitxRuntime
    )

    add_dependencies(${extension} "${keyboard}Profile")

    set_property(GLOBAL APPEND PROPERTY FCITX_RUNTIME_ADDONS ${targets})

    copy_to(${keyboard} copy_directory "${PROJECT_SOURCE_DIR}/assets/SwiftTranslations/${keyboard}" "")
    copy_to(${keyboard} copy_directory "${PROJECT_SOURCE_DIR}/assets/SwiftTranslations/Keyboard" "")
endfunction()
