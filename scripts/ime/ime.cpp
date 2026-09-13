#include <windows.h>
#include <imm.h>

#include <iostream>
#include <stdexcept>
#include <string>

namespace {

constexpr WPARAM kImcGetConversionMode = 0x0001;
constexpr WPARAM kImcSetConversionMode = 0x0002;
constexpr WPARAM kImcGetOpenStatus = 0x0005;
constexpr WPARAM kImcSetOpenStatus = 0x0006;
constexpr ULONG_PTR kImeCmodeNative = 0x0001;
constexpr UINT kImeTimeoutMs = 300;

struct Target {
    HWND ime;
};

struct State {
    bool open;
    bool native;
    ULONG_PTR conversion;

    const char* mode() const
    {
        return open && native ? "zh" : "en";
    }
};

Target get_target()
{
    HWND foreground = GetForegroundWindow();
    if (foreground == nullptr) {
        throw std::runtime_error("no foreground window");
    }

    DWORD thread_id = GetWindowThreadProcessId(foreground, nullptr);

    GUITHREADINFO info{};
    info.cbSize = sizeof(info);
    HWND focus = foreground;
    if (thread_id != 0 && GetGUIThreadInfo(thread_id, &info)
        && info.hwndFocus != nullptr) {
        focus = info.hwndFocus;
    }

    HWND ime = ImmGetDefaultIMEWnd(focus);
    if (ime == nullptr) {
        throw std::runtime_error("no default IME window");
    }

    return { ime };
}

ULONG_PTR ime_control(const Target& target, WPARAM control, LPARAM value = 0)
{
    DWORD_PTR result = 0;
    LRESULT sent = SendMessageTimeoutW(
        target.ime,
        WM_IME_CONTROL,
        control,
        value,
        SMTO_ABORTIFHUNG | SMTO_ERRORONEXIT,
        kImeTimeoutMs,
        &result);

    if (sent == 0) {
        throw std::runtime_error("WM_IME_CONTROL failed or timed out");
    }
    return result;
}

State get_state(const Target& target)
{
    ULONG_PTR open = ime_control(target, kImcGetOpenStatus);
    ULONG_PTR conversion = ime_control(target, kImcGetConversionMode);

    return {
        open != 0,
        (conversion & kImeCmodeNative) != 0,
        conversion,
    };
}

std::string set_mode(const Target& target, const std::string& desired)
{
    if (desired != "en" && desired != "zh") {
        throw std::runtime_error("usage: ime.exe [status|en|zh|--server]");
    }

    State before = get_state(target);

    if (desired == "en") {
        ime_control(target, kImcSetOpenStatus, 0);
    } else {
        ime_control(target, kImcSetOpenStatus, 1);
        ULONG_PTR conversion = ime_control(target, kImcGetConversionMode);
        ime_control(
            target,
            kImcSetConversionMode,
            static_cast<LPARAM>(conversion | kImeCmodeNative));
    }

    State after = get_state(target);
    if (after.mode() != desired) {
        throw std::runtime_error(
            std::string("requested ") + desired + " but read back "
            + after.mode());
    }

    return std::string(before.mode()) + " -> " + after.mode();
}

std::string execute(const std::string& mode)
{
    if (mode != "status" && mode != "en" && mode != "zh") {
        throw std::runtime_error("usage: ime.exe [status|en|zh|--server]");
    }

    Target target = get_target();
    if (mode == "status") {
        State state = get_state(target);
        return std::string("mode=") + state.mode()
            + " open=" + (state.open ? "True" : "False")
            + " native=" + (state.native ? "True" : "False")
            + " conversion=" + std::to_string(state.conversion);
    }

    return set_mode(target, mode);
}

int run_server()
{
    std::cout << "READY\n" << std::flush;

    std::string mode;
    while (std::getline(std::cin, mode)) {
        if (!mode.empty() && mode.back() == '\r') {
            mode.pop_back();
        }
        if (mode.empty()) {
            continue;
        }

        try {
            std::cout << execute(mode) << '\n';
        } catch (const std::exception& error) {
            std::cout << "ERROR " << error.what() << '\n';
        }
        std::cout.flush();
    }

    return 0;
}

} // namespace

int main(int argc, char** argv)
{
    std::ios::sync_with_stdio(false);

    if (argc > 1 && std::string(argv[1]) == "--server") {
        return run_server();
    }

    try {
        std::string mode = argc > 1 ? argv[1] : "status";
        std::cout << execute(mode) << '\n';
        return 0;
    } catch (const std::exception& error) {
        std::cerr << error.what() << '\n';
        return 1;
    }
}
