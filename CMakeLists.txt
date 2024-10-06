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

include(InitializeSwift)
include(AddSwift)

set(KEYBOARD_NAME "Keyboard")
set(KEYBOARD_LANGUAGE "zh-Hans")

set(ENGINE "" CACHE STRING "fcitx5 engine to bundle")

if (ENGINE STREQUAL "hallelujah")
    add_definitions(-DHALLELUJAH)
endif()

# For dependencies not to be find via pkg-config
set(LibIntl_DIR "build/sysroot/usr/lib/cmake")
find_package(LibIntl)
set(fmt_DIR "build/sysroot/usr/lib/cmake/fmt")
find_package(fmt)

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

add_subdirectory(iosfrontend)
add_subdirectory(uipanel)

add_subdirectory(engines)

add_subdirectory(keyboard)
add_subdirectory(src)
