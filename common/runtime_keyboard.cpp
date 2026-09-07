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

void focusIn(const char *p, const char *d) {
    std::string program = p, documentIdentifier = d;
    dispatcher->schedule(
        [=] { frontend->focusIn(program, documentIdentifier); });
}

void focusOut(const char *p, const char *d) {
    std::string program = p, documentIdentifier = d;
    dispatcher->schedule(
        [=] { frontend->focusOut(program, documentIdentifier); });
}

void destroyInputContext(const char *p) {
    std::string program = p;
    dispatcher->schedule([=] { frontend->destroyInputContext(program); });
}

void processKey(const char *p, const char *d, const char *k, const char *c,
                unsigned int modifiers, const char *text, unsigned int cursor,
                unsigned int anchor, bool reset) {
    std::string program = p, documentIdentifier = d, key = k, code = c,
                surroundingText = text;
    dispatcher->schedule([=] {
        bool accepted = frontend->keyEvent(
            program, documentIdentifier,
            fcitx::js_key_to_fcitx_key(
                key, code, modifiers | 1U << 29 /* KeyState::Virtual */),
            false, surroundingText, cursor, anchor, reset);
        if (!accepted) {
            frontend->forwardKey(program, documentIdentifier, key, code);
        }
    });
}

void resetInput(const char *p, const char *d) {
    std::string program = p, documentIdentifier = d;
    dispatcher->schedule(
        [=] { frontend->resetInput(program, documentIdentifier); });
}

void triggerUnicode(const char *p, const char *d) {
    std::string program = p, documentIdentifier = d;
    dispatcher->schedule([=] {
        auto *unicode = instance->addonManager().addon("unicode");
        if (!unicode) {
            return;
        }
        auto *ic = frontend->inputContext(program, documentIdentifier);
        if (!ic) {
            return;
        }
        unicode->call<fcitx::IUnicode::trigger>(ic);
    });
}

void triggerQuickPhrase(const char *p, const char *d) {
    std::string program = p, documentIdentifier = d;
    dispatcher->schedule([=] {
        auto *quickphrase = instance->addonManager().addon("quickphrase");
        if (!quickphrase) {
            return;
        }
        auto *ic = frontend->inputContext(program, documentIdentifier);
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
