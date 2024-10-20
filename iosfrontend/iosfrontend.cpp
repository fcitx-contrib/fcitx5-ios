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

void IosFrontend::focusIn(id client) {
    ic_->setClient(client);
    ic_->focusIn();
}

void IosFrontend::focusOut() {
    ic_->focusOut();
    // Extracting client from nil crashes on Swift, so it has to be put after
    // ic_->focusOut, although commit on focus out doesn't work on iOS (even if
    // commit inside viewWillDisappear)
    ic_->setClient(nil);
}

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
    FCITX_ERROR() << preedit.toString().c_str() << preedit.cursor();
}
} // namespace fcitx
