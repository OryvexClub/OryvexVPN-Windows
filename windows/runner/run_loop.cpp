#include "run_loop.h"
#include <windows.h>
namespace { constexpr UINT kTaskMessage = WM_USER + 1; }
RunLoop::RunLoop() {
  WNDCLASS window_class{}; window_class.hInstance = GetModuleHandle(nullptr); window_class.lpszClassName = L"RunLoopWindow"; window_class.lpfnWndProc = WndProc; RegisterClass(&window_class);
  window_ = CreateWindowEx(0, L"RunLoopWindow", L"", 0, 0, 0, 0, 0, HWND_MESSAGE, nullptr, nullptr, this);
  InitializeCriticalSection(&tasks_mutex_);
}
RunLoop::~RunLoop() { DeleteCriticalSection(&tasks_mutex_); DestroyWindow(window_); }
void RunLoop::Run() { running_ = true; MSG message; while (running_ && GetMessage(&message, nullptr, 0, 0)) { TranslateMessage(&message); DispatchMessage(&message); } }
void RunLoop::Quit() { running_ = false; PostQuitMessage(0); }
void RunLoop::PostTask(Task task) { EnterCriticalSection(&tasks_mutex_); tasks_.push_back(std::move(task)); LeaveCriticalSection(&tasks_mutex_); PostMessage(window_, kTaskMessage, 0, 0); }
void RunLoop::ProcessMessage(UINT message, WPARAM wparam, LPARAM lparam) {
  if (message == kTaskMessage) { EnterCriticalSection(&tasks_mutex_); std::vector<Task> tasks = std::move(tasks_); LeaveCriticalSection(&tasks_mutex_); for (const auto& task : tasks) task(); }
}
LRESULT CALLBACK RunLoop::WndProc(HWND window, UINT message, WPARAM wparam, LPARAM lparam) {
  if (message == WM_NCCREATE) { auto create_struct = reinterpret_cast<CREATESTRUCT*>(lparam); SetWindowLongPtr(window, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(create_struct->lpCreateParams)); }
  auto run_loop = reinterpret_cast<RunLoop*>(GetWindowLongPtr(window, GWLP_USERDATA));
  if (run_loop) run_loop->ProcessMessage(message, wparam, lparam);
  return DefWindowProc(window, message, wparam, lparam);
}
