if (CHINESE_ADDONS)
    set(_Fcitx5Macro_SELF_DIR "${PROJECT_SOURCE_DIR}/fcitx5/src/lib/fcitx-utils")

    option(USE_DLOPEN "" OFF)
    add_subdirectory(fcitx5-lua)

    option(ENABLE_DATA OFF)
    set(HAS_STD_FILESYSTEM 1)
    set(ENABLE_TOOLS OFF)
    add_subdirectory(libime)
    # suppress configure error
    install(TARGETS kenlm EXPORT LibIMECoreTargets LIBRARY DESTINATION "${CMAKE_INSTALL_LIBDIR}" COMPONENT lib)

    option(ENABLE_GUI OFF)
    add_subdirectory(fcitx5-chinese-addons)
    target_link_libraries(chttrans "${PREBUILDER_LIB_DIR}/libmarisa.a")
endif()

if (HALLELUJAH)
    add_library(Marisa_static STATIC IMPORTED)
    set_target_properties(Marisa_static PROPERTIES
        IMPORTED_LOCATION "${PREBUILDER_LIB_DIR}/libmarisa.a"
        INTERFACE_INCLUDE_DIRECTORIES "${PREBUILDER_INCLUDE_DIR}"
    )
    set(MARISA_TARGET Marisa_static)

    add_subdirectory(fcitx5-hallelujah)
endif()

if (MOZC)
    set(MOZC_TARGET
        "-L${PREBUILDER_LIB_DIR}"
        "-lmozc-static"
        "-lutf8_validity"
        "-lprotobuf"
        "-labsl"
    )
    add_subdirectory(fcitx5-mozc)
    target_include_directories(mozc PRIVATE
        "${PREBUILDER_INCLUDE_DIR}/mozc"
        "${PROJECT_SOURCE_DIR}/include"
    )
    target_compile_definitions(mozc PRIVATE -DMOZC_DISABLE_SESSION_WATCHDOG)
endif()

if (RIME)
    # RIME_DATA_DIR is not actually used but must exist.
    set(RIME_DATA_DIR "/usr/share/rime-data")
    find_library(LibJSCore JavaScriptCore)
    set(Rime_dependencies
        "-L${PREBUILDER_LIB_DIR}"
        "-lleveldb"
        "-lyaml-cpp"
        "-lmarisa"
        "-lopencc"
        "-lglog"
        "-llua"
        "-lqjs"
        "${LibJSCore}"
    )
    add_library(Rime_static STATIC IMPORTED)
    set_target_properties(Rime_static PROPERTIES
        IMPORTED_LOCATION "-Wl,-force_load,${PREBUILDER_LIB_DIR}/librime.a" # plugins use __attribute__((constructor))
        INTERFACE_INCLUDE_DIRECTORIES "${PREBUILDER_INCLUDE_DIR}"
        INTERFACE_LINK_LIBRARIES "${Rime_dependencies}"
    )
    set(RIME_TARGET Rime_static)
    set(Rime_VERSION "1.12")

    add_subdirectory(fcitx5-rime)
    target_include_directories(rime PRIVATE "${PROJECT_BINARY_DIR}/ipc/include")
    target_link_libraries(rime FcitxIpc)
endif()
