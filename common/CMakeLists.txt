add_library(SwiftUtil util.swift logging.swift locale.swift)
set_target_properties(SwiftUtil PROPERTIES Swift_MODULE_NAME SwiftUtil)

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

function(add_fcitx_engine_framework engine)
    set(framework "Fcitx${engine}Engine")
    set(registry "get${engine}StaticAddon")
    set(loader "fcitxLoad${engine}Engine")

    add_library(${framework} SHARED
        "${PROJECT_SOURCE_DIR}/common/engine_registry.cpp"
    )
    set_target_properties(${framework} PROPERTIES
        FRAMEWORK TRUE
        MACOSX_FRAMEWORK_IDENTIFIER "${BUNDLE_IDENTIFIER}.${framework}"
    )
    target_compile_definitions(${framework} PRIVATE
        "FCITX_ENGINE_REGISTRY=${registry}"
        "FCITX_ENGINE_LOAD_FUNCTION=${loader}"
    )
    # Use the finished framework binary here instead of the CMake target. If
    # this implementation dependency enters the target link graph, CMake moves
    # FcitxRuntime behind the clients' static Swift module targets. Those
    # archives would then be absorbed into every client instead of being
    # satisfied by FcitxRuntime's exported Swift symbols.
    add_dependencies(${framework} FcitxRuntime)
    target_link_libraries(${framework}
        "${PROJECT_BINARY_DIR}/common/FcitxRuntime.framework/FcitxRuntime"
    )
    fcitx5_import_addons(${framework}
        REGISTRY_VARNAME ${registry}
        ADDONS ${ARGN}
    )

    # fcitx5_import_addons uses the legacy target_link_libraries signature,
    # which makes the static addon targets transitive by default. Clients must
    # link only the finished framework, not absorb those archives again.
    set_target_properties(${framework} PROPERTIES INTERFACE_LINK_LIBRARIES "")
endfunction()

function(link_fcitx_engine target engine)
    set(framework "Fcitx${engine}Engine")
    set(loader "fcitxLoad${engine}Engine")
    set(source "${CMAKE_CURRENT_BINARY_DIR}/${target}-${engine}-load-engine.cpp")

    file(WRITE "${source}" "
extern \"C\" void ${loader}();
__attribute__((constructor)) static void load${engine}Engine() {
    ${loader}();
}
")
    target_sources(${target} PRIVATE "${source}")
    target_link_libraries(${target} ${framework})
endfunction()
