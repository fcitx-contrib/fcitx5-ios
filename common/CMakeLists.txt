add_library(FcitxCommon
    common.cpp
    inputmethod.cpp
)
target_include_directories(FcitxCommon PRIVATE
    "${PROJECT_SOURCE_DIR}/fcitx5/src/modules/notifications"
)
target_link_libraries(FcitxCommon Fcitx5::Core nlohmann_json)

add_library(SwiftUtil util.swift locale.swift)
set_target_properties(SwiftUtil PROPERTIES Swift_MODULE_NAME SwiftUtil)
