#include "fcitx.h"
#include "../common/common.h"
#include <fcitx-config/rawconfig.h>
#include <fcitx/addonmanager.h>

constexpr char addonConfigPrefix[] = "fcitx://config/addon/";

void startFcitx(const char *bundlePath, const char *appGroupPath) {
    if (instance) {
        return;
    }
    setupFcitx(bundlePath, appGroupPath, true);
}

static std::tuple<std::string, std::string>
parseAddonUri(const std::string &uri) {
    auto addon = uri.substr(sizeof(addonConfigPrefix) - 1);
    auto pos = addon.find('/');
    if (pos == std::string::npos) {
        return {addon, ""};
    } else {
        return {addon.substr(0, pos), addon.substr(pos + 1)};
    }
}

void setConfig(const char *uri_, const char *value) {
    std::string uri = uri_;
    if (fcitx::stringutils::startsWith(uri, addonConfigPrefix)) {
        dispatcher->schedule([=] {
            auto [addonName, subPath] = parseAddonUri(uri);
            auto *addon = instance->addonManager().addon(addonName, true);
            if (addon) {
                FCITX_DEBUG() << "Saving addon config to: " << uri;
                if (subPath.empty()) {
                    // addon->setConfig(config);
                } else {
                    addon->setSubConfig(subPath, fcitx::RawConfig());
                }
            } else {
                FCITX_ERROR() << "Failed to get addon";
            }
        });
    }
}
