#include <fcitx/action.h>
#include <fcitx/inputpanel.h>
#include <fcitx/menu.h>
#include <fcitx/statusarea.h>
#include <fcitx/userinterfacemanager.h>
#include <nlohmann/json.hpp>

#include "../common/util.h"
#include "../iosfrontend/iosfrontend.h"
#include "keyboardui-swift.h"
#include "uipanel-public.h"
#include "uipanel.h"

namespace fcitx {

UIPanel *ui;

UIPanel::UIPanel(Instance *instance) : instance_(instance) {
    ui = this;
    eventHandler_ = instance_->watchEvent(
        EventType::InputContextInputMethodActivated, EventWatcherPhase::Default,
        [this](Event &event) {
            auto &icEvent = static_cast<InputContextEvent &>(event);
            auto *ic = dynamic_cast<IosInputContext *>(icEvent.inputContext());
            if (!ic) {
                return;
            }
            auto im = instance_->currentInputMethod();
            KeyboardUI::setCurrentInputMethodAsync(
                ic->program(), ic->documentIdentifier(), im);
        });
}

void UIPanel::update(UserInterfaceComponent component,
                     InputContext *inputContext) {
    auto *ic = dynamic_cast<IosInputContext *>(inputContext);
    if (!ic) {
        return;
    }
    switch (component) {
    case UserInterfaceComponent::InputPanel: {
        const InputPanel &inputPanel = inputContext->inputPanel();
        std::string auxUp, preedit;
        if (!inputPanel.empty()) {
            auxUp = instance_->outputFilter(inputContext, inputPanel.auxUp())
                        .toString();
            preedit =
                instance_->outputFilter(inputContext, inputPanel.preedit())
                    .toString();
        } else if (!inputPanel.overlayMessage().empty()) {
            auxUp = inputPanel.overlayMessage().toString();
        }
        auto caret = inputPanel.preedit().cursor();
        bool hasClientPreedit = !inputPanel.clientPreedit().empty();
        int size = 0;
        auto candidates = swift::Array<swift::String>::init();
        int highlighted = -1;
        if (const auto &list = inputPanel.candidateList()) {
            const auto &bulk = list->toBulk();
            if (bulk) {
                return expand(*ic, auxUp, preedit, caret, hasClientPreedit,
                              list);
            }
            size = list->size();
            for (int i = 0; i < size; i++) {
                const auto &candidate = list->candidate(i);
                candidates.append(
                    instance_->outputFilter(inputContext, candidate.text())
                        .toString());
            }
            highlighted = list->cursorIndex();
        }
        bool hasPrev = false, hasNext = false;
        if (const auto &list = inputPanel.candidateList()) {
            if (auto *pageable = list->toPageable()) {
                hasPrev = pageable->hasPrev();
                hasNext = pageable->hasNext();
            }
        }
        KeyboardUI::setCandidatesAsync(ic->program(), ic->documentIdentifier(),
                                       auxUp, preedit, caret, candidates,
                                       highlighted, false, hasClientPreedit,
                                       "[]", hasPrev, hasNext, false);
        break;
    }
    case UserInterfaceComponent::StatusArea:
        updateStatusArea(*ic);
        break;
    }
}

swift::Array<swift::String> getBulkCandidates(Instance *instance,
                                              IosInputContext &ic, int start,
                                              int count,
                                              bool *pEndReached = nullptr) {
    auto candidates = swift::Array<swift::String>::init();
    const auto &list = ic.inputPanel().candidateList();
    if (!list) {
        return candidates;
    }
    const auto &bulk = list->toBulk();
    if (!bulk) {
        return candidates;
    }
    int size = bulk->totalSize();
    int end = size < 0 ? start + count : std::min(start + count, size);
    bool endReached = size == end;

    for (int i = start; i < end; ++i) {
        try {
            auto &candidate = bulk->candidateFromAll(i);
            candidates.append(
                instance->outputFilter(&ic, candidate.text()).toString());
        } catch (const std::invalid_argument &e) {
            // size == -1 but actual limit is reached
            endReached = true;
            break;
        }
    }
    if (pEndReached) {
        *pEndReached = endReached;
    }
    return candidates;
}

static void pushAction(nlohmann::json &j, const CandidateAction &action) {
    j.push_back({{"id", action.id()},
                 {"text", action.text()},
                 {"checked", action.isChecked()},
                 {"checkable", action.isCheckable()},
                 {"separator", action.isSeparator()}});
}

static std::string serializeTabActions(TabbedCandidateList *tabbedList) {
    auto j = nlohmann::json::array();
    if (tabbedList) {
        for (const auto &action : tabbedList->tabActions()) {
            pushAction(j, action);
        }
    }
    return j.dump();
}

void UIPanel::expand(IosInputContext &ic, const std::string &auxUp,
                     const std::string &preedit, int caret,
                     bool hasClientPreedit,
                     std::shared_ptr<CandidateList> list) {
    bool endReached = false;
    auto candidates = getBulkCandidates(instance_, ic, 0, 72,
                                        &endReached); // Vertically 2 screens.
    auto tabActions = serializeTabActions(list->toTabbed());
    KeyboardUI::setCandidatesAsync(ic.program(), ic.documentIdentifier(), auxUp,
                                   preedit, caret, candidates, 0, true,
                                   hasClientPreedit, tabActions, false, false,
                                   endReached);
}

void UIPanel::scroll(const std::string &program,
                     const std::string &documentIdentifier, int start,
                     int count) {
    auto *frontend = dynamic_cast<IosFrontend *>(
        instance_->addonManager().addon("iosfrontend"));
    if (!frontend) {
        return;
    }
    auto *ic = dynamic_cast<IosInputContext *>(
        frontend->inputContext(program, documentIdentifier));
    if (!ic) {
        return;
    }
    bool endReached = false;
    auto candidates =
        getBulkCandidates(instance_, *ic, start, count, &endReached);
    KeyboardUI::scrollAsync(ic->program(), ic->documentIdentifier(), candidates,
                            endReached);
}

void UIPanel::page(bool next) {
    auto ic = instance_->mostRecentInputContext();
    const auto &list = ic->inputPanel().candidateList();
    if (!list)
        return;
    auto *pageableList = list->toPageable();
    if (!pageableList)
        return;
    next ? pageableList->next() : pageableList->prev();
    // UI is responsible for updating UI
    ic->updateUserInterface(UserInterfaceComponent::InputPanel);
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

void UIPanel::updateStatusArea(IosInputContext &ic) {
    auto actions = swift::Array<KeyboardUI::StatusAreaAction>::init();
    auto &statusArea = ic.statusArea();
    for (auto *action : statusArea.allActions()) {
        if (!action->id()) {
            // Not registered with UI manager.
            continue;
        }
        actions.append(convertAction(action, &ic));
    }
    KeyboardUI::setStatusAreaAsync(ic.program(), ic.documentIdentifier(),
                                   actions);
}

} // namespace fcitx

FCITX_ADDON_FACTORY_V2(uipanel, fcitx::UIPanelFactory);

void scroll(const char *p, const char *d, int start, int count) {
    std::string program = p, documentIdentifier = d;
    dispatcher->schedule(
        [=] { fcitx::ui->scroll(program, documentIdentifier, start, count); });
}

void page(bool next) {
    dispatcher->schedule([next] { fcitx::ui->page(next); });
}

std::string getCandidateActions(int index) {
    return with_fcitx([index]() -> std::string {
        auto j = nlohmann::json::array();
        auto ic = instance->mostRecentInputContext();
        const auto &list = ic->inputPanel().candidateList();
        do {
            if (!list) {
                break;
            }
            auto *actionableList = list->toActionable();
            if (!actionableList) {
                break;
            }
            const auto &bulk = list->toBulk();
            try {
                auto &candidate = bulk ? bulk->candidateFromAll(index)
                                       : list->candidate(index);
                if (actionableList->hasAction(candidate)) {
                    for (const auto &action :
                         actionableList->candidateActions(candidate)) {
                        pushAction(j, action);
                    }
                }
            } catch (const std::invalid_argument &e) {
                FCITX_ERROR() << "action candidate index out of range";
            }
        } while (0);
        return j.dump();
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
        try {
            const auto &candidate =
                bulk ? bulk->candidateFromAll(index) : list->candidate(index);
            if (actionableList->hasAction(candidate)) {
                actionableList->triggerAction(candidate, id);
            }
        } catch (const std::invalid_argument &e) {
            FCITX_ERROR() << "action candidate index out of range";
        }
    });
}

void activateCandidateTabAction(int id) {
    dispatcher->schedule([id] {
        auto ic = instance->mostRecentInputContext();
        const auto &list = ic->inputPanel().candidateList();
        if (!list) {
            return;
        }
        auto *tabbedList = list->toTabbed();
        if (!tabbedList) {
            return;
        }
        tabbedList->triggerTabAction(id);
    });
}

void selectCandidate(int index) {
    dispatcher->schedule([index] {
        auto ic = instance->mostRecentInputContext();
        const auto &list = ic->inputPanel().candidateList();
        if (!list)
            return;
        const auto &bulk = list->toBulk();
        try {
            const auto &candidate =
                bulk ? bulk->candidateFromAll(index) : list->candidate(index);
            // Engine is responsible for updating UI
            candidate.select(ic);
        } catch (const std::invalid_argument &e) {
            FCITX_ERROR() << "select candidate index out of range";
        }
    });
}

void activateStatusAreaAction(int id) {
    dispatcher->schedule([id] {
        if (auto *ic = instance->mostRecentInputContext()) {
            auto *action =
                instance->userInterfaceManager().lookupActionById(id);
            action->activate(ic);
        }
    });
}
