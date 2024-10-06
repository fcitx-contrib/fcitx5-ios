#pragma once

#include <fcitx/addonfactory.h>
#include <fcitx/addoninstance.h>
#include <fcitx/addonmanager.h>
#include <fcitx/instance.h>

namespace fcitx {

class UIPanel final : public UserInterface {
  public:
    UIPanel(Instance *);
    virtual ~UIPanel() = default;

    void reloadConfig() override {}
    const Configuration *getConfig() const override { return nullptr; }
    void setConfig(const RawConfig &config) override {}
    void setSubConfig(const std::string &path,
                      const RawConfig &config) override {}

    Instance *instance() { return instance_; }

    bool available() override { return true; }
    void suspend() override {}
    void resume() override {}
    void update(UserInterfaceComponent component,
                InputContext *inputContext) override;

  private:
    Instance *instance_;
};

class UIPanelFactory : public AddonFactory {
  public:
    AddonInstance *create(AddonManager *manager) override {
        return new UIPanel(manager->instance());
    }
};

} // namespace fcitx
