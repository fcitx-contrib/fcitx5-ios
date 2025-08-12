#include "common.h"
#include "../fcitx5/src/lib/fcitx/addonmanager.h"
#include "nativestreambuf.h"
#include <fcitx-utils/i18n.h>
#include <filesystem>
#include <thread>

namespace fs = std::filesystem;

FCITX_DEFINE_STATIC_ADDON_REGISTRY(getStaticAddon)

std::unique_ptr<fcitx::Instance> instance;
std::unique_ptr<fcitx::EventDispatcher> dispatcher;

static native_streambuf log_streambuf;
static std::ostream stream(&log_streambuf);

static std::thread fcitx_thread;

void setupLog() {
    fcitx::Log::setLogStream(stream);
    fcitx::Log::setLogRule("*=5,notimedate");
}

void setupEnv(const char *appBundlePath, const std::string &xdgDataDirs,
              const char *appGroupPath, bool isMainApp) {
    setenv("F5I_ENV", isMainApp ? "main" : "keyboard", 1);

    fs::path appBundle = appBundlePath;
    std::string xdg_data_dirs = appBundle / "share";
    // For app it's app share plus all keyboards' share, and for keyboard it's
    // app share plus its own share.
    xdg_data_dirs += ":" + xdgDataDirs;
    std::string libime_model_dirs =
        appBundle / "PlugIns/Chinese.appex/lib/libime";
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

// Collect all share/locale/*/LC_MESSAGES/*.mo
std::set<std::string> getAllDomains(const fs::path &localedir) {
    std::set<std::string> ret;
    try {
        for (const auto &entry : fs::directory_iterator(localedir)) {
            if (!entry.is_directory()) {
                continue;
            }
            fs::path lcMessagesPath = entry.path() / "LC_MESSAGES";
            try {
                for (const auto &file :
                     fs::directory_iterator(lcMessagesPath)) {
                    if (file.path().extension() == ".mo") {
                        ret.insert(file.path().stem());
                    }
                }
            } catch (const std::exception &e) {
                // LC_MESSAGES not exist.
            }
        }
    } catch (const std::exception &e) {
        // localedir not exist.
    }
    return ret;
}

// Must be executed before creating fcitx instance, i.e. loading addons, because
// addons register compile-time domain path, and only 1st call of registerDomain
// counts. The .mo files must exist.
void setupI18N(const char *appBundlePath) {
    fs::path bundle = appBundlePath;
    fs::path localedir = bundle / "share" / "locale";
    for (const auto &domain : getAllDomains(localedir)) {
        fcitx::registerDomain(domain.c_str(), localedir);
    }
}

void setupFcitx(const char *appBundlePath, const char *xdgDataDirs,
                const char *appGroupPath, bool isMainApp) {
    setupLog();
    setupEnv(appBundlePath, xdgDataDirs, appGroupPath, isMainApp);
    setupI18N(appBundlePath);

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

void setLocale(const char *locale) {
    std::string val = locale;
    val += ":C";
    // For config items.
    setenv("LANGUAGE", val.c_str(), 1);
    // For addon names.
    setenv("FCITX_LOCALE", val.c_str(), 1);
}
