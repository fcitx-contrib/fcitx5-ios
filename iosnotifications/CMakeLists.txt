add_library(NotifySwift STATIC notify.swift toast.swift)
set_target_properties(NotifySwift PROPERTIES Swift_MODULE_NAME NotifySwift)
target_compile_options(NotifySwift PUBLIC "$<$<COMPILE_LANGUAGE:Swift>:-cxx-interoperability-mode=default>")

_swift_generate_cxx_header(
    NotifySwift
    "${CMAKE_CURRENT_BINARY_DIR}/include/notify-swift.h"
    SOURCES "${CMAKE_CURRENT_SOURCE_DIR}/notify.swift"
    SEARCH_PATHS "${CMAKE_CURRENT_SOURCE_DIR}"
)

add_library(iosnotifications iosnotifications.cpp)
add_dependencies(iosnotifications NotifySwift)
target_include_directories(iosnotifications PUBLIC
    "${CMAKE_CURRENT_BINARY_DIR}/include"
)
target_link_libraries(iosnotifications Fcitx5::Core Fcitx5::Module::Notifications)

configure_file(notifications.conf.in.in notifications.conf.in @ONLY)
fcitx5_translate_desktop_file(${CMAKE_CURRENT_BINARY_DIR}/notifications.conf.in notifications.conf)

add_custom_command(
    TARGET iosnotifications
    POST_BUILD COMMAND /bin/sh -c
    \"
    ${CMAKE_COMMAND} -E copy
        ${CMAKE_CURRENT_BINARY_DIR}/notifications.conf
        ${PROJECT_BINARY_DIR}/keyboard/$<CONFIG>${CMAKE_XCODE_EFFECTIVE_PLATFORMS}/keyboard.appex/share/fcitx5/addon/notifications.conf
    \"
)
