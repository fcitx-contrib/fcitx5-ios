#include <fcitx-utils/event.h>
#include <fcitx-utils/eventdispatcher.h>
#include <fcitx/addonloader.h>
#include <fcitx/instance.h>

extern std::unique_ptr<fcitx::Instance> instance;
extern std::unique_ptr<fcitx::EventDispatcher> dispatcher;

void setupFcitx(const char *appBundlePath, const char *xdgDataDirs,
                const char *appGroupPath, bool isMainApp);
