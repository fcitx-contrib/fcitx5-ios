#include "keycode.h"
#include <fcitx-utils/log.h>

namespace fcitx {
static struct {
    std::string jsCode;
    KeySym sym;
} sym_mappings[] = {
    // modifiers
    {"ControlLeft", FcitxKey_Control_L},
    {"ControlRight", FcitxKey_Control_R},
    {"ShiftLeft", FcitxKey_Shift_L},
    {"ShiftRight", FcitxKey_Shift_R},
    {"CapsLock", FcitxKey_Caps_Lock},
    {"AltLeft", FcitxKey_Alt_L},
    {"AltRight", FcitxKey_Alt_R},
    {"MetaLeft", FcitxKey_Super_L},
    {"MetaRight", FcitxKey_Super_R},

    // keypad
    {"Numpad0", FcitxKey_KP_0},
    {"Numpad1", FcitxKey_KP_1},
    {"Numpad2", FcitxKey_KP_2},
    {"Numpad3", FcitxKey_KP_3},
    {"Numpad4", FcitxKey_KP_4},
    {"Numpad5", FcitxKey_KP_5},
    {"Numpad6", FcitxKey_KP_6},
    {"Numpad7", FcitxKey_KP_7},
    {"Numpad8", FcitxKey_KP_8},
    {"Numpad9", FcitxKey_KP_9},
    {"NumpadComma", FcitxKey_KP_Separator},
    {"NumpadDecimal", FcitxKey_KP_Decimal},
    {"NumpadEqual", FcitxKey_KP_Equal},
    {"NumpadSubtract", FcitxKey_KP_Subtract},
    {"NumpadMultiply", FcitxKey_KP_Multiply},
    {"NumpadAdd", FcitxKey_KP_Add},
    {"NumpadDivide", FcitxKey_KP_Divide},

    // special
    {"Backspace", FcitxKey_BackSpace},
    {"NumpadEnter", FcitxKey_KP_Enter},
    {"Enter", FcitxKey_Return},
    {"Space", FcitxKey_space},
    {"Tab", FcitxKey_Tab},
    {"Escape", FcitxKey_Escape},
    {"Delete", FcitxKey_Delete},
    {"Insert", FcitxKey_Insert},
    {"PageUp", FcitxKey_Page_Up},
    {"PageDown", FcitxKey_Page_Down},
    {"Home", FcitxKey_Home},
    {"End", FcitxKey_End},

    // arrow keys
    {"ArrowUp", FcitxKey_Up},
    {"ArrowDown", FcitxKey_Down},
    {"ArrowLeft", FcitxKey_Left},
    {"ArrowRight", FcitxKey_Right},

    // function keys
    {"F1", FcitxKey_F1},
    {"F2", FcitxKey_F2},
    {"F3", FcitxKey_F3},
    {"F4", FcitxKey_F4},
    {"F5", FcitxKey_F5},
    {"F6", FcitxKey_F6},
    {"F7", FcitxKey_F7},
    {"F8", FcitxKey_F8},
    {"F9", FcitxKey_F9},
    {"F10", FcitxKey_F10},
    {"F11", FcitxKey_F11},
    {"F12", FcitxKey_F12},
};

static struct {
    std::string jsKeycode;
    uint16_t linuxKeycode;
} code_mappings[] = {
    // alphabet
    {"KeyA", 30},
    {"KeyB", 48},
    {"KeyC", 46},
    {"KeyD", 32},
    {"KeyE", 18},
    {"KeyF", 33},
    {"KeyG", 34},
    {"KeyH", 35},
    {"KeyI", 23},
    {"KeyJ", 36},
    {"KeyK", 37},
    {"KeyL", 38},
    {"KeyM", 50},
    {"KeyN", 49},
    {"KeyO", 24},
    {"KeyP", 25},
    {"KeyQ", 16},
    {"KeyR", 19},
    {"KeyS", 31},
    {"KeyT", 20},
    {"KeyU", 22},
    {"KeyV", 47},
    {"KeyW", 17},
    {"KeyX", 45},
    {"KeyY", 21},
    {"KeyZ", 44},

    // number
    {"Digit0", 11},
    {"Digit1", 2},
    {"Digit2", 3},
    {"Digit3", 4},
    {"Digit4", 5},
    {"Digit5", 6},
    {"Digit6", 7},
    {"Digit7", 8},
    {"Digit8", 9},
    {"Digit9", 10},

    // symbol
    {"Backquote", 41},
    {"Backslash", 43},
    {"BracketLeft", 26},
    {"BracketRight", 27},
    {"Comma", 51},
    {"Period", 52},
    {"Equal", 13},
    {"Minus", 12},
    {"Quote", 40},
    {"Semicolon", 39},
    {"Slash", 53},

    // keypad
    {"Numpad0", 82},
    {"Numpad1", 79},
    {"Numpad2", 80},
    {"Numpad3", 81},
    {"Numpad4", 75},
    {"Numpad5", 76},
    {"Numpad6", 77},
    {"Numpad7", 71},
    {"Numpad8", 72},
    {"Numpad9", 73},
    // {OSX_VK_KEYPAD_CLEAR, }, XXX: not sure map to what
    {"NumpadComma", 121},
    {"NumpadDecimal", 83},
    {"NumpadEqual", 117},
    {"NumpadSubtract", 74},
    {"NumpadMultiply", 55},
    {"NumpadAdd", 78},
    {"NumpadDivide", 98},

    // special
    {"Backspace", 14},
    {"NumpadEnter", 96},
    // {OSX_VK_ENTER_POWERBOOK, }, XXX: not sure map to what
    {"Escape", 1},
    {"Delete", 111},
    // {OSX_VK_HELP, }, XXX: not sure map to what
    {"Enter", 28},
    {"Space", 57},
    {"Tab", 15},

    // function
    {"F1", 59},
    {"F2", 60},
    {"F3", 61},
    {"F4", 62},
    {"F5", 63},
    {"F6", 64},
    {"F7", 65},
    {"F8", 66},
    {"F9", 67},
    {"F10", 68},
    {"F11", 87},
    {"F12", 88},

    // cursor
    {"ArrowUp", 103},
    {"ArrowDown", 108},
    {"ArrowLeft", 105},
    {"ArrowRight", 106},

    {"PageUp", 104},
    {"PageDown", 109},
    {"Home", 102},
    {"End", 107},

    // modifiers
    {"CapsLock", 58},
    {"MetaLeft", 125},
    {"MetaRight", 126},
    {"ControlLeft", 29},
    {"ControlRight", 97},
    {"Fn", 0x1d0},
    {"AltLeft", 56},
    {"AltRight", 100},
    {"ShiftLeft", 42},
    {"ShiftRight", 54},
};

KeySym js_key_to_fcitx_keysym(const std::string &key, const std::string &code) {
    for (const auto &pair : sym_mappings) {
        if (pair.jsCode == code) {
            return pair.sym;
        }
    }
    if (key.size() == 1) {
        return Key::keySymFromUnicode(key[0]);
    }
    FCITX_ERROR() << "Unrecognized key " << key << " " << code;
    return {};
}

uint16_t js_keycode_to_fcitx_keycode(const std::string &code) {
    for (const auto &pair : code_mappings) {
        if (pair.jsKeycode == code) {
            return pair.linuxKeycode + 8 /* evdev offset */;
        }
    }
    return 0;
}

Key js_key_to_fcitx_key(const std::string &key, const std::string &code,
                        uint32_t modifiers) {
    return Key{js_key_to_fcitx_keysym(key, code), KeyStates{modifiers},
               js_keycode_to_fcitx_keycode(code)};
}
} // namespace fcitx
