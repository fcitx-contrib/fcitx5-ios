#include <fcitx/action.h>
#include <fcitx/inputpanel.h>
#include <fcitx/menu.h>
#include <fcitx/statusarea.h>
#include <fcitx/userinterfacemanager.h>
#include <nlohmann/json.hpp>

#include "../common/util.h"
#include "../iosfrontend/iosfrontend.h"
#include "../keyboard/fcitx.h"
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
        updateStatusArea(inputContext);
        break;
    }
}

KeyboardUI::StatusAreaAction convertAction(Action *action, InputContext *ic) {
    auto children = swift::Array<KeyboardUI::StatusAreaAction>::init();
    if (auto *menu = action->menu()) {
        for (auto *subAction : menu->actions()) {
            children.append(convertAction(subAction, ic));
        }
    }
    return KeyboardUI::StatusAreaAction::init(
        action->id(), action->shortText(ic), action->isChecked(ic),
        action->isSeparator(), children);
}

void UIPanel::updateStatusArea(InputContext *ic) {
    auto actions = swift::Array<KeyboardUI::StatusAreaAction>::init();
    auto &statusArea = ic->statusArea();
    for (auto *action : statusArea.allActions()) {
        if (!action->id()) {
            // Not registered with UI manager.
            continue;
        }
        actions.append(convertAction(action, ic));
    }
    auto im = instance_->currentInputMethod();
    KeyboardUI::setStatusAreaAsync(actions, im.c_str());
}

} // namespace fcitx

FCITX_ADDON_FACTORY_V2(uipanel, fcitx::UIPanelFactory);

std::string getCandidateActions(int index) {
    return with_fcitx([index] -> std::string {
        auto ic = instance->mostRecentInputContext();
        const auto &list = ic->inputPanel().candidateList();
        if (!list)
            return "[]";
        auto *actionableList = list->toActionable();
        if (!actionableList) {
            return "[]";
        }
        try {
            const auto &candidate = list->candidate(index);
            if (actionableList->hasAction(candidate)) {
                auto j = nlohmann::json::array();
                for (const auto &action :
                     actionableList->candidateActions(candidate)) {
                    j.push_back({{"id", action.id()}, {"text", action.text()}});
                }
                return j.dump();
            }
        } catch (const std::invalid_argument &e) {
            FCITX_ERROR() << "action candidate index out of range";
        }
        return "[]";
    });
}

void activateCandidateAction(int index, int id) {
    dispatcher->schedule([=] {
        auto ic = instance->mostRecentInputContext();
        const auto &list = ic->inputPanel().candidateList();
        if (!list)
            return;
        auto *actionableList = list->toActionable();
        if (!actionableList)
            return;
        try {
            const auto &candidate = list->candidate(index);
            if (actionableList->hasAction(candidate)) {
                actionableList->triggerAction(candidate, id);
            }
        } catch (const std::invalid_argument &e) {
            FCITX_ERROR() << "action candidate index out of range";
        }
    });
}

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

void activateStatusAreaAction(int id) {
    with_fcitx([id] {
        if (auto *ic = instance->mostRecentInputContext()) {
            auto *action =
                instance->userInterfaceManager().lookupActionById(id);
            action->activate(ic);
        }
    });
}
