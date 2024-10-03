add_library(iosfrontend STATIC iosfrontend.cpp)
target_link_libraries(iosfrontend Fcitx5::Core)

configure_file(iosfrontend.conf.in.in iosfrontend.conf.in @ONLY)
fcitx5_translate_desktop_file(${CMAKE_CURRENT_BINARY_DIR}/iosfrontend.conf.in iosfrontend.conf)

add_custom_command(
    TARGET iosfrontend
    POST_BUILD COMMAND /bin/sh -c
    \"COMMAND_DONE=0 \;
    if ${CMAKE_COMMAND} -E copy
        ${CMAKE_CURRENT_BINARY_DIR}/iosfrontend.conf
        ${PROJECT_BINARY_DIR}/keyboard/$<CONFIG>${CMAKE_XCODE_EFFECTIVE_PLATFORMS}/keyboard.appex/share/fcitx5/addon/iosfrontend.conf
        \&\>/dev/null \; then
        COMMAND_DONE=1 \;
    fi \;
    if [ \\$$COMMAND_DONE -eq 0 ] \; then
        echo Failed to copy the conf into the app bundle \;
        exit 1 \;
    fi\"
)
