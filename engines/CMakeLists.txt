set(DEFAULT_INPUT_METHODS)

if (CHINESE_ADDONS)
    add_definitions(-DCHINESE_ADDONS)
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
    list(APPEND DEFAULT_INPUT_METHODS pinyin shuangpin wbx)
endif()

if (HALLELUJAH)
    add_library(Marisa_static STATIC IMPORTED)
    set_target_properties(Marisa_static PROPERTIES
        IMPORTED_LOCATION "${PREBUILDER_LIB_DIR}/libmarisa.a"
        INTERFACE_INCLUDE_DIRECTORIES "${PREBUILDER_INCLUDE_DIR}"
    )
    set(MARISA_TARGET Marisa_static)
    add_library(JsonC_static STATIC IMPORTED)
    set_target_properties(JsonC_static PROPERTIES
        IMPORTED_LOCATION "${PREBUILDER_LIB_DIR}/libjson-c.a"
        INTERFACE_INCLUDE_DIRECTORIES "${PREBUILDER_INCLUDE_DIR}"
    )
    set(JSONC_TARGET JsonC_static)

    add_definitions(-DHALLELUJAH)
    add_subdirectory(fcitx5-hallelujah)
    list(APPEND DEFAULT_INPUT_METHODS hallelujah)
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
    list(APPEND DEFAULT_INPUT_METHODS mozc)
endif()

if (RIME)
    # RIME_DATA_DIR is not actually used but must exist.
    set(RIME_DATA_DIR "/usr/share/rime-data")
    set(Rime_dependencies
        "${PREBUILDER_LIB_DIR}/libleveldb.a"
        "${PREBUILDER_LIB_DIR}/libyaml-cpp.a"
        "${PREBUILDER_LIB_DIR}/libmarisa.a"
        "${PREBUILDER_LIB_DIR}/libopencc.a"
        "${PREBUILDER_LIB_DIR}/libglog.a"
        "${PREBUILDER_LIB_DIR}/liblua.a"
    )
    add_library(Rime_static STATIC IMPORTED)
    set_target_properties(Rime_static PROPERTIES
        IMPORTED_LOCATION "-Wl,-force_load,${PREBUILDER_LIB_DIR}/librime.a" # plugins use __attribute__((constructor))
        INTERFACE_INCLUDE_DIRECTORIES "${PREBUILDER_INCLUDE_DIR}"
        INTERFACE_LINK_LIBRARIES "${Rime_dependencies}"
    )
    set(RIME_TARGET Rime_static)
    set(Rime_VERSION "1.12")

    add_definitions(-DRIME)
    add_subdirectory(fcitx5-rime)
    target_include_directories(rime PRIVATE "${PROJECT_BINARY_DIR}/ipc/include")
    add_dependencies(rime FcitxIpc)
    list(APPEND DEFAULT_INPUT_METHODS rime)
endif()

add_custom_command(
    OUTPUT "${PROJECT_BINARY_DIR}/profile"
    COMMAND python scripts/configure.py ${DEFAULT_INPUT_METHODS}
    DEPENDS "${PROJECT_SOURCE_DIR}/default"
    WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}"
    COMMENT "Generating profile"
)
add_custom_target(gen_profile DEPENDS "${PROJECT_BINARY_DIR}/profile")
