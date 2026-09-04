#include "common.h"
#include "runtime-api.h"
#include "util.h"

#include "../iosfrontend/iosfrontend.h"
#include "keycode.h"

#include <fcitx/inputmethodmanager.h>
#include <quickphrase_public.h>
#include <unicode_public.h>

namespace {
fcitx::IosFrontend *frontend;

void updateSurroundingText(const std::string &text, unsigned int cursor,
                           unsigned int anchor, bool reset) {
    if (reset) {
        frontend->resetInput();
    }
    frontend->setSurroundingText(text, cursor, anchor);
}
} // namespace

void startKeyboardFcitx(const char *appBundlePath, const char *xdgDataDirs,
                        const char *appGroupPath) {
    if (instance) {
        return;
    }
    setupFcitx(appBundlePath, xdgDataDirs, appGroupPath, false);
    auto &addonMgr = instance->addonManager();
    frontend =
        dynamic_cast<fcitx::IosFrontend *>(addonMgr.addon("iosfrontend"));
}

void focusIn() {
    dispatcher->schedule([] { frontend->focusIn(); });
}

void focusOut() {
    dispatcher->schedule([] { frontend->focusOut(); });
}

void processKey(const char *k, const char *c, const char *text,
                unsigned int cursor, unsigned int anchor, bool reset) {
    std::string key = k, code = c, surroundingText = text;
    dispatcher->schedule([=] {
        updateSurroundingText(surroundingText, cursor, anchor, reset);
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

void triggerUnicode() {
    dispatcher->schedule([] {
        auto *unicode = instance->addonManager().addon("unicode");
        if (!unicode) {
            return;
        }
        auto *ic = instance->mostRecentInputContext();
        if (!ic) {
            return;
        }
        unicode->call<fcitx::IUnicode::trigger>(ic);
    });
}

void triggerQuickPhrase() {
    dispatcher->schedule([] {
        auto *quickphrase = instance->addonManager().addon("quickphrase");
        if (!quickphrase) {
            return;
        }
        auto *ic = instance->mostRecentInputContext();
        if (!ic) {
            return;
        }
        quickphrase->call<fcitx::IQuickPhrase::trigger>(ic, "", "", "", "",
                                                        fcitx::Key());
    });
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
