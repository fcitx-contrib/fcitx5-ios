#include <fcitx/addoninstance.h>
#include <fcitx/addonloader.h>

#ifndef FCITX_ENGINE_REGISTRY
#error FCITX_ENGINE_REGISTRY must name this engine framework's addon registry
#endif

#ifndef FCITX_ENGINE_LOAD_FUNCTION
#error FCITX_ENGINE_LOAD_FUNCTION must name this engine framework's load function
#endif

extern fcitx::StaticAddonRegistry &getStaticAddon();

FCITX_DEFINE_STATIC_ADDON_REGISTRY(FCITX_ENGINE_REGISTRY)

extern "C" __attribute__((visibility("default"))) void
FCITX_ENGINE_LOAD_FUNCTION() {
    static const bool loaded = [] {
        auto &runtimeRegistry = getStaticAddon();
        auto &engineRegistry = FCITX_ENGINE_REGISTRY();
        runtimeRegistry.insert(engineRegistry.begin(), engineRegistry.end());
        return true;
    }();
    (void)loaded;
}
