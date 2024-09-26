cmake_minimum_required(VERSION 3.27)

# Avoid MinSizeRel and RelWithDebInfo.
set(CMAKE_CONFIGURATION_TYPES Debug Release CACHE STRING INTERNAL FORCE)

project(fcitx5-ios VERSION 0.1.0 LANGUAGES CXX Swift)
set(CMAKE_OSX_DEPLOYMENT_TARGET 15)
set(CMAKE_Swift_LANGUAGE_VERSION 5.9)

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

add_subdirectory(keyboard)
add_subdirectory(src)
