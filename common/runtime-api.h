#pragma once

#include <string>

void startFcitx(const char *appBundlePath, const char *xdgDataDirs,
                const char *appGroupPath);
void startKeyboardFcitx(const char *appBundlePath, const char *xdgDataDirs,
                        const char *appGroupPath);
void setLocale(const char *locale);

void focusIn(const char *program, const char *documentIdentifier);
void focusOut(const char *program, const char *documentIdentifier);
void destroyInputContext(const char *program);
void processKey(const char *program, const char *documentIdentifier,
                const char *key, const char *code, unsigned int modifiers,
                const char *surroundingText, unsigned int cursor,
                unsigned int anchor, bool reset);
void resetInput(const char *program, const char *documentIdentifier);
void triggerUnicode(const char *program, const char *documentIdentifier);
void triggerQuickPhrase(const char *program, const char *documentIdentifier);
void reload();
void toggle();

void setCurrentInputMethod(const char *inputMethod);
void setInputMethods(const char *json);
std::string getAllInputMethods();
std::string getInputMethods();

std::string getConfig(const char *uri);
void setConfig(const char *uri, const char *value);
std::string getAddons();
bool isRegexValid(const char *regex);
