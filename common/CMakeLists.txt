add_library(SwiftUtil util.swift logging.swift locale.swift ClipboardStore.swift ClipboardSync.swift ClipboardTransport.swift ClipboardSuggestion.swift)
set_target_properties(SwiftUtil PROPERTIES Swift_MODULE_NAME SwiftUtil)
target_link_libraries(SwiftUtil PUBLIC GRDB)

set(CMAKE_SHARED_LINKER_FLAGS "")
add_library(FcitxRuntime SHARED
    inputmethod.cpp
    runtime_main.cpp
    runtime_keyboard.cpp
    runtime_config.cpp
    keycode.cpp
)
set_target_properties(FcitxRuntime PROPERTIES
    FRAMEWORK TRUE
    MACOSX_FRAMEWORK_IDENTIFIER "${BUNDLE_IDENTIFIER}.FcitxRuntime"
)
target_include_directories(FcitxRuntime PRIVATE
    "${PROJECT_SOURCE_DIR}/fcitx5/src/modules/notifications"
    "${PROJECT_SOURCE_DIR}/fcitx5/src/modules/unicode"
    "${PROJECT_SOURCE_DIR}/fcitx5/src/modules/quickphrase"
)
target_compile_options(FcitxRuntime PRIVATE
    "$<$<COMPILE_LANGUAGE:CXX>:-fvisibility=default>"
)
target_link_libraries(FcitxRuntime
    Fcitx5::Core
    nlohmann_json
    SwiftFrontend
    KeyboardUI
    NotifySwift
    SwiftUtil
    FcitxProtocol
)
# Export the complete shared API, including backup methods used only by the app.
# Consumers import the Swift modules but use the implementation in FcitxRuntime.
set_target_properties(FcitxRuntime PROPERTIES
    LINK_LIBRARY_OVERRIDE "WHOLE_ARCHIVE,SwiftUtil,GRDB"
)
