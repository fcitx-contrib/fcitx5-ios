add_library(FcitxIpc ipc.swift)
set_target_properties(FcitxIpc PROPERTIES Swift_MODULE_NAME FcitxIpc)
target_include_directories(FcitxIpc PRIVATE "${PROJECT_BINARY_DIR}/common/$<CONFIG>-${SDK_NAME}")
target_compile_options(FcitxIpc PUBLIC "$<$<COMPILE_LANGUAGE:Swift>:-cxx-interoperability-mode=default>")
target_link_libraries(FcitxIpc SwiftUtil)

_swift_generate_cxx_header(
    FcitxIpc
    "${CMAKE_CURRENT_BINARY_DIR}/include/fcitxipc-swift.h"
    SOURCES "${CMAKE_CURRENT_SOURCE_DIR}/ipc.swift"
    SEARCH_PATHS "${PROJECT_BINARY_DIR}/common/$<CONFIG>-${SDK_NAME}"
)
