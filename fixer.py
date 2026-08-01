#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
fixer.py - OryvexVPN CI-First Project Fixer

اصلاح‌کننده سریع پروژه برای آماده‌سازی کامل فایل‌ها جهت بیلد در GitHub Actions.
بدون نیاز به اجرای دستورات flutter روی سیستم لوکال.
"""

import os
import re
import sys
from pathlib import Path
from typing import Optional, List, Tuple


class FlutterProjectFixer:
    def __init__(self, project_root: Optional[str] = None):
        if project_root:
            self.root = Path(project_root)
        else:
            script_dir = Path(__file__).resolve().parent
            if (script_dir / "pubspec.yaml").exists():
                self.root = script_dir
            else:
                self.root = Path(os.getcwd())
        self.fixed_files: List[str] = []
        self.skipped_files: List[str] = []

    def log(self, message: str, level: str = "INFO"):
        icons = {
            "INFO": "[i]", "SUCCESS": "[OK]", "WARNING": "[!]",
            "ERROR": "[X]", "STEP": "[>]", "FIX": "[FIX]", "SKIP": "[--]",
        }
        print(f"{icons.get(level, '[i]')} {message}")

    def _write_if_needed(self, path: Path, content: str, reason: str, force: bool = False):
        path.parent.mkdir(parents=True, exist_ok=True)
        rel = str(path.relative_to(self.root)) if self._is_relative(path) else str(path)

        if path.exists() and not force:
            try:
                existing = path.read_text(encoding='utf-8')
            except Exception:
                existing = ""
            if existing.strip():
                self.skipped_files.append(f"{rel} (دست‌نخورده باقی ماند)")
                self.log(f"اسکیپ شد: {rel}", "SKIP")
                return False

        path.write_text(content, encoding='utf-8')
        self.fixed_files.append(f"{rel} ({reason})")
        self.log(f"اصلاح شد: {rel} <- {reason}", "FIX")
        return True

    def _is_relative(self, path: Path) -> bool:
        try:
            path.relative_to(self.root)
            return True
        except ValueError:
            return False

    def check_project(self) -> bool:
        if not (self.root / "pubspec.yaml").exists():
            self.log("فایل pubspec.yaml یافت نشد! مسیر پروژه درست نیست.", "ERROR")
            return False
        self.log("پروژه فلاتر شناسایی شد.", "SUCCESS")
        return True

    # 1. بازیابی فایل main.dart به برنامه اصلی اورایوکس
    def fix_main_dart(self) -> bool:
        path = self.root / "lib" / "main.dart"
        content = '''import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/config.dart';
import 'screens/home_screen.dart';
import 'services/network_manager.dart';
import 'services/tray_service.dart';
import 'services/window_manager_service.dart';
import 'services/vpn_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // تنظیمات اولیه پنجره ویندو
  await WindowManagerService.init();

  // شروع پایش وضعیت شبکه
  await NetworkManager.instance.start();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => VPNService()),
      ],
      child: const OryvexVPNApp(),
    ),
  );
}

class OryvexVPNApp extends StatefulWidget {
  const OryvexVPNApp({super.key});

  @override
  State<OryvexVPNApp> createState() => _OryvexVPNAppState();
}

class _OryvexVPNAppState extends State<OryvexVPNApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      TrayService.instance.init();
    });
  }

  @override
  void dispose() {
    TrayService.instance.dispose();
    NetworkManager.instance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const HomeScreen(),
    );
  }
}
'''
        existing = path.read_text(encoding='utf-8') if path.exists() else ""
        is_default_demo = 'Flutter Demo' in existing or 'MyHomePage' in existing or '_counter' in existing
        
        return self._write_if_needed(
            path, 
            content, 
            "بازگردانی main.dart از برنامه نمونه فلاتر به پروژه اصلی", 
            force=is_default_demo
        )

    # 2. تکمیل فایل‌های Core و Services
    def fix_config_dart(self) -> bool:
        path = self.root / "lib" / "core" / "config.dart"
        content = '''class AppConfig {
  AppConfig._();

  static const String appName = 'OryvexVPN';
  static const String appVersion = '1.0.0';

  static const String warpRegisterUrl =
      'https://api.cloudflareclient.com/v0a737/reg';
  static const String defaultDnsPrimary = '1.1.1.1';
  static const String defaultDnsSecondary = '1.0.0.1';
  static const String defaultEndpointPort = '2408';
  static const int mtu = 1280;
  static const int persistentKeepaliveSeconds = 25;

  static const String tunnelInterfaceName = 'oryvexvpn';
  static const Duration processStartupGrace = Duration(milliseconds: 500);
  static const Duration processShutdownGrace = Duration(seconds: 2);
  static const Duration registerTimeout = Duration(seconds: 15);

  static const double windowWidth = 400;
  static const double windowHeight = 700;

  static const String prefAutoConnect = 'auto_connect';
  static const String prefStartMinimized = 'start_minimized';
}
'''
        return self._write_if_needed(path, content, "تنظیم مقادیر کانفیگ برنامه")

    def fix_network_manager(self) -> bool:
        path = self.root / "lib" / "services" / "network_manager.dart"
        content = '''import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkManager {
  NetworkManager._internal();
  static final NetworkManager instance = NetworkManager._internal();

  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _onlineController =
      StreamController<bool>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  Stream<bool> get onConnectivityChanged => _onlineController.stream;

  Future<void> start() async {
    try {
      final initial = await _connectivity.checkConnectivity();
      _isOnline = _resultsToOnline(initial);
    } catch (_) {
      _isOnline = true;
    }

    _subscription?.cancel();
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      final online = _resultsToOnline(results);
      if (online != _isOnline) {
        _isOnline = online;
        _onlineController.add(_isOnline);
      }
    });
  }

  bool _resultsToOnline(List<ConnectivityResult> results) {
    return results.any((r) => r != ConnectivityResult.none);
  }

  Future<bool> checkNow() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _isOnline = _resultsToOnline(results);
      return _isOnline;
    } catch (_) {
      return _isOnline;
    }
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}
'''
        return self._write_if_needed(path, content, "مدیریت اتصال به شبکه")

    def fix_proxy_service(self) -> bool:
        path = self.root / "lib" / "services" / "proxy_service.dart"
        content = '''import 'dart:io';

class ProxyService {
  ProxyService._();

  static const String _regPath =
      r'HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings';

  static Future<bool> isProxyEnabled() async {
    if (!Platform.isWindows) return false;
    try {
      final result = await Process.run(
        'reg',
        ['query', _regPath, '/v', 'ProxyEnable'],
      );
      if (result.exitCode != 0) return false;
      final out = result.stdout.toString();
      return out.contains('0x1');
    } catch (_) {
      return false;
    }
  }

  static Future<String?> currentProxyServer() async {
    if (!Platform.isWindows) return null;
    try {
      final result = await Process.run(
        'reg',
        ['query', _regPath, '/v', 'ProxyServer'],
      );
      if (result.exitCode != 0) return null;
      final out = result.stdout.toString();
      final match = RegExp(r'REG_SZ\\s+(\\S+)').firstMatch(out);
      return match?.group(1);
    } catch (_) {
      return null;
    }
  }

  static Future<void> refreshSystemProxySettings() async {
    if (!Platform.isWindows) return;
    try {
      await Process.run('netsh', ['winhttp', 'import', 'proxy', 'source=ie']);
    } catch (_) {}
  }
}
'''
        return self._write_if_needed(path, content, "سرویس تنظمیات پروکسی")

    def fix_tray_service(self) -> bool:
        path = self.root / "lib" / "services" / "tray_service.dart"
        content = '''import 'dart:io';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

class TrayService with TrayListener {
  TrayService._internal();
  static final TrayService instance = TrayService._internal();

  bool _initialized = false;
  bool _isConnected = false;

  Future<void> Function()? onConnectRequested;
  Future<void> Function()? onDisconnectRequested;
  Future<void> Function()? onQuitRequested;

  Future<void> init() async {
    if (!Platform.isWindows || _initialized) return;
    _initialized = true;

    trayManager.addListener(this);

    try {
      await trayManager.setIcon('windows/runner/resources/app_icon.ico');
    } catch (_) {}

    await _rebuildMenu();
    await trayManager.setToolTip('OryvexVPN');
  }

  Future<void> updateConnectionState(bool isConnected) async {
    _isConnected = isConnected;
    if (!_initialized) return;
    await _rebuildMenu();
    await trayManager.setToolTip(
      isConnected ? 'OryvexVPN - متصل' : 'OryvexVPN - قطع',
    );
  }

  Future<void> _rebuildMenu() async {
    final menu = Menu(
      items: [
        MenuItem(key: 'show_window', label: 'نمایش پنجره'),
        MenuItem.separator(),
        MenuItem(
          key: 'toggle_connection',
          label: _isConnected ? 'قطع اتصال' : 'اتصال',
        ),
        MenuItem.separator(),
        MenuItem(key: 'quit', label: 'خروج'),
      ],
    );
    await trayManager.setContextMenu(menu);
  }

  Future<void> dispose() async {
    if (!_initialized) return;
    trayManager.removeListener(this);
    _initialized = false;
  }

  @override
  void onTrayIconMouseDown() {
    _restoreWindow();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    switch (menuItem.key) {
      case 'show_window':
        await _restoreWindow();
        break;
      case 'toggle_connection':
        if (_isConnected) {
          await onDisconnectRequested?.call();
        } else {
          await onConnectRequested?.call();
        }
        break;
      case 'quit':
        await onQuitRequested?.call();
        break;
    }
  }

  Future<void> _restoreWindow() async {
    if (!Platform.isWindows) return;
    final isVisible = await windowManager.isVisible();
    if (!isVisible) {
      await windowManager.show();
    }
    await windowManager.focus();
  }
}
'''
        return self._write_if_needed(path, content, "سرویس آیکون کنار ساعت (Tray)")

    def fix_window_manager_service(self) -> bool:
        path = self.root / "lib" / "services" / "window_manager_service.dart"
        content = '''import 'dart:io';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:warp_vpn_app/core/config.dart';

class WindowManagerService {
  WindowManagerService._();

  static bool _initialized = false;

  static Future<void> init() async {
    if (!Platform.isWindows || _initialized) return;
    _initialized = true;

    await windowManager.ensureInitialized();

    const windowOptions = WindowOptions(
      size: Size(AppConfig.windowWidth, AppConfig.windowHeight),
      minimumSize: Size(AppConfig.windowWidth, AppConfig.windowHeight),
      maximumSize: Size(AppConfig.windowWidth, AppConfig.windowHeight),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  static Future<void> hideToTray() async {
    if (!Platform.isWindows) return;
    await windowManager.hide();
  }

  static Future<void> restore() async {
    if (!Platform.isWindows) return;
    await windowManager.show();
    await windowManager.focus();
  }

  static Future<void> quit() async {
    if (!Platform.isWindows) {
      exit(0);
    }
    await windowManager.destroy();
  }
}
'''
        return self._write_if_needed(path, content, "مدیریت ابعاد و حالت پنجره برنامه")

    # 3. اصلاح وابستگی‌های pubspec.yaml
    def fix_pubspec_dependencies(self) -> bool:
        path = self.root / "pubspec.yaml"
        if not path.exists():
            return False

        text = path.read_text(encoding='utf-8')
        required_deps = {
            "window_manager": "^0.4.3",
            "settings_ui": "^2.0.2",
            "shared_preferences": "^2.3.2",
            "tray_manager": "^0.3.1",
            "provider": "^6.1.2",
            "connectivity_plus": "^6.1.0",
            "http": "^1.2.2",
            "cryptography": "^2.7.0",
            "path_provider": "^2.1.1",
        }

        lines = text.splitlines()
        try:
            dep_idx = next(i for i, l in enumerate(lines) if l.strip() == "dependencies:")
        except StopIteration:
            return False

        end_idx = len(lines)
        for i in range(dep_idx + 1, len(lines)):
            line = lines[i]
            if line and not line.startswith(' ') and not line.startswith('\t') and line.strip():
                end_idx = i
                break

        block = "\n".join(lines[dep_idx:end_idx])
        missing = {
            name: ver for name, ver in required_deps.items()
            if re.search(rf'^\s*{re.escape(name)}\s*:', block, re.MULTILINE) is None
        }

        if not missing:
            return False

        insertion = "\n".join(f"  {name}: {ver}" for name, ver in missing.items())
        new_lines = lines[:end_idx] + [insertion] + lines[end_idx:]
        path.write_text("\n".join(new_lines) + "\n", encoding='utf-8')
        self.fixed_files.append(f"pubspec.yaml (افزودن کتابخانه‌های: {', '.join(missing.keys())})")
        return True

    def fix_sdk_constraint(self) -> bool:
        pubspec = self.root / "pubspec.yaml"
        if pubspec.exists():
            text = pubspec.read_text(encoding='utf-8')
            new_text, count = re.subn(
                r"sdk:\s*['\"][^'\"]*['\"]",
                "sdk: '>=3.0.0 <4.0.0'",
                text,
                count=1,
            )
            if count > 0 and new_text != text:
                pubspec.write_text(new_text, encoding='utf-8')
                self.fixed_files.append("pubspec.yaml (اصلاح رنج نسخه Dart برای GitHub Actions)")
                return True
        return False

    def run(self) -> bool:
        print("\n" + "=" * 64)
        print("OryvexVPN CI-Ready Project Fixer")
        print("=" * 64)
        print(f"\nمسیر پروژه: {self.root}\n")

        if not self.check_project():
            return False

        # بازسازی بدون فراخوانی ترمینال فلاتر
        self.fix_main_dart()
        self.fix_config_dart()
        self.fix_network_manager()
        self.fix_proxy_service()
        self.fix_tray_service()
        self.fix_window_manager_service()
        self.fix_pubspec_dependencies()
        self.fix_sdk_constraint()

        print("\n" + "=" * 64)
        print("گزارش نهایی")
        print("=" * 64)

        if self.fixed_files:
            print("\nفایل‌های اصلاح شده:")
            for f in self.fixed_files:
                print(f"  [OK]  {f}")
        else:
            print("\nتمام فایل‌ها سالم بودند نیاز به تغییری نبود.")

        print("\nکار تمام است! حالا بدون زدن هیچ دستوری در سیستم لوکال، کد را Commit و Push کنید تا بیلد در GitHub Actions انجام شود.")
        return True


if __name__ == "__main__":
    try:
        root = sys.argv[1] if len(sys.argv) > 1 else os.getcwd()
        fixer = FlutterProjectFixer(root)
        fixer.run()
    except Exception as e:
        print(f"\nخطا: {e}")
        sys.exit(1)