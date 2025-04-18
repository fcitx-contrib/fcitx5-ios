add_library(SwiftFrontend STATIC iosfrontend.swift)
set_target_properties(SwiftFrontend PROPERTIES Swift_MODULE_NAME SwiftFrontend)
target_compile_options(SwiftFrontend PUBLIC "$<$<COMPILE_LANGUAGE:Swift>:-cxx-interoperability-mode=default>")
target_include_directories(SwiftFrontend PUBLIC
    "${CMAKE_CURRENT_SOURCE_DIR}"
    "${PROJECT_BINARY_DIR}/protocol/$<CONFIG>-${SDK_NAME}"
)
target_link_libraries(SwiftFrontend FcitxProtocol)

_swift_generate_cxx_header(
    SwiftFrontend
    "${CMAKE_CURRENT_BINARY_DIR}/include/iosfrontend-swift.h"
    SOURCES "${CMAKE_CURRENT_SOURCE_DIR}/iosfrontend.swift"
    SEARCH_PATHS "${CMAKE_CURRENT_SOURCE_DIR};${PROJECT_BINARY_DIR}/protocol/$<CONFIG>-${SDK_NAME}"
)

add_fcitx5_addon(iosfrontend iosfrontend.cpp)
add_dependencies(iosfrontend SwiftFrontend)
target_link_libraries(iosfrontend Fcitx5::Core)
target_include_directories(iosfrontend PUBLIC
    "${CMAKE_CURRENT_BINARY_DIR}/include"
)

configure_file(iosfrontend.conf.in.in iosfrontend.conf.in @ONLY)
fcitx5_translate_desktop_file(${CMAKE_CURRENT_BINARY_DIR}/iosfrontend.conf.in iosfrontend.conf)
