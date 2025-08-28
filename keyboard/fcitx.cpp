#include "../iosfrontend/iosfrontend.h"

#include "../common/common.h"
#include "../common/util.h"
#include "fcitx.h"
#include "keycode.h"

#include <fcitx/inputmethodmanager.h>

fcitx::IosFrontend *frontend;

void startFcitx(const char *appBundlePath, const char *xdgDataDirs,
                const char *appGroupPath) {
    if (instance) {
        return;
    }
    setupFcitx(appBundlePath, xdgDataDirs, appGroupPath, false);
    auto &addonMgr = instance->addonManager();
    frontend =
        dynamic_cast<fcitx::IosFrontend *>(addonMgr.addon("iosfrontend"));
    return;
}

void focusIn(id client) {
    return dispatcher->schedule([client] { frontend->focusIn(client); });
}

void focusOut(id client) {
    return dispatcher->schedule([client] { frontend->focusOut(client); });
}

void processKey(const char *k, const char *c) {
    std::string key = k, code = c;
    dispatcher->schedule([=] {
        bool accepted =
            frontend->keyEvent(fcitx::js_key_to_fcitx_key(
                                   key, code, 1 << 29 /* KeyState::Virtual */),
                               false);
        if (!accepted) {
            frontend->forwardKey(key, code);
        }
    });
}

void resetInput() {
    dispatcher->schedule([] { frontend->resetInput(); });
}

void reload() {
    dispatcher->schedule([] {
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

void toggle() {
    dispatcher->schedule([] { instance->toggle(); });
}

void setCurrentInputMethod(const char *im) {
    std::string inputMethod = im;
    dispatcher->schedule([=] { instance->setCurrentInputMethod(inputMethod); });
}
