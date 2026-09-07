#pragma once

#include <fcitx/addonfactory.h>
#include <fcitx/addoninstance.h>
#include <fcitx/addonmanager.h>
#include <fcitx/candidatelist.h>
#include <fcitx/instance.h>

namespace fcitx {

class IosInputContext;

class UIPanel final : public VirtualKeyboardUserInterface {
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
    bool isVirtualKeyboardVisible() const override { return true; }
    void showVirtualKeyboard() override {}
    void hideVirtualKeyboard() override {}
    void scroll(const std::string &program,
                const std::string &documentIdentifier, int start, int count);
    void page(bool next);

  private:
    Instance *instance_;
    std::unique_ptr<HandlerTableEntry<EventHandler>> eventHandler_;

    void updateStatusArea(IosInputContext &ic);
    void expand(IosInputContext &ic, const std::string &auxUp,
                const std::string &preedit, int caret, bool hasClientPreedit,
                std::shared_ptr<CandidateList> list);
};

class UIPanelFactory : public AddonFactory {
  public:
    AddonInstance *create(AddonManager *manager) override {
        return new UIPanel(manager->instance());
    }
};

} // namespace fcitx
