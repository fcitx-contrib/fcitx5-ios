#pragma once

#include <fcitx-config/configuration.h>
#include <fcitx/addonfactory.h>
#include <fcitx/addoninstance.h>
#include <fcitx/addonmanager.h>
#include <fcitx/focusgroup.h>
#include <fcitx/instance.h>

namespace fcitx {

class IosInputContext;

class IosFrontend : public AddonInstance {
  public:
    IosFrontend(Instance *instance);
    Instance *instance() { return instance_; }

    void reloadConfig() override {}
    void save() override {}
    const Configuration *getConfig() const override { return nullptr; }
    void setConfig(const RawConfig &config) override {}

    void createInputContext();
    bool keyEvent(const Key &key, bool isRelease);
    void focusIn();
    void focusOut();

  private:
    Instance *instance_;
    FocusGroup focusGroup_;
    IosInputContext *ic_;
};

class IosFrontendFactory : public AddonFactory {
  public:
    AddonInstance *create(AddonManager *manager) override {
        return new IosFrontend(manager->instance());
    }
};

class IosInputContext : public InputContext {
  public:
    IosInputContext(IosFrontend *frontend,
                     InputContextManager &inputContextManager);
    ~IosInputContext();

    const char *frontend() const override { return "ios"; }
    void commitStringImpl(const std::string &text) override;
    void deleteSurroundingTextImpl(int offset, unsigned int size) override {}
    void forwardKeyImpl(const ForwardKeyEvent &key) override {}
    void updatePreeditImpl() override;

  private:
    IosFrontend *frontend_;
};
} // namespace fcitx
