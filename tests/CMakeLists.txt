find_program(XCRUN xcrun REQUIRED NO_CMAKE_FIND_ROOT_PATH)

set(UNDO_REDO_TEST "${CMAKE_CURRENT_BINARY_DIR}/UndoRedoSwift")
set(UNDO_REDO_TEST_SOURCES
    "${PROJECT_SOURCE_DIR}/keyboard/util.swift"
    "${PROJECT_SOURCE_DIR}/keyboard/UndoRedo.swift"
    "${CMAKE_CURRENT_SOURCE_DIR}/testundoredo.swift"
)
add_custom_command(
    OUTPUT "${UNDO_REDO_TEST}"
    COMMAND "${XCRUN}" --sdk macosx swiftc
        -module-cache-path "${CMAKE_CURRENT_BINARY_DIR}/ModuleCache"
        ${UNDO_REDO_TEST_SOURCES}
        -o "${UNDO_REDO_TEST}"
    DEPENDS ${UNDO_REDO_TEST_SOURCES}
    VERBATIM
)
add_custom_target(UndoRedoSwiftTest ALL DEPENDS "${UNDO_REDO_TEST}")
add_test(NAME UndoRedoSwift COMMAND "${UNDO_REDO_TEST}")
