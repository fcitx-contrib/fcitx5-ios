# Icon
add_custom_command(
    OUTPUT "${PROJECT_BINARY_DIR}/full-punc.png"
    COMMAND rsvg-convert "${CMAKE_CURRENT_SOURCE_DIR}/full-punc.svg" "-o" "${PROJECT_BINARY_DIR}/full-punc.png"
    DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/full-punc.svg"
)
add_custom_command(
    OUTPUT "${PROJECT_BINARY_DIR}/half-punc.png"
    COMMAND rsvg-convert "${CMAKE_CURRENT_SOURCE_DIR}/half-punc.svg" "-o" "${PROJECT_BINARY_DIR}/half-punc.png"
    DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/half-punc.svg"
)
add_custom_target(png_images ALL
    DEPENDS "${PROJECT_BINARY_DIR}/full-punc.png" "${PROJECT_BINARY_DIR}/half-punc.png"
)

execute_process(COMMAND "${PROJECT_SOURCE_DIR}/scripts/generate-icons.sh")

# I18n
list(TRANSFORM LPROJS PREPEND "${CMAKE_CURRENT_SOURCE_DIR}/" OUTPUT_VARIABLE LPROJ_DIRS)
list(TRANSFORM LPROJ_DIRS APPEND "/Localizable.strings" OUTPUT_VARIABLE LOCALIZABLE_STRINGS_FILES)

file(GLOB_RECURSE LOCALIZABLE_SWIFT_SOURCES ${PROJECT_SOURCE_DIR}/src/*.swift)

add_custom_command(
    OUTPUT ${LOCALIZABLE_STRINGS_FILES}
    COMMAND genstrings ${LOCALIZABLE_SWIFT_SOURCES} -SwiftUI -o ${CMAKE_CURRENT_SOURCE_DIR}/en.lproj
    COMMAND ${PROJECT_SOURCE_DIR}/scripts/update_translations.py ${LOCALIZABLE_STRINGS_FILES}
    DEPENDS ${LOCALIZABLE_SWIFT_SOURCES}
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    COMMENT "Generating Localizable.strings..."
)
add_custom_target(GenerateStrings
    DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/en.lproj/Localizable.strings
)
