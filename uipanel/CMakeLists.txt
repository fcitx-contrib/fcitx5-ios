add_library(uipanel STATIC uipanel.cpp)
target_link_libraries(uipanel Fcitx5::Core)

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
