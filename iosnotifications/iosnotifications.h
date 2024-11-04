#pragma once

#include <fcitx/addonfactory.h>
#include <fcitx/addoninstance.h>
#include <fcitx/addonmanager.h>
#include <fcitx/instance.h>
#include <notifications_public.h>

namespace fcitx {
class Notifications final : public AddonInstance {
  public:
    Notifications(Instance *instance);
    ~Notifications() = default;
    uint32_t sendNotification(const std::string &appName, uint32_t replaceId,
                              const std::string &appIcon,
                              const std::string &summary,
                              const std::string &body,
                              const std::vector<std::string> &actions,
                              int32_t timeout,
                              NotificationActionCallback actionCallback,
                              NotificationClosedCallback closedCallback);
    void showTip(const std::string &tipId, const std::string &appName,
                 const std::string &appIcon, const std::string &summary,
                 const std::string &body, int32_t timeout);

    void closeNotification(uint64_t internalId);

  private:
    FCITX_ADDON_EXPORT_FUNCTION(Notifications, sendNotification);
    FCITX_ADDON_EXPORT_FUNCTION(Notifications, showTip);
    FCITX_ADDON_EXPORT_FUNCTION(Notifications, closeNotification);
};

class IosNotificationsFactory : public AddonFactory {
    AddonInstance *create(AddonManager *manager) override {
        return new Notifications(manager->instance());
    }
};
} // namespace fcitx
