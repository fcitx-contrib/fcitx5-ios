#include "fcitx.h"
#include "../common/common.h"
#include "../common/util.h"
#include <fcitx-config/rawconfig.h>
#include <fcitx/addonmanager.h>
#include <fcitx/inputmethodmanager.h>
#include <nlohmann/json.hpp>

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

void setInputMethods(const char *json) {
    with_fcitx([=] {
        auto &imMgr = instance->inputMethodManager();
        auto group = imMgr.currentGroup();
        auto &imList = group.inputMethodList();
        imList.clear();
        auto j = nlohmann::json::parse(json);
        for (const auto &im : j) {
            imList.emplace_back(im.get<std::string>());
        }
        imMgr.setGroup(group);
        imMgr.save();
    });
}

std::string getAllInputMethods() {
    return with_fcitx([] {
        nlohmann::json j;
        auto &imMgr = instance->inputMethodManager();
        imMgr.foreachEntries([&j](const fcitx::InputMethodEntry &entry) {
            j.push_back(jsonDescribeIm(&entry));
            return true;
        });
        return j.dump();
    });
}
