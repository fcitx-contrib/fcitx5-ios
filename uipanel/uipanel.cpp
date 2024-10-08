#include <fcitx/inputpanel.h>

#include "uipanel.h"

namespace fcitx {

UIPanel::UIPanel(Instance *instance) : instance_(instance) {}

void UIPanel::showVirtualKeyboard() {}

void UIPanel::update(UserInterfaceComponent component,
                     InputContext *inputContext) {
    switch (component) {
    case UserInterfaceComponent::InputPanel: {
        const InputPanel &inputPanel = inputContext->inputPanel();
        int size = 0;
        if (const auto &list = inputPanel.candidateList()) {
            size = list->size();
            for (int i = 0; i < size; i++) {
                const auto &candidate = list->candidate(i);
                FCITX_INFO()
                    << instance_->outputFilter(inputContext, candidate.text())
                           .toString();
            }
        }
        break;
    }
    case UserInterfaceComponent::StatusArea:
        break;
    }
}

} // namespace fcitx
