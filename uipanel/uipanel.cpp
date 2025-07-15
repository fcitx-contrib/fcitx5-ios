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

UIPanel *ui;

UIPanel::UIPanel(Instance *instance) : instance_(instance) { ui = this; }

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
        auto auxUp = instance_->outputFilter(inputContext, inputPanel.auxUp())
                         .toString();
        auto preedit =
            instance_->outputFilter(inputContext, inputPanel.preedit())
                .toString();
        auto caret = inputPanel.preedit().cursor();
        int size = 0;
        auto candidates = swift::Array<swift::String>::init();
        if (const auto &list = inputPanel.candidateList()) {
            const auto &bulk = list->toBulk();
            if (bulk) {
                KeyboardUI::setCandidatesAsync(auxUp, preedit, caret,
                                               candidates);
                return expand();
            }
            size = list->size();
            for (int i = 0; i < size; i++) {
                const auto &candidate = list->candidate(i);
                candidates.append(
                    instance_->outputFilter(inputContext, candidate.text())
                        .toString());
            }
        }
        KeyboardUI::setCandidatesAsync(auxUp, preedit, caret, candidates);
        break;
    }
    case UserInterfaceComponent::StatusArea:
        updateStatusArea(inputContext);
        break;
    }
}

// Vertically 1.5 screens.
void UIPanel::expand() { scroll(0, 48); }

void UIPanel::scroll(int start, int count) {
    auto ic = instance_->mostRecentInputContext();
    const auto &list = ic->inputPanel().candidateList();
    if (!list) {
        return;
    }
    const auto &bulk = list->toBulk();
    if (!bulk) {
        return;
    }
    int size = bulk->totalSize();
    int end = size < 0 ? start + count : std::min(start + count, size);
    bool endReached = size == end;
    auto candidates = swift::Array<swift::String>::init();
    for (int i = start; i < end; ++i) {
        try {
            auto &candidate = bulk->candidateFromAll(i);
            candidates.append(
                instance_->outputFilter(ic, candidate.text()).toString());
        } catch (const std::invalid_argument &e) {
            // size == -1 but actual limit is reached
            endReached = true;
            break;
        }
    }
    KeyboardUI::scrollAsync(candidates, start == 0, endReached);
}

KeyboardUI::StatusAreaAction convertAction(Action *action, InputContext *ic) {
    auto children = swift::Array<KeyboardUI::StatusAreaAction>::init();
    if (auto *menu = action->menu()) {
        for (auto *subAction : menu->actions()) {
            children.append(convertAction(subAction, ic));
        }
    }
    return KeyboardUI::StatusAreaAction::init(
        action->id(), action->shortText(ic), action->icon(ic),
        action->isChecked(ic), action->isSeparator(), children);
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

static std::string serializeActions(ActionableCandidateList *actionableList,
                                    const CandidateWord &candidate) {
    if (actionableList->hasAction(candidate)) {
        auto j = nlohmann::json::array();
        for (const auto &action : actionableList->candidateActions(candidate)) {
            j.push_back({{"id", action.id()}, {"text", action.text()}});
        }
        return j.dump();
    }
    return "[]";
}

} // namespace fcitx

FCITX_ADDON_FACTORY_V2(uipanel, fcitx::UIPanelFactory);

void scroll(int start, int count) {
    with_fcitx([start, count] { fcitx::ui->scroll(start, count); });
}

std::string getCandidateActions(int index) {
    return with_fcitx([index]() -> std::string {
        auto ic = instance->mostRecentInputContext();
        const auto &list = ic->inputPanel().candidateList();
        if (!list)
            return "[]";
        auto *actionableList = list->toActionable();
        if (!actionableList) {
            return "[]";
        }
        const auto &bulk = list->toBulk();
        if (bulk) {
            try {
                auto &candidate = bulk->candidateFromAll(index);
                return serializeActions(actionableList, candidate);
            } catch (const std::invalid_argument &e) {
                FCITX_ERROR() << "action candidate index out of range";
            }
        } else {
            try {
                const auto &candidate = list->candidate(index);
                return serializeActions(actionableList, candidate);
            } catch (const std::invalid_argument &e) {
                FCITX_ERROR() << "action candidate index out of range";
            }
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
        const auto &bulk = list->toBulk();
        if (bulk) {
            try {
                const auto &candidate = bulk->candidateFromAll(index);
                if (actionableList->hasAction(candidate)) {
                    actionableList->triggerAction(candidate, id);
                }
            } catch (const std::invalid_argument &e) {
                FCITX_ERROR() << "action candidate index out of range";
            }
        } else {
            try {
                const auto &candidate = list->candidate(index);
                if (actionableList->hasAction(candidate)) {
                    actionableList->triggerAction(candidate, id);
                }
            } catch (const std::invalid_argument &e) {
                FCITX_ERROR() << "action candidate index out of range";
            }
        }
    });
}

void selectCandidate(int index) {
    with_fcitx([index] {
        auto ic = instance->mostRecentInputContext();
        const auto &list = ic->inputPanel().candidateList();
        if (!list)
            return;
        const auto &bulk = list->toBulk();
        // Engine is responsible for updating UI
        if (bulk) {
            try {
                bulk->candidateFromAll(index).select(ic);
            } catch (const std::invalid_argument &e) {
                FCITX_ERROR() << "select candidate index out of range";
            }
        } else {
            try {
                list->candidate(index).select(ic);
            } catch (const std::invalid_argument &e) {
                FCITX_ERROR() << "select candidate index out of range";
            }
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
