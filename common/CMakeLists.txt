add_library(FcitxCommon common.cpp)
target_include_directories(FcitxCommon PRIVATE
    "${PROJECT_SOURCE_DIR}/fcitx5/src/modules/notifications"
)
target_link_libraries(FcitxCommon Fcitx5::Core)

add_library(SwiftUtil util.swift)
set_target_properties(SwiftUtil PROPERTIES Swift_MODULE_NAME SwiftUtil)
