file(GLOB_RECURSE GRDB_FILES CONFIGURE_DEPENDS "${GRDB_SOURCE_DIR}/GRDB/*.swift")
add_library(GRDB STATIC ${GRDB_FILES})
set_target_properties(GRDB PROPERTIES Swift_MODULE_NAME GRDB)
target_include_directories(GRDB PUBLIC "${GRDB_SOURCE_DIR}/Sources/GRDBSQLite")
target_compile_options(GRDB PRIVATE
    -DSQLITE_ENABLE_FTS5
    -DSQLITE_ENABLE_SNAPSHOT
    -enable-upcoming-feature MemberImportVisibility
)
target_link_libraries(GRDB PUBLIC sqlite3)
