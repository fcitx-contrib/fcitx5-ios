add_library(FcitxCommon common.cpp)
target_include_directories(FcitxCommon PRIVATE
    "${PROJECT_SOURCE_DIR}/fcitx5/src/modules/notifications"
)
target_link_libraries(FcitxCommon Fcitx5::Core)
