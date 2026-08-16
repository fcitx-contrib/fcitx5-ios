#pragma once

#include <string>

void startFcitx(const char *appBundlePath, const char *xdgDataDirs,
                const char *appGroupPath);
void startKeyboardFcitx(const char *appBundlePath, const char *xdgDataDirs,
                        const char *appGroupPath);
void setLocale(const char *locale);

void focusIn();
void focusOut();
void processKey(const char *key, const char *code);
void resetInput();
void triggerUnicode();
void triggerQuickPhrase();
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
