#include "common.h"
#include "../engines/fcitx5-hallelujah/src/hallelujah.h"
#include "../engines/fcitx5-rime/src/rimeengine.h"
#include "../fcitx5/src/modules/spell/spell.h"
#include "../iosfrontend/iosfrontend.h"
#include "../uipanel/uipanel.h"
#include "nativestreambuf.h"
#include <filesystem>

#include <thread>

#ifdef HALLELUJAH
fcitx::HallelujahFactory HallelujahFactory;
fcitx::SpellModuleFactory SpellModuleFactory;
#endif
#ifdef RIME
fcitx::RimeEngineFactory RimeFactory;
#endif

namespace fs = std::filesystem;

fcitx::IosFrontendFactory IosFrontendFactory;
fcitx::UIPanelFactory UIPanelFactory;

fcitx::StaticAddonRegistry addons = {
#ifdef HALLELUJAH
    std::make_pair<std::string, fcitx::AddonFactory *>("spell",
                                                       &SpellModuleFactory),
#endif
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

std::unique_ptr<fcitx::Instance> instance;
std::unique_ptr<fcitx::EventDispatcher> dispatcher;

native_streambuf log_streambuf;
std::ostream stream(&log_streambuf);

std::thread fcitx_thread;

void setupLog() {
    fcitx::Log::setLogStream(stream);
    fcitx::Log::setLogRule("*=5,notimedate");
}

void setupEnv(const char *bundlePath, const char *appGroupPath,
              bool isMainApp) {
    setenv("F5I_ENV", isMainApp ? "main" : "keyboard", 1);

    fs::path bundle = bundlePath;
    std::string xdg_data_dirs = bundle / "share";
    setenv("XDG_DATA_DIRS", xdg_data_dirs.c_str(), 1);

    fs::path group = appGroupPath;
    std::string xdg_data_home = group / "data";
    std::string fcitx_config_home = group / "config";
    setenv("XDG_DATA_HOME", xdg_data_home.c_str(), 1);
    // By default FCITX_DATA_HOME is XDG_DATA_HOME/fcitx5. Flatten it like f5a.
    setenv("FCITX_DATA_HOME", xdg_data_home.c_str(), 1);
    // By default FCITX_CONFIG_HOME is XDG_CONFIG_HOME/fcitx5. Move it from
    // ~/.config/fcitx5 to appGroupPath/config.
    setenv("FCITX_CONFIG_HOME", fcitx_config_home.c_str(), 1);
}

void setupFcitx(const char *bundlePath, const char *appGroupPath,
                bool isMainApp) {
    setupLog();
    setupEnv(bundlePath, appGroupPath, isMainApp);

    instance = std::make_unique<fcitx::Instance>(0, nullptr);
    instance->setInputMethodMode(fcitx::InputMethodMode::OnScreenKeyboard);
    auto &addonMgr = instance->addonManager();
    addonMgr.registerDefaultLoader(&addons);
    instance->initialize();
    dispatcher = std::make_unique<fcitx::EventDispatcher>();
    dispatcher->attach(&instance->eventLoop());
    fcitx_thread = std::thread([] { instance->eventLoop().exec(); });
}
