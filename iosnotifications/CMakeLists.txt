add_library(NotifySwift STATIC notify.swift toast.swift)
set_target_properties(NotifySwift PROPERTIES Swift_MODULE_NAME NotifySwift)
target_compile_options(NotifySwift PUBLIC "$<$<COMPILE_LANGUAGE:Swift>:-cxx-interoperability-mode=default>")

_swift_generate_cxx_header(
    NotifySwift
    "${CMAKE_CURRENT_BINARY_DIR}/include/notify-swift.h"
    SOURCES "${CMAKE_CURRENT_SOURCE_DIR}/notify.swift"
    SEARCH_PATHS "${CMAKE_CURRENT_SOURCE_DIR}"
)

add_fcitx5_addon(notifications iosnotifications.cpp)
add_dependencies(notifications NotifySwift)
target_include_directories(notifications PUBLIC
    "${CMAKE_CURRENT_BINARY_DIR}/include"
)
target_link_libraries(notifications Fcitx5::Core Fcitx5::Module::Notifications)

configure_file(notifications.conf.in.in notifications.conf.in @ONLY)
fcitx5_translate_desktop_file(${CMAKE_CURRENT_BINARY_DIR}/notifications.conf.in notifications.conf)
