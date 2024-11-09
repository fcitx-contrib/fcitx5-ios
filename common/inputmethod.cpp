#include "common-public.h"
#include "common.h"
#include <fcitx/inputmethodentry.h>
#include <fcitx/inputmethodmanager.h>
#include <nlohmann/json.hpp>

static nlohmann::json jsonDescribeIm(const fcitx::InputMethodEntry *entry) {
    nlohmann::json j;
    j["name"] = entry->uniqueName();
    j["displayName"] = entry->nativeName() != "" ? entry->nativeName()
                       : entry->name() != ""     ? entry->name()
                                                 : entry->uniqueName();
    j["languageCode"] = entry->languageCode();
    return j;
}

std::string getInputMethods() {
    static std::string ret;
    nlohmann::json j;
    auto &imMgr = instance->inputMethodManager();
    auto group = imMgr.currentGroup();
    bool empty = true;
    for (const auto &im : group.inputMethodList()) {
        auto entry = imMgr.entry(im.name());
        if (!entry)
            continue;
        empty = false;
        j.push_back(jsonDescribeIm(entry));
    }
    if (empty) { // j is not treated array
        return "[]";
    }
    ret = j.dump();
    return ret.c_str();
}
