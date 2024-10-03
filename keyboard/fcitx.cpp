#include "../iosfrontend/iosfrontend.h"
#include "nativestreambuf.h"
#include <fcitx/instance.h>
#include <filesystem>
#include <thread>

#include "fcitx.h"

namespace fs = std::filesystem;

fcitx::IosFrontendFactory IosFrontendFactory;
fcitx::StaticAddonRegistry addons = {
    std::make_pair<std::string, fcitx::AddonFactory *>("iosfrontend",
                                                       &IosFrontendFactory),
};

native_streambuf log_streambuf;
std::unique_ptr<fcitx::Instance> instance;
std::ostream stream(&log_streambuf);
std::thread fcitx_thread;

void setupLog() {
    fcitx::Log::setLogStream(stream);
    fcitx::Log::setLogRule("*=5,notimedate");
}

void setupEnv(const char *bundlePath) {
    fs::path bundle = bundlePath;
    std::string fcitx_data_home = bundle / "share/fcitx5";
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
    fcitx_thread = std::thread([] { instance->exec(); });
    return;
}
