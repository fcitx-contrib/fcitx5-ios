#include "common.h"
#include "../fcitx5/src/lib/fcitx/addonmanager.h"
#include "nativestreambuf.h"
#include <filesystem>

#include <thread>

namespace fs = std::filesystem;

extern fcitx::StaticAddonRegistry &getStaticAddon();

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
    addonMgr.registerDefaultLoader(&getStaticAddon());
    instance->initialize();
    dispatcher = std::make_unique<fcitx::EventDispatcher>();
    dispatcher->attach(&instance->eventLoop());
    fcitx_thread = std::thread([] { instance->eventLoop().exec(); });
}
