#include "../fcitx5/src/modules/spell/spell.h"
#include "../iosfrontend/iosfrontend.h"
#include "../uipanel/uipanel.h"
#include "nativestreambuf.h"
#include <fcitx-utils/event.h>
#include <fcitx-utils/eventdispatcher.h>
#include <fcitx/instance.h>
#include <filesystem>
#include <thread>

#include "fcitx.h"
#include "util.h"

#if defined(HALLELUJAH)

#include "../engines/fcitx5-hallelujah/src/hallelujah.h"
#define ENGINE_ADDON "hallelujah"
fcitx::HallelujahFactory

#endif
    EngineFactory;

namespace fs = std::filesystem;

fcitx::SpellModuleFactory SpellModuleFactory;
fcitx::IosFrontendFactory IosFrontendFactory;
fcitx::UIPanelFactory UIPanelFactory;

fcitx::StaticAddonRegistry addons = {
    std::make_pair<std::string, fcitx::AddonFactory *>("spell",
                                                       &SpellModuleFactory),
    std::make_pair<std::string, fcitx::AddonFactory *>("iosfrontend",
                                                       &IosFrontendFactory),
    std::make_pair<std::string, fcitx::AddonFactory *>("uipanel",
                                                       &UIPanelFactory),
    std::make_pair<std::string, fcitx::AddonFactory *>(ENGINE_ADDON,
                                                       &EngineFactory),
};

native_streambuf log_streambuf;
std::unique_ptr<fcitx::Instance> instance;
std::unique_ptr<fcitx::EventDispatcher> dispatcher;
fcitx::IosFrontend *frontend;

std::ostream stream(&log_streambuf);
std::thread fcitx_thread;

void setupLog() {
    fcitx::Log::setLogStream(stream);
    fcitx::Log::setLogRule("*=5,notimedate");
}

void setupEnv(const char *bundlePath) {
    fs::path bundle = bundlePath;
    std::string xdg_data_dirs = bundle / "share";
    std::string fcitx_data_home = bundle / "share/fcitx5";
    setenv("XDG_DATA_DIRS", xdg_data_dirs.c_str(), 1);
    setenv("FCITX_DATA_HOME", fcitx_data_home.c_str(), 1);
}

void startFcitx(const char *bundlePath) {
    if (instance) {
        return;
    }
    setupLog();
    setupEnv(bundlePath);

    instance = std::make_unique<fcitx::Instance>(0, nullptr);
    auto &addonMgr = instance->addonManager();
    addonMgr.registerDefaultLoader(&addons);
    instance->initialize();
    frontend =
        dynamic_cast<fcitx::IosFrontend *>(addonMgr.addon("iosfrontend"));
    dispatcher = std::make_unique<fcitx::EventDispatcher>();
    dispatcher->attach(&instance->eventLoop());
    fcitx_thread = std::thread([] { instance->eventLoop().exec(); });
    return;
}

void focusIn(id client) {
    return with_fcitx([client] { frontend->focusIn(client); });
}

bool processKey(const char *key) {
    return with_fcitx(
        [key] { return frontend->keyEvent(fcitx::Key{key}, false); });
}
