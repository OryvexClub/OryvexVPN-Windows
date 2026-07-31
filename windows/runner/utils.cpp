#include "utils.h"
#include <windows.h>
#include <shellapi.h>
#include <string>
#include <vector>
std::vector<std::string> GetCommandLineArguments() {
  int argc; wchar_t** argv = ::CommandLineToArgvW(::GetCommandLineW(), &argc);
  if (argv == nullptr) return std::vector<std::string>();
  std::vector<std::string> command_line_args;
  for (int i = 1; i < argc; i++) {
    int length = ::WideCharToMultiByte(CP_UTF8, 0, argv[i], -1, nullptr, 0, nullptr, nullptr);
    if (length > 0) { std::string arg(length - 1, 0); ::WideCharToMultiByte(CP_UTF8, 0, argv[i], -1, arg.data(), length, nullptr, nullptr); command_line_args.push_back(arg); }
  }
  ::LocalFree(argv);
  return command_line_args;
}
