#pragma once

#include <string>

void startFcitx(const char *bundlePath, const char *appGroupPath);
void setConfig(const char *uri, const char *value);
void setInputMethods(const char *json);
std::string getAllInputMethods();
