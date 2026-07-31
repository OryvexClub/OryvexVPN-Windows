#ifndef RUNNER_WIN32_WINDOW_H_
#define RUNNER_WIN32_WINDOW_H_
#include <windows.h>
#include <functional>
#include <memory>
#include <string>
class Win32Window {
 public:
  struct Point { unsigned int x; unsigned int y; };
  struct Size { unsigned int width; unsigned int height; };
  Win32Window(); virtual ~Win32Window();
  bool Create(const std::wstring& title, const Point& origin, const Size& size);
  void Destroy();
  void SetQuitOnClose(bool quit_on_close);
  HWND GetHandle();
  float GetDpiScale() const { return dpi_scale_; }
  Size GetClientArea() const;
 protected:
  virtual bool OnCreate();
  virtual void OnDestroy();
  virtual LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam, LPARAM const lparam) noexcept;
 private:
  static bool RegisterWindowClass();
  static const wchar_t* GetWindowClassName();
  HWND window_handle_ = nullptr;
  float dpi_scale_ = 1.0f;
  bool quit_on_close_ = false;
  Point origin_;
  Size size_;
};
#endif
