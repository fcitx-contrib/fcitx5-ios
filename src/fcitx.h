#pragma once

#include <string>

void startFcitx(const char *bundlePath, const char *appGroupPath);
std::string getConfig(const char *uri);
void setConfig(const char *uri, const char *value);
std::string getAddons();
void setInputMethods(const char *json);
std::string getAllInputMethods();
