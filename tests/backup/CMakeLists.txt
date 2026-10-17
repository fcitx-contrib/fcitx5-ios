# The main targets use the iOS toolchain. Like UndoRedoSwift, compile a separate
# macOS executable and its dependencies with the host SDK for CTest.
set(BACKUP_HOST_DIR "${CMAKE_CURRENT_BINARY_DIR}/host")
set(BACKUP_MODULE_CACHE "${CMAKE_CURRENT_BINARY_DIR}/ModuleCache")
set(BACKUP_SQLITE_MODULE "${PROJECT_SOURCE_DIR}/deps/GRDB/Sources/GRDBSQLite")

get_target_property(BACKUP_GRDB_SOURCES GRDB SOURCES)
get_target_property(BACKUP_GRDB_OPTIONS GRDB COMPILE_OPTIONS)
get_target_property(BACKUP_ZIP_SOURCES ZIPFoundation SOURCES)

add_custom_command(
    OUTPUT "${BACKUP_HOST_DIR}/libGRDB.a" "${BACKUP_HOST_DIR}/GRDB.swiftmodule"
    COMMAND "${CMAKE_COMMAND}" -E make_directory "${BACKUP_HOST_DIR}"
    COMMAND "${XCRUN}" --sdk macosx swiftc
        -swift-version "${CMAKE_Swift_LANGUAGE_VERSION}"
        -module-cache-path "${BACKUP_MODULE_CACHE}"
        -I "${BACKUP_SQLITE_MODULE}"
        ${BACKUP_GRDB_OPTIONS}
        -emit-library -static -emit-module -module-name GRDB
        -emit-module-path "${BACKUP_HOST_DIR}/GRDB.swiftmodule"
        ${BACKUP_GRDB_SOURCES}
        -o "${BACKUP_HOST_DIR}/libGRDB.a"
    DEPENDS ${BACKUP_GRDB_SOURCES}
        "${BACKUP_SQLITE_MODULE}/module.modulemap"
        "${BACKUP_SQLITE_MODULE}/shim.h"
    VERBATIM
)

add_custom_command(
    OUTPUT "${BACKUP_HOST_DIR}/libZIPFoundation.a" "${BACKUP_HOST_DIR}/ZIPFoundation.swiftmodule"
    COMMAND "${CMAKE_COMMAND}" -E make_directory "${BACKUP_HOST_DIR}"
    COMMAND "${XCRUN}" --sdk macosx swiftc
        -swift-version "${CMAKE_Swift_LANGUAGE_VERSION}"
        -module-cache-path "${BACKUP_MODULE_CACHE}"
        -emit-library -static -emit-module -module-name ZIPFoundation
        -emit-module-path "${BACKUP_HOST_DIR}/ZIPFoundation.swiftmodule"
        ${BACKUP_ZIP_SOURCES}
        -o "${BACKUP_HOST_DIR}/libZIPFoundation.a"
    DEPENDS ${BACKUP_ZIP_SOURCES}
    VERBATIM
)

set(BACKUP_TEST "${CMAKE_CURRENT_BINARY_DIR}/BackupTests")
set(BACKUP_TEST_SOURCES
    "${CMAKE_CURRENT_SOURCE_DIR}/BackupTests.swift"
    "${PROJECT_SOURCE_DIR}/src/DatabaseBackup.swift"
    "${PROJECT_SOURCE_DIR}/src/BackupArchive.swift"
)
add_custom_command(
    OUTPUT "${BACKUP_TEST}"
    COMMAND "${XCRUN}" --sdk macosx swiftc
        -swift-version "${CMAKE_Swift_LANGUAGE_VERSION}"
        -module-cache-path "${BACKUP_MODULE_CACHE}"
        -I "${BACKUP_HOST_DIR}" -I "${BACKUP_SQLITE_MODULE}"
        ${BACKUP_TEST_SOURCES}
        "${BACKUP_HOST_DIR}/libGRDB.a" "${BACKUP_HOST_DIR}/libZIPFoundation.a"
        -o "${BACKUP_TEST}"
    DEPENDS ${BACKUP_TEST_SOURCES}
        "${BACKUP_HOST_DIR}/libGRDB.a" "${BACKUP_HOST_DIR}/GRDB.swiftmodule"
        "${BACKUP_HOST_DIR}/libZIPFoundation.a" "${BACKUP_HOST_DIR}/ZIPFoundation.swiftmodule"
    VERBATIM
)
add_custom_target(BackupSwiftTest ALL DEPENDS "${BACKUP_TEST}")
add_test(NAME BackupSwift COMMAND "${BACKUP_TEST}")
