#include "iosfrontend.h"
#include "iosfrontend-swift.h"

#include <atomic>

namespace fcitx {
namespace {
std::atomic_size_t liveInputContextCount = 0;
}

IosFrontend::IosFrontend(Instance *instance)
    : instance_(instance), focusGroup_("ios", instance->inputContextManager()) {
}

IosInputContext *
IosFrontend::findInputContext(const std::string &program,
                              const std::string &documentIdentifier) const {
    auto iter = inputContexts_.find(program);
    if (iter == inputContexts_.end() ||
        iter->second->documentIdentifier() != documentIdentifier) {
        return nullptr;
    }
    return iter->second;
}

IosInputContext &
IosFrontend::ensureInputContext(const std::string &program,
                                const std::string &documentIdentifier) {
    auto iter = inputContexts_.find(program);
    if (iter != inputContexts_.end()) {
        if (iter->second->documentIdentifier() == documentIdentifier) {
            return *iter->second;
        }
        destroyInputContext(iter->second);
    }

    auto *ic = new IosInputContext(this, instance_->inputContextManager(),
                                   program, documentIdentifier);
    ic->setFocusGroup(&focusGroup_);
    inputContexts_[program] = ic;
    return *ic;
}

void IosFrontend::destroyInputContext(IosInputContext *ic) {
    if (ic->hasFocus()) {
        ic->focusOut();
        focusGroup_.setFocusedInputContext(nullptr);
    }
    inputContexts_.erase(ic->program());
    delete ic;
}

void IosFrontend::destroyInputContext(const std::string &program) {
    auto iter = inputContexts_.find(program);
    if (iter != inputContexts_.end()) {
        destroyInputContext(iter->second);
    }
}

bool IosFrontend::keyEvent(const std::string &program,
                           const std::string &documentIdentifier,
                           const Key &key, bool isRelease,
                           const std::string &text, unsigned int cursor,
                           unsigned int anchor, bool reset) {
    auto &ic = ensureInputContext(program, documentIdentifier);
    ic.focusIn();
    if (reset) {
        ic.reset();
    }
    ic.setSurroundingText(text, cursor, anchor);
    KeyEvent event(&ic, key, isRelease);
    ic.keyEvent(event);
    return event.accepted();
}

void IosFrontend::forwardKey(const std::string &program,
                             const std::string &documentIdentifier,
                             const std::string &key, const std::string &code) {
    SwiftFrontend::forwardKeyAsync(program, documentIdentifier, key, code);
}

void IosFrontend::focusIn(const std::string &program,
                          const std::string &documentIdentifier) {
    ensureInputContext(program, documentIdentifier).focusIn();
}

void IosFrontend::focusOut(const std::string &program,
                           const std::string &documentIdentifier) {
    if (auto *ic = findInputContext(program, documentIdentifier);
        ic && ic->hasFocus()) {
        ic->focusOut();
    }
}

void IosFrontend::resetInput(const std::string &program,
                             const std::string &documentIdentifier) {
    if (auto *ic = findInputContext(program, documentIdentifier)) {
        ic->reset();
    }
}

InputContext *IosFrontend::inputContext(const std::string &program,
                                        const std::string &documentIdentifier) {
    return findInputContext(program, documentIdentifier);
}

IosInputContext::IosInputContext(IosFrontend *frontend,
                                 InputContextManager &inputContextManager,
                                 const std::string &program,
                                 const std::string &documentIdentifier)
    : InputContext(inputContextManager, program), frontend_(frontend),
      documentIdentifier_(documentIdentifier) {
    CapabilityFlags flags = CapabilityFlag::Preedit;
    flags |= CapabilityFlag::SurroundingText;
    setCapabilityFlags(flags);
    created();
    auto count = ++liveInputContextCount;
    FCITX_INFO() << "Create IC program=" << program
                 << " document=" << documentIdentifier
                 << " liveInputContexts=" << count;
}

IosInputContext::~IosInputContext() {
    destroy();
    auto count = --liveInputContextCount;
    FCITX_INFO() << "Destroy IC program=" << program()
                 << " document=" << documentIdentifier_
                 << " liveInputContexts=" << count;
}

void IosInputContext::deleteSurroundingTextImpl(int offset, unsigned int size) {
    SwiftFrontend::deleteSurroundingTextAsync(program(), documentIdentifier_,
                                              offset, size);
}

void IosInputContext::commitStringImpl(const std::string &text) {
    SwiftFrontend::commitStringAsync(program(), documentIdentifier_, text);
}

void IosInputContext::updatePreeditImpl() {
    auto preedit =
        frontend_->instance()->outputFilter(this, inputPanel().clientPreedit());
    SwiftFrontend::setPreeditAsync(program(), documentIdentifier_,
                                   preedit.toString(), preedit.cursor());
}

void IosInputContext::setSurroundingText(const std::string &text,
                                         unsigned int cursor,
                                         unsigned int anchor) {
    surroundingText().setText(text, cursor, anchor);
    updateSurroundingText();
}
} // namespace fcitx

FCITX_ADDON_FACTORY_V2(iosfrontend, fcitx::IosFrontendFactory);
