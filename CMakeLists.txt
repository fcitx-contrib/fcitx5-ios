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

list(PREPEND CMAKE_MODULE_PATH "${PROJECT_SOURCE_DIR}/cmake")

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

set(ENV{PKG_CONFIG_SYSROOT_DIR} "${PROJECT_BINARY_DIR}/sysroot")
set(ENV{PKG_CONFIG_PATH} "${PREBUILDER_LIB_DIR}/pkgconfig")

list(APPEND CMAKE_FIND_ROOT_PATH "${FIND_ROOT_PATH}")

option(BUILD_SHARED_LIBS "" OFF)
option(BUILD_SHARED_FCITX_ADDON "" OFF)

add_subdirectory(deps)

option(ENABLE_TESTING_ADDONS "" OFF)
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

option(CHINESE_ADDONS "" ON)
option(HALLELUJAH "" OFF)
option(RIME "" OFF)

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

add_subdirectory(engines)

fcitx5_get_addon_targets(ADDON_TARGETS iosnotifications engines fcitx5 iosfrontend uipanel)

add_subdirectory(common)
add_subdirectory(keyboard)
add_subdirectory(src)
