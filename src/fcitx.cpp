#include "fcitx.h"
#include "../common/common.h"
#include "../common/util.h"
#include <fcitx/inputmethodmanager.h>
#include <nlohmann/json.hpp>

void startFcitx(const char *appBundlePath, const char *xdgDataDirs,
                const char *appGroupPath) {
    if (instance) {
        return;
    }
    setupFcitx(appBundlePath, xdgDataDirs, appGroupPath, true);
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
        auto j = nlohmann::json::array();
        auto &imMgr = instance->inputMethodManager();
        imMgr.foreachEntries([&j](const fcitx::InputMethodEntry &entry) {
            j.push_back(jsonDescribeIm(&entry));
            return true;
        });
        return j.dump();
    });
}
