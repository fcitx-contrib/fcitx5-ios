#pragma once

#include <fcitx-utils/eventdispatcher.h>
#include <fcitx/instance.h>
#include <future>

extern std::unique_ptr<fcitx::Instance> instance;
extern std::unique_ptr<fcitx::EventDispatcher> dispatcher;

template <class F, class T = std::invoke_result_t<F>>
inline T with_fcitx(F func) {
    std::promise<T> prom;
    std::future<T> fut = prom.get_future();
    dispatcher->schedule([&prom, func = std::move(func)]() {
        try {
            if constexpr (std::is_void_v<T>) {
                func();
                prom.set_value();
            } else {
                T result = func();
                prom.set_value(std::move(result));
            }
        } catch (...) {
            prom.set_exception(std::current_exception());
        }
    });
    fut.wait();
    return fut.get();
}
