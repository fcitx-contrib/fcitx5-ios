#pragma once

#include <fcitx-config/configuration.h>
#include <fcitx-config/iniparser.h>
#include <fcitx-utils/i18n.h>
#include <fcitx/addonfactory.h>
#include <fcitx/addoninstance.h>
#include <fcitx/addonmanager.h>
#include <fcitx/focusgroup.h>
#include <fcitx/instance.h>

#include <string>
#include <unordered_map>

namespace fcitx {

class IosInputContext;

FCITX_CONFIGURATION(IosFrontendConfig,
                    Option<bool> removeTrackingParameters{
                        this, "RemoveTrackingParameters",
                        _("Remove tracking parameters"), true};);

class IosFrontend : public AddonInstance {
  public:
    IosFrontend(Instance *instance);
    Instance *instance() { return instance_; }

    void reloadConfig() override;
    void save() override;
    const Configuration *getConfig() const override { return &config_; }
    void setConfig(const RawConfig &config) override;

    std::string filterClipboardEntry(std::string text) const;

    bool keyEvent(const std::string &program,
                  const std::string &documentIdentifier, const Key &key,
                  bool isRelease, const std::string &text, unsigned int cursor,
                  unsigned int anchor, bool reset);
    void forwardKey(const std::string &program,
                    const std::string &documentIdentifier,
                    const std::string &key, const std::string &code);
    void focusIn(const std::string &program,
                 const std::string &documentIdentifier);
    void focusOut(const std::string &program,
                  const std::string &documentIdentifier);
    void destroyInputContext(const std::string &program);
    void resetInput(const std::string &program,
                    const std::string &documentIdentifier);
    InputContext *inputContext(const std::string &program,
                               const std::string &documentIdentifier);

  private:
    Instance *instance_;
    IosFrontendConfig config_;
    FocusGroup focusGroup_;
    std::unordered_map<std::string, IosInputContext *> inputContexts_;

    IosInputContext *
    findInputContext(const std::string &program,
                     const std::string &documentIdentifier) const;
    IosInputContext &ensureInputContext(const std::string &program,
                                        const std::string &documentIdentifier);
    void destroyInputContext(IosInputContext *ic);

    static const inline std::string ConfPath = "conf/iosfrontend.conf";
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
                    InputContextManager &inputContextManager,
                    const std::string &program,
                    const std::string &documentIdentifier);
    ~IosInputContext();

    const char *frontend() const override { return "ios"; }
    void commitStringImpl(const std::string &text) override;
    void deleteSurroundingTextImpl(int offset, unsigned int size) override;
    void forwardKeyImpl(const ForwardKeyEvent &key) override {}
    void updatePreeditImpl() override;
    void setSurroundingText(const std::string &text, unsigned int cursor,
                            unsigned int anchor);
    const std::string &documentIdentifier() const {
        return documentIdentifier_;
    }

  private:
    IosFrontend *frontend_;
    std::string documentIdentifier_;
};
} // namespace fcitx
