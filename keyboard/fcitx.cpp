#include "../iosfrontend/iosfrontend.h"

#include "../common/common.h"
#include "../common/util.h"
#include "fcitx.h"

#include <fcitx/inputmethodmanager.h>

fcitx::IosFrontend *frontend;

void startFcitx(const char *bundlePath, const char *appGroupPath) {
    if (instance) {
        return;
    }
    setupFcitx(bundlePath, appGroupPath, false);
    auto &addonMgr = instance->addonManager();
    frontend =
        dynamic_cast<fcitx::IosFrontend *>(addonMgr.addon("iosfrontend"));
    return;
}

void focusIn(id client) {
    return with_fcitx([client] { frontend->focusIn(client); });
}

void focusOut(id client) {
    return with_fcitx([client] { frontend->focusOut(client); });
}

bool processKey(const char *key) {
    return with_fcitx(
        [key] { return frontend->keyEvent(fcitx::Key{key}, false); });
}

void reload() {
    with_fcitx([] {
        instance->reloadConfig();
        instance->refresh();
        auto &addonManager = instance->addonManager();
        for (const auto category :
             {fcitx::AddonCategory::InputMethod, fcitx::AddonCategory::Frontend,
              fcitx::AddonCategory::Loader, fcitx::AddonCategory::Module,
              fcitx::AddonCategory::UI}) {
            const auto names = addonManager.addonNames(category);
            for (const auto &name : names) {
                instance->reloadAddonConfig(name);
            }
        }
        // Changing wbx's config needs this to reload table/wbx.conf.
        instance->inputMethodManager().reset();
        instance->inputMethodManager().load();
    });
}
