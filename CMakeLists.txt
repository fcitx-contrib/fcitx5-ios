cmake_minimum_required(VERSION 3.27)

# Avoid MinSizeRel and RelWithDebInfo.
set(CMAKE_CONFIGURATION_TYPES Debug Release CACHE STRING INTERNAL FORCE)

project(fcitx5-ios VERSION 0.1.0 LANGUAGES CXX Swift)
set(CMAKE_OSX_DEPLOYMENT_TARGET 15)
set(CMAKE_Swift_LANGUAGE_VERSION 5.9)
set(CMAKE_CXX_STANDARD 17)

set(BUNDLE_IDENTIFIER "org.fcitx.Fcitx5")
set(BUNDLE_NAME "Fcitx5")
set(ICON_FILE "icon.icns")

set(CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake" ${CMAKE_MODULE_PATH})

if (IOS_PLATFORM STREQUAL "SIMULATOR")
    set(F5I_TARGET "${CMAKE_OSX_ARCHITECTURES}-apple-ios${CMAKE_OSX_DEPLOYMENT_TARGET}-simulator")
else()
    set(F5I_TARGET "${CMAKE_OSX_ARCHITECTURES}-apple-ios${CMAKE_OSX_DEPLOYMENT_TARGET}")
endif()

if (NOT URL_SCHEME)
    message(FATAL_ERROR "Must provide URL_SCHEME")
endif()

include(InitializeSwift)
include(AddSwift)

set(KEYBOARD_NAME "Keyboard")
set(KEYBOARD_LANGUAGE "zh-Hans")

set(FIND_ROOT_PATH "${PROJECT_BINARY_DIR}/sysroot/usr")
set(PREBUILDER_INCLUDE_DIR "${FIND_ROOT_PATH}/include")
set(PREBUILDER_LIB_DIR "${FIND_ROOT_PATH}/lib")
set(PREBUILDER_SHARE_DIR "${FIND_ROOT_PATH}/share")

list(APPEND CMAKE_FIND_ROOT_PATH "${FIND_ROOT_PATH}")

add_subdirectory(deps)

option(ENABLE_TEST "" OFF)
option(ENABLE_COVERAGE "" OFF)
option(ENABLE_ENCHANT "" OFF)
option(ENABLE_X11 "" OFF)
option(ENABLE_WAYLAND "" OFF)
option(ENABLE_DBUS "" OFF)
option(ENABLE_DOC "" OFF)
option(ENABLE_SERVER "" OFF)
option(ENABLE_KEYBOARD "" OFF)
option(USE_SYSTEMD "" OFF)
option(ENABLE_XDGAUTOSTART "" OFF)
option(ENABLE_EMOJI "" OFF)
option(ENABLE_LIBUUID "" OFF)
option(BUILD_SPELL_DICT "" OFF)

find_host_package(PkgConfig)
find_host_package(Gettext)
find_host_package(nlohmann_json)

add_library(Libuv_static STATIC IMPORTED)
set_target_properties(Libuv_static PROPERTIES
    IMPORTED_LOCATION "${PREBUILDER_LIB_DIR}/libuv.a"
    INTERFACE_INCLUDE_DIRECTORIES "${PREBUILDER_INCLUDE_DIR}"
)
set(LIBUV_TARGET Libuv_static)

add_subdirectory(fcitx5)

add_subdirectory(protocol)
add_subdirectory(iosfrontend)
add_subdirectory(iosnotifications)
add_subdirectory(uipanel)
add_subdirectory(ipc)

option(HALLELUJAH "" OFF)
option(RIME "" OFF)

set(ADDONS)
set(DEFAULT_INPUT_METHODS)

function(copy_to_keyboard cmd file relative_path)
    add_custom_command(TARGET ${BUNDLE_NAME}
        POST_BUILD COMMAND /bin/sh -c \"
        ${CMAKE_COMMAND} -E ${cmd} ${file}
            ${PROJECT_BINARY_DIR}/keyboard/$<CONFIG>${CMAKE_XCODE_EFFECTIVE_PLATFORMS}/keyboard.appex/${relative_path}
    \")
endfunction()

function(copy_share_to_keyboard cmd relative_path)
    copy_to_keyboard(${cmd} "${PREBUILDER_SHARE_DIR}/${relative_path}" "share/${relative_path}")
endfunction()

function(copy_to_app cmd file relative_path)
    add_custom_command(TARGET ${BUNDLE_NAME}
        POST_BUILD COMMAND /bin/sh -c \"
        ${CMAKE_COMMAND} -E ${cmd} ${file}
            ${PROJECT_BINARY_DIR}/src/$<CONFIG>${CMAKE_XCODE_EFFECTIVE_PLATFORMS}/${BUNDLE_NAME}.app/${relative_path}
    \")
endfunction()

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
    add_subdirectory(engines/fcitx5-hallelujah)
    list(APPEND ADDONS hallelujah)
    list(APPEND DEFAULT_INPUT_METHODS hallelujah)
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
    add_subdirectory(engines/fcitx5-rime)
    list(APPEND ADDONS rime)
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

if (HALLELUJAH)
    list(APPEND ADDONS spell)
endif()

add_subdirectory(common)
add_subdirectory(keyboard)
add_subdirectory(src)
