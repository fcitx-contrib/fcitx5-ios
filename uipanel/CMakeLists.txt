add_library(KeyboardUI STATIC
    keyboardui.swift
    Key.swift
    Keyboard.swift
    Candidate.swift
    CandidateBar.swift
)
set_target_properties(KeyboardUI PROPERTIES Swift_MODULE_NAME KeyboardUI)
target_compile_options(KeyboardUI PUBLIC "$<$<COMPILE_LANGUAGE:Swift>:-cxx-interoperability-mode=default>")
target_include_directories(KeyboardUI PUBLIC
    "${CMAKE_CURRENT_SOURCE_DIR}"
    "${PROJECT_BINARY_DIR}/protocol/$<CONFIG>${CMAKE_XCODE_EFFECTIVE_PLATFORMS}"
)
target_link_libraries(KeyboardUI FcitxProtocol)

_swift_generate_cxx_header(
    KeyboardUI
    "${CMAKE_CURRENT_BINARY_DIR}/include/keyboardui-swift.h"
    SOURCES "${CMAKE_CURRENT_SOURCE_DIR}/keyboardui.swift"
    SEARCH_PATHS "${CMAKE_CURRENT_SOURCE_DIR};${PROJECT_BINARY_DIR}/protocol/$<CONFIG>${CMAKE_XCODE_EFFECTIVE_PLATFORMS}"
)

add_library(uipanel STATIC uipanel.cpp)
add_dependencies(uipanel KeyboardUI)
target_link_libraries(uipanel Fcitx5::Core)
target_include_directories(uipanel PUBLIC
    "${CMAKE_CURRENT_BINARY_DIR}/include"
)

configure_file(uipanel.conf.in.in uipanel.conf.in @ONLY)
fcitx5_translate_desktop_file(${CMAKE_CURRENT_BINARY_DIR}/uipanel.conf.in uipanel.conf)

add_custom_command(
    TARGET uipanel
    POST_BUILD COMMAND /bin/sh -c
    \"
    ${CMAKE_COMMAND} -E copy
        ${CMAKE_CURRENT_BINARY_DIR}/uipanel.conf
        ${PROJECT_BINARY_DIR}/keyboard/$<CONFIG>${CMAKE_XCODE_EFFECTIVE_PLATFORMS}/keyboard.appex/share/fcitx5/addon/uipanel.conf
    \"
)
