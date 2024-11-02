add_library(FcitxIpc ipc.swift)
set_target_properties(FcitxIpc PROPERTIES Swift_MODULE_NAME FcitxIpc)
target_compile_options(FcitxIpc PUBLIC "$<$<COMPILE_LANGUAGE:Swift>:-cxx-interoperability-mode=default>")

_swift_generate_cxx_header(
    FcitxIpc
    "${CMAKE_CURRENT_BINARY_DIR}/include/fcitxipc-swift.h"
    SOURCES "${CMAKE_CURRENT_SOURCE_DIR}/ipc.swift"
    SEARCH_PATHS "${CMAKE_XCODE_EFFECTIVE_PLATFORMS}"
)
