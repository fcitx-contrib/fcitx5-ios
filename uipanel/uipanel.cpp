#include <fcitx/action.h>
#include <fcitx/inputcontextmanager.h>
#include <fcitx/inputpanel.h>
#include <fcitx/menu.h>
#include <fcitx/statusarea.h>
#include <fcitx/userinterfacemanager.h>
#include <nlohmann/json.hpp>

#include "../common/util.h"
#include "keyboardui-swift.h"
#include "uipanel-public.h"
#include "uipanel.h"

namespace fcitx {

namespace {

constexpr char hexDigits[] = "0123456789abcdef";

std::string inputContextToken(const InputContext &inputContext) {
    std::string result;
    result.reserve(inputContext.uuid().size() * 2);
    for (auto byte : inputContext.uuid()) {
        result.push_back(hexDigits[byte >> 4]);
        result.push_back(hexDigits[byte & 0xf]);
    }
    return result;
}

int hexValue(char value) {
    if (value >= '0' && value <= '9') {
        return value - '0';
    }
    if (value >= 'a' && value <= 'f') {
        return value - 'a' + 10;
    }
    if (value >= 'A' && value <= 'F') {
        return value - 'A' + 10;
    }
    return -1;
}

InputContext *findInputContext(Instance *instance, std::string_view token) {
    ICUUID uuid;
    if (token.size() != uuid.size() * 2) {
        return nullptr;
    }
    for (size_t i = 0; i < uuid.size(); ++i) {
        int high = hexValue(token[i * 2]);
        int low = hexValue(token[i * 2 + 1]);
        if (high < 0 || low < 0) {
            return nullptr;
        }
        uuid[i] = static_cast<uint8_t>((high << 4) | low);
    }
    return instance->inputContextManager().findByUUID(uuid);
}

} // namespace

UIPanel *ui;

UIPanel::UIPanel(Instance *instance) : instance_(instance) {
    ui = this;
    eventHandler_ = instance_->watchEvent(
        EventType::InputContextInputMethodActivated, EventWatcherPhase::Default,
        [this](Event &event) {
            auto &icEvent = static_cast<InputContextEvent &>(event);
            auto *ic = icEvent.inputContext();
            if (!ic) {
                return;
            }
            auto im = instance_->currentInputMethod();
            KeyboardUI::setCurrentInputMethodAsync(ic->program(),
                                                   inputContextToken(*ic), im);
        });
}

void UIPanel::update(UserInterfaceComponent component,
                     InputContext *inputContext) {
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
                return expand(*inputContext, auxUp, preedit, caret,
                              hasClientPreedit, list);
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
        KeyboardUI::setCandidatesAsync(
            inputContext->program(), inputContextToken(*inputContext), auxUp,
            preedit, caret, candidates, highlighted, false, hasClientPreedit,
            "[]", hasPrev, hasNext, false);
        break;
    }
    case UserInterfaceComponent::StatusArea:
        updateStatusArea(*inputContext);
        break;
    }
}

swift::Array<swift::String> getBulkCandidates(Instance *instance,
                                              InputContext &ic, int start,
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

void UIPanel::expand(InputContext &ic, const std::string &auxUp,
                     const std::string &preedit, int caret,
                     bool hasClientPreedit,
                     std::shared_ptr<CandidateList> list) {
    bool endReached = false;
    auto candidates = getBulkCandidates(instance_, ic, 0, 72,
                                        &endReached); // Vertically 2 screens.
    auto tabActions = serializeTabActions(list->toTabbed());
    KeyboardUI::setCandidatesAsync(
        ic.program(), inputContextToken(ic), auxUp, preedit, caret, candidates,
        0, true, hasClientPreedit, tabActions, false, false, endReached);
}

void UIPanel::scroll(const std::string &inputContext, int start, int count) {
    auto *ic = findInputContext(instance_, inputContext);
    if (!ic) {
        return;
    }
    bool endReached = false;
    auto candidates =
        getBulkCandidates(instance_, *ic, start, count, &endReached);
    KeyboardUI::scrollAsync(ic->program(), inputContext, candidates,
                            endReached);
}

void UIPanel::page(const std::string &inputContext, bool next) {
    auto *ic = findInputContext(instance_, inputContext);
    if (!ic) {
        return;
    }
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

void UIPanel::updateStatusArea(InputContext &ic) {
    auto actions = swift::Array<KeyboardUI::StatusAreaAction>::init();
    auto &statusArea = ic.statusArea();
    for (auto *action : statusArea.allActions()) {
        if (!action->id()) {
            // Not registered with UI manager.
            continue;
        }
        actions.append(convertAction(action, &ic));
    }
    KeyboardUI::setStatusAreaAsync(ic.program(), inputContextToken(ic),
                                   actions);
}

} // namespace fcitx

FCITX_ADDON_FACTORY_V2(uipanel, fcitx::UIPanelFactory);

bool inputContextIsFocused(const char *inputContext) {
    std::string token = inputContext;
    return with_fcitx([&] {
        auto *ic = fcitx::findInputContext(instance.get(), token);
        return ic && ic->hasFocus();
    });
}

void scroll(const char *inputContext, int start, int count) {
    std::string token = inputContext;
    dispatcher->schedule([=] { fcitx::ui->scroll(token, start, count); });
}

void page(const char *inputContext, bool next) {
    std::string token = inputContext;
    dispatcher->schedule([=] { fcitx::ui->page(token, next); });
}

std::string getCandidateActions(const char *inputContext, int index) {
    std::string token = inputContext;
    return with_fcitx([&]() -> std::string {
        auto j = nlohmann::json::array();
        auto *ic = fcitx::findInputContext(instance.get(), token);
        do {
            if (!ic) {
                break;
            }
            const auto &list = ic->inputPanel().candidateList();
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

void activateCandidateAction(const char *inputContext, int index, int id) {
    std::string token = inputContext;
    dispatcher->schedule([=] {
        auto *ic = fcitx::findInputContext(instance.get(), token);
        if (!ic) {
            return;
        }
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

void activateCandidateTabAction(const char *inputContext, int id) {
    std::string token = inputContext;
    dispatcher->schedule([=] {
        auto *ic = fcitx::findInputContext(instance.get(), token);
        if (!ic) {
            return;
        }
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

void selectCandidate(const char *inputContext, int index) {
    std::string token = inputContext;
    dispatcher->schedule([=] {
        auto *ic = fcitx::findInputContext(instance.get(), token);
        if (!ic) {
            return;
        }
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

void activateStatusAreaAction(const char *inputContext, int id) {
    std::string token = inputContext;
    dispatcher->schedule([=] {
        if (auto *ic = fcitx::findInputContext(instance.get(), token)) {
            auto *action =
                instance->userInterfaceManager().lookupActionById(id);
            if (action) {
                action->activate(ic);
            }
        }
    });
}
