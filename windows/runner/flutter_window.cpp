#include "flutter_window.h"
#include <optional>
#include "flutter/generated_plugin_registrant.h"
FlutterWindow::FlutterWindow(const flutter::DartProject& project) : project_(project) {}
FlutterWindow::~FlutterWindow() {}
bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) return false;
  auto state = flutter::FlutterViewController::CreateWithProject(project_);
  if (!state) return false;
  flutter_controller_ = std::move(*state);
  flutter_controller_->SetBounds(GetClientArea());
  flutter_controller_->AddPluginRegistrant(&RegisterPlugins);
  SetChildContent(flutter_controller_->view()->GetNativeWindow());
  flutter_controller_->ForceRedraw();
  return true;
}
void FlutterWindow::OnDestroy() {
  if (flutter_controller_) flutter_controller_ = nullptr;
  Win32Window::OnDestroy();
}
LRESULT FlutterWindow::MessageHandler(HWND hwnd, UINT const message, WPARAM const wparam, LPARAM const lparam) noexcept {
  if (flutter_controller_) {
    std::optional<LRESULT> result = flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam, lparam);
    if (result) return *result;
  }
  switch (message) {
    case WM_FONTCHANGE: flutter_controller_->ForceRedraw(); break;
  }
  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
