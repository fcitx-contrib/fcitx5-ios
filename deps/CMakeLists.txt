add_subdirectory(AlertToast)

file(GLOB SWIFTER_FILES CONFIGURE_DEPENDS swifter/Xcode/Sources/*.swift)
add_library(Swifter STATIC ${SWIFTER_FILES})
set_target_properties(Swifter PROPERTIES Swift_MODULE_NAME Swifter)
# We don't care 3rd-party warnings as long as it works.
target_compile_options(Swifter PRIVATE -suppress-warnings)
