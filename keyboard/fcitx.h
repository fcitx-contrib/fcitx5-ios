#pragma once

#include <objc/objc.h>

void startFcitx(const char *bundlePath, const char *appGroupPath);
void focusIn(id client);
void focusOut();
bool processKey(const char *key);
void reload();
