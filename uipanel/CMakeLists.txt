add_library(KeyboardUI STATIC
    keyboardui.swift
    VirtualKeyboard.swift
    ContextMenu.swift
    Key.swift
    Keyboard.swift
    Candidate.swift
    WrapLayout.swift
    CandidateBar.swift
    Toolbar.swift
    StatusArea.swift
    Edit.swift
    Symbol.swift
    ReturnBar.swift
    ui.swift
)
set_target_properties(KeyboardUI PROPERTIES Swift_MODULE_NAME KeyboardUI)
target_compile_options(KeyboardUI PUBLIC "$<$<COMPILE_LANGUAGE:Swift>:-cxx-interoperability-mode=default>")
target_include_directories(KeyboardUI PUBLIC
    "${CMAKE_CURRENT_SOURCE_DIR}"
    "${PROJECT_SOURCE_DIR}/common"
    "${PROJECT_BINARY_DIR}/protocol/$<CONFIG>-${SDK_NAME}"
    "${PROJECT_BINARY_DIR}/common/$<CONFIG>-${SDK_NAME}"
)
target_link_libraries(KeyboardUI FcitxProtocol FcitxCommon SwiftUtil)

_swift_generate_cxx_header(
    KeyboardUI
    "${CMAKE_CURRENT_BINARY_DIR}/include/keyboardui-swift.h"
    SOURCES "${CMAKE_CURRENT_SOURCE_DIR}/keyboardui.swift"
    SEARCH_PATHS "${CMAKE_CURRENT_SOURCE_DIR};${PROJECT_SOURCE_DIR}/common;${PROJECT_BINARY_DIR}/protocol/$<CONFIG>-${SDK_NAME};${PROJECT_BINARY_DIR}/common/$<CONFIG>-${SDK_NAME}"
)

add_fcitx5_addon(uipanel uipanel.cpp)
add_dependencies(uipanel KeyboardUI)
target_link_libraries(uipanel Fcitx5::Core nlohmann_json)
target_include_directories(uipanel PUBLIC
    "${CMAKE_CURRENT_BINARY_DIR}/include"
)

configure_file(uipanel.conf.in.in uipanel.conf.in @ONLY)
fcitx5_translate_desktop_file(${CMAKE_CURRENT_BINARY_DIR}/uipanel.conf.in uipanel.conf)
