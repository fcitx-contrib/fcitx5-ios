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

set(PREBUILDER_LIB_DIR "${PROJECT_BINARY_DIR}/sysroot/usr/lib")
set(PREBUILDER_SHARE_DIR "${PROJECT_BINARY_DIR}/sysroot/usr/share")

set(ENV{PKG_CONFIG_PATH} "${PREBUILDER_LIB_DIR}/pkgconfig")

# For dependencies not to be find via pkg-config
set(LibIntl_DIR "${PREBUILDER_LIB_DIR}/cmake")
find_package(LibIntl)
set(fmt_DIR "${PREBUILDER_LIB_DIR}/cmake/fmt")
find_package(fmt)

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

add_subdirectory(fcitx5)

add_subdirectory(protocol)
add_subdirectory(iosfrontend)
add_subdirectory(iosnotifications)
add_subdirectory(uipanel)
add_subdirectory(ipc)

option(HALLELUJAH "" OFF)
option(RIME "" OFF)

set(ADDONS)

if (HALLELUJAH)
    add_definitions(-DHALLELUJAH)
    add_subdirectory(engines/fcitx5-hallelujah)
    list(APPEND ADDONS hallelujah)
endif()
if (RIME)
    # RIME_DATA_DIR is not actually used but must exist.
    set(RIME_DATA_DIR "/usr/share/rime-data")
    set(RIME_TARGET "${PREBUILDER_LIB_DIR}/librime.a" "-L${PREBUILDER_LIB_DIR}" leveldb yaml-cpp marisa opencc glog)
    set(Rime_VERSION "1.11.2")
    add_definitions(-DRIME)
    add_subdirectory(engines/fcitx5-rime)
    list(APPEND ADDONS rime)
endif()

if (HALLELUJAH)
    list(APPEND ADDONS spell)
endif()

add_subdirectory(common)
add_subdirectory(keyboard)
add_subdirectory(src)
