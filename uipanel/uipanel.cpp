#include <fcitx/inputpanel.h>

#include "../iosfrontend/iosfrontend.h"
#include "../keyboard/fcitx.h"
#include "../keyboard/util.h"
#include "keyboardui-swift.h"
#include "uipanel-public.h"
#include "uipanel.h"

namespace fcitx {

UIPanel::UIPanel(Instance *instance) : instance_(instance) {}

void UIPanel::showVirtualKeyboard() {
    if (auto ic = dynamic_cast<IosInputContext *>(
            instance_->mostRecentInputContext())) {
        KeyboardUI::showKeyboardAsync(ic->getClient());
    }
}

void UIPanel::update(UserInterfaceComponent component,
                     InputContext *inputContext) {
    switch (component) {
    case UserInterfaceComponent::InputPanel: {
        const InputPanel &inputPanel = inputContext->inputPanel();
        int size = 0;
        auto candidates = swift::Array<swift::String>::init();
        if (const auto &list = inputPanel.candidateList()) {
            size = list->size();
            for (int i = 0; i < size; i++) {
                const auto &candidate = list->candidate(i);
                candidates.append(
                    instance_->outputFilter(inputContext, candidate.text())
                        .toString());
            }
        }
        KeyboardUI::setCandidatesAsync(candidates);
        break;
    }
    case UserInterfaceComponent::StatusArea:
        break;
    }
}

} // namespace fcitx

void selectCandidate(int index) {
    with_fcitx([index] {
        auto ic = instance->mostRecentInputContext();
        const auto &list = ic->inputPanel().candidateList();
        if (!list)
            return;
        try {
            // Engine is responsible for updating UI
            list->candidate(index).select(ic);
        } catch (const std::invalid_argument &e) {
            FCITX_ERROR() << "select candidate index out of range";
        }
    });
}
