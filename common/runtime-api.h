#pragma once

#include <string>

void startFcitx(const char *appBundlePath, const char *xdgDataDirs,
                const char *appGroupPath);
void startKeyboardFcitx(const char *appBundlePath, const char *xdgDataDirs,
                        const char *appGroupPath);

void focusIn();
void focusOut();
void processKey(const char *key, const char *code);
void resetInput();
void triggerUnicode();
void triggerQuickPhrase();
void reload();
void toggle();
void setCurrentInputMethod(const char *inputMethod);

std::string getConfig(const char *uri);
void setConfig(const char *uri, const char *value);
std::string getAddons();
void setInputMethods(const char *json);
std::string getAllInputMethods();
std::string getInputMethods();
void setLocale(const char *locale);
