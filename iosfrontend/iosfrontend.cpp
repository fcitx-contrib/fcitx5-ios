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
    SwiftFrontend::forwardKeyAsync(ic_->getClient(), key, code);
}

void IosFrontend::focusIn(id client) {
    ic_->setClient(client);
    ic_->focusIn();
}

void IosFrontend::focusOut(id client) {
    // Old viewWillDisappear may be called after new viewWillAppear (if
    // switching apps) so don't always reset.
    if (client != ic_->getClient()) {
        return;
    }
    ic_->focusOut();
    // Extracting client from nil crashes on Swift, so it has to be put after
    // ic_->focusOut, although commit on focus out doesn't work on iOS (even if
    // commit inside viewWillDisappear)
    ic_->setClient(nil);
}

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
    SwiftFrontend::commitStringAsync(client_, text);
}

void IosInputContext::updatePreeditImpl() {
    auto preedit =
        frontend_->instance()->outputFilter(this, inputPanel().clientPreedit());
    SwiftFrontend::setPreeditAsync(client_, preedit.toString(),
                                   preedit.cursor());
}
} // namespace fcitx

FCITX_ADDON_FACTORY_V2(iosfrontend, fcitx::IosFrontendFactory);
