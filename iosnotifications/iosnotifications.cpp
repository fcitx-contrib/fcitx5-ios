#include "iosnotifications.h"
#include "notify-swift.h"

namespace fcitx {
Notifications::Notifications(Instance *instance) {}

uint32_t Notifications::sendNotification(
    const std::string &appName, uint32_t replaceId, const std::string &appIcon,
    const std::string &summary, const std::string &body,
    const std::vector<std::string> &actions, int32_t timeout,
    NotificationActionCallback actionCallback,
    NotificationClosedCallback closedCallback) {

    FCITX_INFO() << "sendNotification " << body;
    return 0;
}

void Notifications::showTip(const std::string &tipId,
                            const std::string &appName,
                            const std::string &appIcon,
                            const std::string &summary, const std::string &body,
                            int32_t timeout) {
    // For f5i appIcon is replaced with running/success/error to show icons for
    // different message type.
    NotifySwift::showTip(appIcon, body, timeout);
}

void Notifications::closeNotification(uint64_t internalId) {
    FCITX_INFO() << "closeNotification " << internalId;
}
} // namespace fcitx

FCITX_ADDON_FACTORY_V2(notifications, fcitx::IosNotificationsFactory);
