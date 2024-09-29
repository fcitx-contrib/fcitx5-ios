#include "nativestreambuf.h"
#include <fcitx/instance.h>
#include <thread>

#include "fcitx.h"

native_streambuf log_streambuf;
std::unique_ptr<fcitx::Instance> instance;
std::ostream stream(&log_streambuf);
std::thread fcitx_thread;

void startFcitx() {
  if (instance) {
    return;
  }
  fcitx::Log::setLogStream(stream);
  fcitx::Log::setLogRule("*=5,notimedate");
  instance = std::make_unique<fcitx::Instance>(0, nullptr);
  fcitx_thread = std::thread([] { instance->exec(); });
  return;
}
