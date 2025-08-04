add_custom_command(
    OUTPUT "${PROJECT_BINARY_DIR}/full-punc.png"
    COMMAND magick -background none "${CMAKE_CURRENT_SOURCE_DIR}/full-punc.svg" "${PROJECT_BINARY_DIR}/full-punc.png"
    DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/full-punc.svg"
)
add_custom_command(
    OUTPUT "${PROJECT_BINARY_DIR}/half-punc.png"
    COMMAND magick -background none "${CMAKE_CURRENT_SOURCE_DIR}/half-punc.svg" "${PROJECT_BINARY_DIR}/half-punc.png"
    DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/half-punc.svg"
)
add_custom_target(png_images ALL
    DEPENDS "${PROJECT_BINARY_DIR}/full-punc.png" "${PROJECT_BINARY_DIR}/half-punc.png"
)

execute_process(COMMAND "${PROJECT_SOURCE_DIR}/scripts/generate-icons.sh")
