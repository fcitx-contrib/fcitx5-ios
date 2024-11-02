#include "../engines/fcitx5-hallelujah/src/hallelujah.h"
#include "../engines/fcitx5-rime/src/rimeengine.h"

#include "../fcitx5/src/modules/spell/spell.h"
#include "../iosfrontend/iosfrontend.h"
#include "../uipanel/uipanel.h"
#include "nativestreambuf.h"
#include <fcitx-utils/event.h>
#include <fcitx-utils/eventdispatcher.h>
#include <filesystem>
#include <thread>

#include "fcitx.h"
#include "util.h"

#ifdef HALLELUJAH
fcitx::HallelujahFactory HallelujahFactory;
#endif
#ifdef RIME
fcitx::RimeEngineFactory RimeFactory;
#endif

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
#ifdef HALLELUJAH
    std::make_pair<std::string, fcitx::AddonFactory *>("hallelujah",
                                                       &HallelujahFactory),
#endif
#ifdef RIME
    std::make_pair<std::string, fcitx::AddonFactory *>("rime", &RimeFactory),
#endif
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

void setupEnv(const char *bundlePath, const char *appGroupPath) {
    fs::path bundle = bundlePath;
    fs::path group = appGroupPath;
    std::string xdg_data_dirs = bundle / "share";
    std::string xdg_data_home = group / "data";
    std::string fcitx_config_home = group / "config";
    setenv("XDG_DATA_DIRS", xdg_data_dirs.c_str(), 1);
    setenv("XDG_DATA_HOME", xdg_data_home.c_str(), 1);
    // By default FCITX_DATA_HOME is XDG_DATA_HOME/fcitx5. Flatten it like f5a.
    setenv("FCITX_DATA_HOME", xdg_data_home.c_str(), 1);
    // By default FCITX_CONFIG_HOME is XDG_CONFIG_HOME/fcitx5. Move it from
    // ~/.config/fcitx5 to appGroupPath/config.
    setenv("FCITX_CONFIG_HOME", fcitx_config_home.c_str(), 1);
    // Distinguish with main app.
    setenv("F5I_ENV", "keyboard", 1);
}

void startFcitx(const char *bundlePath, const char *appGroupPath) {
    if (instance) {
        return;
    }
    setupLog();
    setupEnv(bundlePath, appGroupPath);

    instance = std::make_unique<fcitx::Instance>(0, nullptr);
    instance->setInputMethodMode(fcitx::InputMethodMode::OnScreenKeyboard);
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

void focusOut() {
    return with_fcitx([] { frontend->focusOut(); });
}

bool processKey(const char *key) {
    return with_fcitx(
        [key] { return frontend->keyEvent(fcitx::Key{key}, false); });
}
