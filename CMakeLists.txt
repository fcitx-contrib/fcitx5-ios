cmake_minimum_required(VERSION 3.27)

# Avoid MinSizeRel and RelWithDebInfo.
set(CMAKE_CONFIGURATION_TYPES Debug Release CACHE STRING INTERNAL FORCE)

set(ENABLE_STRICT_TRY_COMPILE ON)
set(DEPLOYMENT_TARGET 17) # I really need onChange for focus out.
set(CMAKE_TOOLCHAIN_FILE "${CMAKE_CURRENT_LIST_DIR}/ios-cmake/ios.toolchain.cmake")

project(fcitx5-ios VERSION 0.1.0 LANGUAGES CXX Swift)
set(CMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED YES) # Need it for AppGroup even for simulator.
set(CMAKE_OSX_DEPLOYMENT_TARGET 17)
set(CMAKE_Swift_LANGUAGE_VERSION 5.9)
set(CMAKE_CXX_STANDARD 20)

set(BUNDLE_IDENTIFIER "org.fcitx.Fcitx5")
set(BUNDLE_NAME "Fcitx5")

list(PREPEND CMAKE_MODULE_PATH "${PROJECT_SOURCE_DIR}/cmake")

include(InitializeSwift)
include(AddSwift)

set(FIND_ROOT_PATH "${PROJECT_BINARY_DIR}/usr")
set(PREBUILDER_INCLUDE_DIR "${FIND_ROOT_PATH}/include")
set(PREBUILDER_LIB_DIR "${FIND_ROOT_PATH}/lib")
set(PREBUILDER_SHARE_DIR "${FIND_ROOT_PATH}/share")

set(ENV{PKG_CONFIG_SYSROOT_DIR} "${PROJECT_BINARY_DIR}")
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
find_package(nlohmann_json REQUIRED)

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
option(HALLELUJAH "" ON)
option(MOZC "" ON)
option(RIME "" ON)

function(copy_to_keyboard keyboard cmd file relative_path)
    add_custom_command(TARGET "${keyboard}Extension"
        POST_BUILD COMMAND /bin/sh -c \"
        ${CMAKE_COMMAND} -E ${cmd} ${file}
            ${PROJECT_BINARY_DIR}/src/$<CONFIG>-${SDK_NAME}/${keyboard}.appex/${relative_path}
    \")
endfunction()

function(copy_share_to_keyboard keyboard cmd relative_path)
    copy_to_keyboard(${keyboard} ${cmd} "${PREBUILDER_SHARE_DIR}/${relative_path}" "share/${relative_path}")
endfunction()

function(copy_to_app cmd file relative_path)
    add_custom_command(TARGET ${BUNDLE_NAME}
        POST_BUILD COMMAND /bin/sh -c \"
        ${CMAKE_COMMAND} -E ${cmd} ${file}
            ${PROJECT_BINARY_DIR}/src/$<CONFIG>-${SDK_NAME}/${BUNDLE_NAME}.app/${relative_path}
    \")
endfunction()

set(Fcitx5Utils_DIR "${PROJECT_SOURCE_DIR}/cmake")
add_subdirectory(engines)

fcitx5_get_addon_targets(COMMON_TARGETS iosnotifications fcitx5 iosfrontend uipanel)

set(LOCALES en zh-Hans)
list(TRANSFORM LOCALES APPEND ".lproj" OUTPUT_VARIABLE LPROJS)
add_subdirectory(assets)
add_subdirectory(common)
add_subdirectory(keyboard)
add_subdirectory(src)
