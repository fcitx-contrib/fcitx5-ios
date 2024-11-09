#include "common-public.h"
#include "common.h"
#include "util.h"
#include <fcitx/inputmethodmanager.h>

nlohmann::json jsonDescribeIm(const fcitx::InputMethodEntry *entry) {
    nlohmann::json j;
    j["name"] = entry->uniqueName();
    j["displayName"] = entry->nativeName() != "" ? entry->nativeName()
                       : entry->name() != ""     ? entry->name()
                                                 : entry->uniqueName();
    j["languageCode"] = entry->languageCode();
    return j;
}

std::string getInputMethods() {
    return with_fcitx([] -> std::string {
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
        return j.dump();
    });
}
