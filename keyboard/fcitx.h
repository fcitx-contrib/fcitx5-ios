#pragma once

void startFcitx(const char *appBundlePath, const char *xdgDataDirs,
                const char *appGroupPath);
void focusIn();
void focusOut();
void processKey(const char *key, const char *code);
void resetInput();
void reload();
void toggle();
void setCurrentInputMethod(const char *inputMethod);
