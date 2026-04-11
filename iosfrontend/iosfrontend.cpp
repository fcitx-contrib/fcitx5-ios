#include "iosfrontend.h"
#include "iosfrontend-swift.h"

namespace fcitx {

IosFrontend::IosFrontend(Instance *instance)
    : instance_(instance), focusGroup_("ios", instance->inputContextManager()) {
    createInputContext();
}

void IosFrontend::createInputContext() {
    ic_ = new IosInputContext(this, instance_->inputContextManager());
    ic_->setFocusGroup(&focusGroup_);
}

bool IosFrontend::keyEvent(const Key &key, bool isRelease) {
    KeyEvent event(ic_, key, isRelease);
    ic_->keyEvent(event);
    return event.accepted();
}

void IosFrontend::forwardKey(const std::string &key, const std::string &code) {
    SwiftFrontend::forwardKeyAsync(key, code);
}

void IosFrontend::focusIn() { ic_->focusIn(); }

void IosFrontend::focusOut() { ic_->focusOut(); }

void IosFrontend::resetInput() { ic_->reset(); }

IosInputContext::IosInputContext(IosFrontend *frontend,
                                 InputContextManager &inputContextManager)
    : InputContext(inputContextManager, ""), frontend_(frontend) {
    CapabilityFlags flags = CapabilityFlag::Preedit;
    setCapabilityFlags(flags);
    created();
}

IosInputContext::~IosInputContext() { destroy(); }

void IosInputContext::commitStringImpl(const std::string &text) {
    SwiftFrontend::commitStringAsync(text);
}

void IosInputContext::updatePreeditImpl() {
    auto preedit =
        frontend_->instance()->outputFilter(this, inputPanel().clientPreedit());
    SwiftFrontend::setPreeditAsync(preedit.toString(), preedit.cursor());
}
} // namespace fcitx

FCITX_ADDON_FACTORY_V2(iosfrontend, fcitx::IosFrontendFactory);
