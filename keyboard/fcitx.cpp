#include "../iosfrontend/iosfrontend.h"

#include "../common/common.h"
#include "../common/util.h"
#include "fcitx.h"

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

void focusOut() {
    return with_fcitx([] { frontend->focusOut(); });
}

bool processKey(const char *key) {
    return with_fcitx(
        [key] { return frontend->keyEvent(fcitx::Key{key}, false); });
}
