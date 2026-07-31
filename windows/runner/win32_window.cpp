#include "win32_window.h"
#include <dwmapi.h>
#include <flutter_windows.h>
#include <windows.h>
#include "resource.h"
namespace { static constexpr DWORD DWMWA_USE_IMMERSIVE_DARK_MODE = 20; constexpr bool kUseDarkMode = true; }
Win32Window::Win32Window() {}
Win32Window::~Win32Window() { Destroy(); }
bool Win32Window::Create(const std::wstring& title, const Point& origin, const Size& size) {
  if (window_handle_) return false;
  RegisterWindowClass();
  origin_ = origin; size_ = size;
  const int x = origin.x, y = origin.y, width = size.width, height = size.height;
  window_handle_ = CreateWindow(GetWindowClassName(), title.c_str(), WS_OVERLAPPEDWINDOW, x, y, width, height, nullptr, nullptr, GetModuleHandle(nullptr), this);
  if (!window_handle_) return false;
  if (kUseDarkMode) { BOOL const use_immersive_dark_mode = TRUE; DwmSetWindowAttribute(window_handle_, DWMWA_USE_IMMERSIVE_DARK_MODE, &use_immersive_dark_mode, sizeof(use_immersive_dark_mode)); }
  ShowWindow(window_handle_, SW_SHOW);
  return true;
}
void Win32Window::Destroy() { if (window_handle_) { DestroyWindow(window_handle_); window_handle_ = nullptr; } }
HWND Win32Window::GetHandle() { return window_handle_; }
void Win32Window::SetQuitOnClose(bool quit_on_close) { quit_on_close_ = quit_on_close; }
Win32Window::Size Win32Window::GetClientArea() const { RECT client_area; GetClientRect(window_handle_, &client_area); return Size{static_cast<unsigned int>(client_area.right - client_area.left), static_cast<unsigned int>(client_area.bottom - client_area.top)}; }
bool Win32Window::OnCreate() { return true; }
void Win32Window::OnDestroy() {}
LRESULT Win32Window::MessageHandler(HWND hwnd, UINT const message, WPARAM const wparam, LPARAM const lparam) noexcept {
  switch (message) {
    case WM_DESTROY: window_handle_ = nullptr; if (quit_on_close_) PostQuitMessage(0); return 0;
    case WM_DPICHANGED: dpi_scale_ = GetDpiForWindow(hwnd) / 96.0f; break;
    case WM_GETMINMAXINFO: { auto minmax_info = reinterpret_cast<MINMAXINFO*>(lparam); minmax_info->ptMinTrackSize.x = 400; minmax_info->ptMinTrackSize.y = 300; return 0; }
  }
  return DefWindowProc(hwnd, message, wparam, lparam);
}
bool Win32Window::RegisterWindowClass() {
  static bool registered = false;
  if (registered) return true;
  WNDCLASS window_class{}; window_class.hInstance = GetModuleHandle(nullptr); window_class.lpszClassName = GetWindowClassName(); window_class.lpfnWndProc = &WndProc; window_class.hCursor = LoadCursor(nullptr, IDC_ARROW); window_class.hbrBackground = nullptr; window_class.style = CS_HREDRAW | CS_VREDRAW;
  if (!RegisterClass(&window_class)) return false;
  registered = true; return true;
}
const wchar_t* Win32Window::GetWindowClassName() { return L"FLUTTER_RUNNER_WIN32_WINDOW"; }
LRESULT CALLBACK WndProc(HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam) {
  if (message == WM_NCCREATE) { auto create_struct = reinterpret_cast<CREATESTRUCT*>(lparam); SetWindowLongPtr(hwnd, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(create_struct->lpCreateParams)); }
  auto window = reinterpret_cast<Win32Window*>(GetWindowLongPtr(hwnd, GWLP_USERDATA));
  if (window) return window->MessageHandler(hwnd, message, wparam, lparam);
  return DefWindowProc(hwnd, message, wparam, lparam);
}
