#pragma once

#include <objc/objc.h>

void startFcitx(const char *bundlePath);
void focusIn(id client);
bool processKey(const char *key);
