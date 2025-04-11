#pragma once

#include <objc/objc.h>

void startFcitx(const char *bundlePath, const char *appGroupPath);
void focusIn(id client);
void focusOut(id client);
bool processKey(const char *key, const char *code);
void reload();
void toggle();
