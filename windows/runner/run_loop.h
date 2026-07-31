#ifndef RUNNER_RUN_LOOP_H_
#define RUNNER_RUN_LOOP_H_
#include <windows.h>
#include <functional>
#include <vector>
class RunLoop {
 public:
  using Task = std::function<void()>;
  RunLoop(); ~RunLoop();
  void Run(); void Quit(); void PostTask(Task task);
 private:
  static LRESULT CALLBACK WndProc(HWND window, UINT message, WPARAM wparam, LPARAM lparam);
  void ProcessMessage(UINT message, WPARAM wparam, LPARAM lparam);
  HWND window_; bool running_ = false; std::vector<Task> tasks_; CRITICAL_SECTION tasks_mutex_;
};
#endif
