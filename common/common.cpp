#include "common.h"
#include "../engines/fcitx5-hallelujah/src/factory.h"
#include "../fcitx5/src/lib/fcitx/addoninstance.h"
#include "../fcitx5/src/lib/fcitx/addonmanager.h"
#include "nativestreambuf.h"
#include <filesystem>

#include <thread>

#ifdef HALLELUJAH
fcitx::HallelujahFactory HallelujahFactory;
#endif

namespace fs = std::filesystem;

static fcitx::StaticAddonRegistry addons = {
#ifdef HALLELUJAH
    std::make_pair<std::string, fcitx::AddonFactory *>("hallelujah",
                                                       &HallelujahFactory),
#endif
};

FCITX_IMPORT_ADDON_FACTORY(addons, iosfrontend);
FCITX_IMPORT_ADDON_FACTORY(addons, notifications);
FCITX_IMPORT_ADDON_FACTORY(addons, uipanel);

#ifdef CHINESE_ADDONS
FCITX_IMPORT_ADDON_FACTORY(addons, pinyin);
FCITX_IMPORT_ADDON_FACTORY(addons, table);
FCITX_IMPORT_ADDON_FACTORY(addons, chttrans);
FCITX_IMPORT_ADDON_FACTORY(addons, fullwidth);
FCITX_IMPORT_ADDON_FACTORY(addons, pinyinhelper);
FCITX_IMPORT_ADDON_FACTORY(addons, punctuation);
#endif

#if defined(HALLELUJAH) || defined(CHINESE_ADDONS)
FCITX_IMPORT_ADDON_FACTORY(addons, spell);
#endif

#ifdef RIME
FCITX_IMPORT_ADDON_FACTORY(addons, rime);
#endif

std::unique_ptr<fcitx::Instance> instance;
std::unique_ptr<fcitx::EventDispatcher> dispatcher;

static native_streambuf log_streambuf;
static std::ostream stream(&log_streambuf);

static std::thread fcitx_thread;

void setupLog() {
    fcitx::Log::setLogStream(stream);
    fcitx::Log::setLogRule("*=5,notimedate");
}

void setupEnv(const char *bundlePath, const char *appGroupPath,
              bool isMainApp) {
    setenv("F5I_ENV", isMainApp ? "main" : "keyboard", 1);

    fs::path bundle = bundlePath;
    std::string xdg_data_dirs = bundle / "share";
    std::string libime_model_dirs = bundle / "lib/libime";
    setenv("XDG_DATA_DIRS", xdg_data_dirs.c_str(), 1);
    setenv("LIBIME_MODEL_DIRS", libime_model_dirs.c_str(), 1);

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
    instance->setVirtualKeyboardAutoShow(true);
    instance->setVirtualKeyboardAutoHide(true);
    auto &addonMgr = instance->addonManager();
    addonMgr.registerDefaultLoader(&addons);
    instance->initialize();
    dispatcher = std::make_unique<fcitx::EventDispatcher>();
    dispatcher->attach(&instance->eventLoop());
    fcitx_thread = std::thread([] { instance->eventLoop().exec(); });
}
