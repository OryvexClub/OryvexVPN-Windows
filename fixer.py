#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
fixer.py - ابزار رفع خودکار مشکلات پروژه فلاتر OryvexVPN

نسخه جدید:
- برندینگ "Oryvex VPS" به "OryvexVPN" تغییر کرد.
- اتصال واقعی WireGuard روی ویندوز اضافه شد (به‌جای کانفیگ ساختگی قبلی).
- طراحی رابط کاربری بهبود یافت و لودر واقعی مرحله‌به‌مرحله اضافه شد.

مهم: این ابزار دیگر کلید WARP جعلی تولید نمی‌کند، چون آن کلیدها هرگز با
سرورهای واقعی Cloudflare تایید نمی‌شدند و برنامه را در حالت "قطع واقعی /
نمایش متصل" نگه می‌داشتند. اتصال واقعی نیازمند سرور WireGuard خودتان
(همان VPS) است که آدرس و توکن آن را از تنظیمات برنامه وارد می‌کنید.
"""

import os
import re
import sys
from pathlib import Path
from typing import Optional


class FlutterProjectFixer:
    def __init__(self, project_root: Optional[str] = None):
        if project_root:
            self.root = Path(project_root)
        else:
            # پیش‌فرض: پوشه‌ای که خود fixer.py در آن قرار دارد، نه پوشه‌ای
            # که از آنجا اجرا شده‌اید (raw cwd می‌تواند اشتباه باشد وقتی
            # اسکریپت را از یک مسیر بالاتر صدا می‌زنید).
            script_dir = Path(__file__).resolve().parent
            if (script_dir / "pubspec.yaml").exists():
                self.root = script_dir
            else:
                self.root = Path(os.getcwd())
        self.fixed_files = []

    def log(self, message: str, level: str = "INFO"):
        icons = {
            "INFO": "[i]", "SUCCESS": "[✓]", "WARNING": "[!]",
            "ERROR": "[✗]", "STEP": "[>]", "FIX": "[🔧]"
        }
        print(f"{icons.get(level, '[i]')} {message}")

    def check_project(self) -> bool:
        if not (self.root / "pubspec.yaml").exists():
            self.log("فایل pubspec.yaml پیدا نشد! این یک پروژه فلاتر نیست.", "ERROR")
            return False
        self.log("پروژه فلاتر شناسایی شد.", "SUCCESS")
        return True

    # ------------------------------------------------------------------
    # lib/main.dart
    # ------------------------------------------------------------------
    def fix_main_dart(self) -> bool:
        main_path = self.root / "lib" / "main.dart"
        correct = '''import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:warp_vpn_app/screens/home_screen.dart';
import 'package:warp_vpn_app/services/vpn_service.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (_) => VPNService(),
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'OryvexVPN',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D0D12),
        primaryColor: const Color(0xFF00E5FF),
        fontFamily: 'Vazirmatn',
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E5FF),
          surface: Color(0xFF1A1A22),
        ),
      ),
      home: const HomeScreen(),
    ),
  );
}
'''
        main_path.parent.mkdir(parents=True, exist_ok=True)
        main_path.write_text(correct, encoding='utf-8')
        self.fixed_files.append("main.dart")
        return True

    # ------------------------------------------------------------------
    # lib/services/wireguard_service.dart  (NEW - the real connection layer)
    # ------------------------------------------------------------------
    def fix_wireguard_service(self) -> bool:
        wg_path = self.root / "lib" / "services" / "wireguard_service.dart"
        correct = '''import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// مدیریت واقعی تانل WireGuard روی ویندوز.
///
/// نیازمندی‌ها:
///  1) WireGuard for Windows نصب باشد (wireguard.com/install).
///  2) برنامه با دسترسی Administrator اجرا شود (نصب/حذف تانل نیاز به
///     ارتقای سطح دسترسی دارد - این یک محدودیت ویندوز است، نه این کد).
///  3) یک سرور VPS خودتان که WireGuard روی آن اجرا می‌شود و کانفیگ معتبر
///     برمی‌گرداند.
///
/// این سرویس هیچ کلیدی را به‌صورت ساختگی تولید نمی‌کند. کانفیگ را عیناً از
/// سرور شما می‌گیرد و همان را روی سیستم نصب می‌کند، سپس وضعیت واقعی سرویس
/// ویندوز را می‌خواند تا وضعیت اتصال هرگز دروغ نگوید.
class WireGuardService {
  static const _tunnelName = 'oryvexvpn';

  /// دریافت کانفیگ آماده از بک‌اند شما.
  /// قرارداد بک‌اند:
  ///   POST {serverUrl}/api/wireguard/config
  ///   Header: Authorization: Bearer <token>
  ///   Response JSON: { "config": "<متن کامل کانفیگ WireGuard>" }
  static Future<String> fetchConfig({
    required String serverUrl,
    required String token,
  }) async {
    if (serverUrl.trim().isEmpty) {
      throw Exception('آدرس سرور VPS تنظیم نشده است');
    }
    final base = serverUrl.trim().replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.parse('$base/api/wireguard/config');

    final response = await http
        .post(uri, headers: {'Authorization': 'Bearer $token'})
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('سرور کانفیگ برنگرداند (کد ${response.statusCode})');
    }

    final data = json.decode(response.body);
    final config = data['config'];
    if (config == null || config.toString().trim().isEmpty) {
      throw Exception('پاسخ سرور کانفیگ معتبری نداشت');
    }
    return config.toString();
  }

  static Future<File> _writeConfigFile(String config) async {
    final dir = Directory.systemTemp;
    final file = File('${dir.path}\\\\$_tunnelName.conf');
    return file.writeAsString(config);
  }

  static Future<bool> isWireGuardInstalled() async {
    try {
      final result = await Process.run('where', ['wireguard.exe']);
      return result.exitCode == 0 &&
          result.stdout.toString().trim().isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// نصب و راه‌اندازی واقعی سرویس تانل. در صورت خطا (مثل نبود دسترسی
  /// Administrator یا نصب‌نبودن WireGuard) پیام خطای قابل‌فهم می‌دهد.
  static Future<void> connect(String config) async {
    if (!Platform.isWindows) {
      throw Exception('این نسخه فعلاً فقط از ویندوز پشتیبانی می‌کند');
    }
    if (!await isWireGuardInstalled()) {
      throw Exception(
        'WireGuard برای ویندوز نصب نیست. از wireguard.com/install دانلود کنید',
      );
    }

    final file = await _writeConfigFile(config);
    final result = await Process.run(
      'wireguard.exe',
      ['/installtunnelservice', file.path],
      runInShell: true,
    );

    if (result.exitCode != 0) {
      throw Exception(
        'نصب تانل ناموفق بود. برنامه را با دسترسی Administrator اجرا کنید.\\n'
        '${result.stderr}',
      );
    }
  }

  static Future<void> disconnect() async {
    if (!Platform.isWindows) return;
    await Process.run(
      'wireguard.exe',
      ['/uninstalltunnelservice', _tunnelName],
      runInShell: true,
    );
  }

  /// وضعیت واقعی را از خود ویندوز می‌پرسد - رابط کاربری هرگز از این جلوتر
  /// ادعای "متصل" نمی‌کند.
  static Future<bool> isConnected() async {
    if (!Platform.isWindows) return false;
    try {
      final result = await Process.run(
        'sc',
        ['query', 'WireGuardTunnel\\$$_tunnelName'],
        runInShell: true,
      );
      return result.stdout.toString().contains('RUNNING');
    } catch (_) {
      return false;
    }
  }

  static Future<void> saveServerSettings(String url, String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('oryvex_server_url', url);
    await prefs.setString('oryvex_server_token', token);
  }

  static Future<Map<String, String>> loadServerSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'url': prefs.getString('oryvex_server_url') ?? '',
      'token': prefs.getString('oryvex_server_token') ?? '',
    };
  }
}
'''
        wg_path.parent.mkdir(parents=True, exist_ok=True)
        wg_path.write_text(correct, encoding='utf-8')
        self.fixed_files.append("wireguard_service.dart (جدید)")
        return True

    # ------------------------------------------------------------------
    # lib/services/vpn_service.dart
    # ------------------------------------------------------------------
    def fix_vpn_service(self) -> bool:
        vpn_path = self.root / "lib" / "services" / "vpn_service.dart"
        correct = '''import 'package:flutter/foundation.dart';
import 'wireguard_service.dart';

enum VpnStage {
  idle,
  fetchingConfig,
  installingTunnel,
  connected,
  error,
  disconnecting,
}

class VPNService extends ChangeNotifier {
  VpnStage _stage = VpnStage.idle;
  String _statusMessage = 'برای اتصال کلیک کنید';
  String? _lastError;
  String _serverUrl = '';
  String _token = '';

  VpnStage get stage => _stage;
  bool get isConnected => _stage == VpnStage.connected;
  bool get isConnecting =>
      _stage == VpnStage.fetchingConfig || _stage == VpnStage.installingTunnel;
  String get statusMessage => _statusMessage;
  String? get lastError => _lastError;
  String get serverUrl => _serverUrl;

  Future<void> loadSettings() async {
    final s = await WireGuardService.loadServerSettings();
    _serverUrl = s['url'] ?? '';
    _token = s['token'] ?? '';

    // وضعیت واقعی سرویس ویندوز را چک می‌کنیم تا اگر تانل از قبل بالا بود
    // رابط کاربری با واقعیت هماهنگ باشد (نه صرفاً یک متغیر محلی).
    if (await WireGuardService.isConnected()) {
      _stage = VpnStage.connected;
      _statusMessage = 'متصل';
      notifyListeners();
    }
  }

  Future<void> saveSettings(String url, String token) async {
    _serverUrl = url;
    _token = token;
    await WireGuardService.saveServerSettings(url, token);
    notifyListeners();
  }

  Future<void> connect() async {
    if (isConnecting) return;

    if (_serverUrl.trim().isEmpty) {
      _lastError = 'ابتدا آدرس سرور VPS را در تنظیمات وارد کنید';
      _stage = VpnStage.error;
      _statusMessage = 'اتصال ناموفق بود';
      notifyListeners();
      return;
    }

    _lastError = null;
    _stage = VpnStage.fetchingConfig;
    _statusMessage = 'در حال دریافت کانفیگ از سرور...';
    notifyListeners();

    try {
      final config = await WireGuardService.fetchConfig(
        serverUrl: _serverUrl,
        token: _token,
      );

      _stage = VpnStage.installingTunnel;
      _statusMessage = 'در حال برقراری تانل WireGuard...';
      notifyListeners();

      await WireGuardService.connect(config);

      // هرگز صرفاً بر اساس موفقیت فراخوانی ادعای اتصال نمی‌کنیم؛ از خود
      // ویندوز می‌پرسیم که سرویس واقعاً در حال اجراست یا نه.
      final actuallyUp = await WireGuardService.isConnected();
      if (!actuallyUp) {
        throw Exception(
          'تانل نصب شد ولی سرویس ویندوز آن را «در حال اجرا» گزارش نمی‌دهد',
        );
      }

      _stage = VpnStage.connected;
      _statusMessage = 'متصل';
    } catch (e) {
      _stage = VpnStage.error;
      _lastError = e.toString().replaceFirst('Exception: ', '');
      _statusMessage = 'اتصال ناموفق بود';
    }
    notifyListeners();
  }

  Future<void> disconnect() async {
    _stage = VpnStage.disconnecting;
    _statusMessage = 'در حال قطع اتصال...';
    notifyListeners();

    await WireGuardService.disconnect();

    _stage = VpnStage.idle;
    _statusMessage = 'قطع شد';
    notifyListeners();
  }
}
'''
        vpn_path.parent.mkdir(parents=True, exist_ok=True)
        vpn_path.write_text(correct, encoding='utf-8')
        self.fixed_files.append("vpn_service.dart")
        return True

    # ------------------------------------------------------------------
    # lib/screens/settings_dialog.dart (NEW)
    # ------------------------------------------------------------------
    def fix_settings_dialog(self) -> bool:
        settings_path = self.root / "lib" / "screens" / "settings_dialog.dart"
        correct = '''import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/vpn_service.dart';

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({Key? key}) : super(key: key);

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  final _urlController = TextEditingController();
  final _tokenController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final vpn = context.read<VPNService>();
    _urlController.text = vpn.serverUrl;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A22),
      title: const Text(
        'تنظیمات سرور VPS',
        style: TextStyle(fontFamily: 'Vazirmatn', color: Colors.white),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _urlController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'آدرس سرور (https://vps.example.com)',
              labelStyle: TextStyle(color: Colors.white54),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _tokenController,
            obscureText: true,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'توکن دسترسی',
              labelStyle: TextStyle(color: Colors.white54),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'سرور شما باید روی مسیر /api/wireguard/config یک کانفیگ '
            'WireGuard معتبر برگرداند. برنامه فقط همان کانفیگ را دریافت '
            'و روی سیستم نصب می‌کند.',
            style: TextStyle(
              fontFamily: 'Vazirmatn',
              fontSize: 12,
              color: Colors.white38,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('انصراف'),
        ),
        ElevatedButton(
          onPressed: () {
            context.read<VPNService>().saveSettings(
                  _urlController.text.trim(),
                  _tokenController.text.trim(),
                );
            Navigator.pop(context);
          },
          child: const Text('ذخیره'),
        ),
      ],
    );
  }
}
'''
        settings_path.parent.mkdir(parents=True, exist_ok=True)
        settings_path.write_text(correct, encoding='utf-8')
        self.fixed_files.append("settings_dialog.dart (جدید)")
        return True

    # ------------------------------------------------------------------
    # lib/screens/home_screen.dart
    # ------------------------------------------------------------------
    def fix_home_screen(self) -> bool:
        home_path = self.root / "lib" / "screens" / "home_screen.dart"
        correct = '''import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/vpn_service.dart';
import 'settings_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VPNService>().loadSettings();
    });
  }

  @override
  Widget build(BuildContext context) {
    final vpn = context.watch<VPNService>();

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0D0D12), Color(0xFF15151C)],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            vpn.isConnected ? Icons.shield_rounded : Icons.shield_outlined,
                            color: vpn.isConnected ? const Color(0xFF00E5FF) : Colors.white54,
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'OryvexVPN',
                            style: TextStyle(
                              fontFamily: 'Vazirmatn',
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.settings_rounded, color: Colors.white70),
                        onPressed: () => showDialog(
                          context: context,
                          builder: (_) => const SettingsDialog(),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                Text(
                  vpn.statusMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Vazirmatn',
                    fontSize: 16,
                    color: vpn.isConnected
                        ? const Color(0xFF00E5FF)
                        : (vpn.stage == VpnStage.error ? Colors.redAccent : Colors.white54),
                  ),
                ),
                if (vpn.lastError != null) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      vpn.lastError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Vazirmatn',
                        fontSize: 12,
                        color: Colors.redAccent,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 40),

                // دکمه اتصال / لودر واقعی مرحله‌به‌مرحله
                GestureDetector(
                  onTap: vpn.isConnecting
                      ? null
                      : () => vpn.isConnected ? vpn.disconnect() : vpn.connect(),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF1A1A22),
                      boxShadow: [
                        BoxShadow(
                          color: vpn.isConnected
                              ? const Color(0xFF00E5FF).withOpacity(0.35)
                              : (vpn.isConnecting
                                  ? Colors.orangeAccent.withOpacity(0.3)
                                  : Colors.black26),
                          blurRadius: vpn.isConnected || vpn.isConnecting ? 50 : 15,
                          spreadRadius: vpn.isConnected || vpn.isConnecting ? 5 : 0,
                        ),
                      ],
                      border: Border.all(
                        color: vpn.isConnected
                            ? const Color(0xFF00E5FF)
                            : (vpn.isConnecting ? Colors.orangeAccent : Colors.white12),
                        width: vpn.isConnected ? 4 : 2,
                      ),
                    ),
                    child: Center(
                      child: vpn.isConnecting
                          ? const SizedBox(
                              width: 46,
                              height: 46,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                color: Colors.orangeAccent,
                              ),
                            )
                          : Icon(
                              Icons.power_settings_new_rounded,
                              size: 70,
                              color: vpn.isConnected ? const Color(0xFF00E5FF) : Colors.white30,
                            ),
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                Expanded(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 400),
                    opacity: vpn.isConnected ? 1.0 : 0.0,
                    child: vpn.isConnected
                        ? Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A1A22),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.dns_rounded, color: Color(0xFF00E5FF), size: 18),
                                      SizedBox(width: 8),
                                      Text(
                                        'تانل WireGuard فعال است',
                                        style: TextStyle(
                                          fontFamily: 'Vazirmatn',
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          )
                        : const SizedBox(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
'''
        home_path.parent.mkdir(parents=True, exist_ok=True)
        home_path.write_text(correct, encoding='utf-8')
        self.fixed_files.append("home_screen.dart")
        return True

    # ------------------------------------------------------------------
    # pubspec.yaml
    # ------------------------------------------------------------------
    def fix_pubspec(self) -> bool:
        pubspec_path = self.root / "pubspec.yaml"
        correct = '''name: warp_vpn_app
description: داشبورد OryvexVPN - اتصال واقعی به سرور WireGuard شخصی شما
version: 1.0.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter
  intl: ^0.19.0
  http: ^1.1.0
  crypto: ^3.0.3
  path_provider: ^2.1.1
  permission_handler: ^11.0.1
  provider: ^6.0.5
  share_plus: ^7.2.1
  connectivity_plus: ^5.0.2
  shared_preferences: ^2.2.2

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0

flutter:
  uses-material-design: true
  assets:
    - assets/fonts/
  fonts:
    - family: Vazirmatn
      fonts:
        - asset: assets/fonts/Vazirmatn-Regular.ttf
'''
        pubspec_path.write_text(correct, encoding='utf-8')
        self.fixed_files.append("pubspec.yaml (wireguard_flutter حذف شد، shared_preferences اضافه شد)")
        return True

    # ------------------------------------------------------------------
    # README.md
    # ------------------------------------------------------------------
    def fix_readme(self) -> bool:
        readme_path = self.root / "README.md"
        correct = '''# OryvexVPN - داشبورد ویندوز

داشبورد اتصال به سرور WireGuard شخصی شما (VPS) - بدون کانفیگ ساختگی.

## قابلیت‌ها
- اتصال/قطع واقعی از طریق WireGuard for Windows
- دریافت کانفیگ از سرور VPS خودتان (نه یک کلید ساختگی محلی)
- وضعیت اتصال از سرویس واقعی ویندوز خوانده می‌شود، هرگز جعلی نیست
- تنظیمات سرور در برنامه (آدرس + توکن)

## نیازمندی‌ها
1. [WireGuard for Windows](https://www.wireguard.com/install/) نصب باشد.
2. برنامه با دسترسی Administrator اجرا شود (نصب/حذف تانل نیاز به ارتقای دسترسی دارد).
3. یک سرور (VPS) با WireGuard فعال که روی مسیر زیر کانفیگ برمی‌گرداند:

   ```
   POST {serverUrl}/api/wireguard/config
   Header: Authorization: Bearer <token>
   Response: { "config": "<متن کامل کانفیگ WireGuard>" }
   ```

## شروع سریع
```bash
flutter pub get
flutter run -d windows
```

## ساخت
```bash
flutter build windows --release
```

## GitHub Actions
با push به شاخه main، برنامه به صورت خودکار ساخته می‌شود.
'''
        readme_path.write_text(correct, encoding='utf-8')
        self.fixed_files.append("README.md")
        return True

    # ------------------------------------------------------------------
    # .github/workflows/build_windows.yml
    # ------------------------------------------------------------------
    def fix_workflow(self) -> bool:
        workflow_path = self.root / ".github" / "workflows" / "build_windows.yml"
        if not workflow_path.exists():
            return False

        correct = '''name: Build Windows App

on:
  push:
    branches: [ main ]
  workflow_dispatch:

env:
  ACTIONS_ALLOW_USE_UNSECURE_NODE_VERSION: true

jobs:
  build:
    runs-on: windows-2022

    steps:
      - uses: actions/checkout@v4

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.24.0'
          channel: 'stable'
          cache: true

      - name: Precache Windows artifacts
        run: flutter precache --windows

      - name: Run flutter doctor
        run: flutter doctor -v

      - name: Enable Windows desktop
        run: flutter config --enable-windows-desktop

      - name: Clean previous builds
        run: flutter clean

      - name: Get dependencies
        run: flutter pub get

      - name: Update Windows Project Files
        run: |
          flutter create --platforms windows --overwrite .
          git checkout lib/ pubspec.yaml README.md

      - name: Get dependencies (again after create)
        run: flutter pub get

      - name: Build Windows app
        run: flutter build windows --release

      - name: Upload build artifacts
        uses: actions/upload-artifact@v4
        with:
          name: oryvexvpn-windows
          path: build/windows/x64/runner/Release/
'''
        workflow_path.write_text(correct, encoding='utf-8')
        self.fixed_files.append("build_windows.yml")
        return True

    # ------------------------------------------------------------------
    # حذف فایل‌های منسوخ (کانفیگ ساختگی قدیمی)
    # ------------------------------------------------------------------
    def remove_obsolete_files(self) -> bool:
        obsolete = [self.root / "lib" / "services" / "warp_generator.dart"]
        for path in obsolete:
            if path.exists():
                path.unlink()
                self.fixed_files.append(f"حذف شد: {path.relative_to(self.root)}")
        return True

    # ------------------------------------------------------------------
    def scrub_tokens(self) -> bool:
        token_regex = re.compile(r'ghp_[A-Za-z0-9_]{36,}')
        modified = False
        for filepath in self.root.rglob('*'):
            if filepath.is_dir() or any(part.startswith('.git') for part in filepath.parts):
                continue
            try:
                content = filepath.read_text(encoding='utf-8')
                new_content, count = token_regex.subn('YOUR_GITHUB_TOKEN', content)
                if count > 0:
                    filepath.write_text(new_content, encoding='utf-8')
                    modified = True
            except Exception:
                pass
        return modified

    def update_gitignore(self) -> bool:
        gi_path = self.root / ".gitignore"
        required = [".env", "*.token", "*.secret", "key.properties", "*.keystore", "*.jks"]
        existing = gi_path.read_text(encoding='utf-8') if gi_path.exists() else ""
        missing = [r for r in required if r not in existing]
        if missing:
            with gi_path.open('a', encoding='utf-8') as f:
                f.write("\n" + "\n".join(missing) + "\n")
            self.fixed_files.append(".gitignore")
        return True

    def run(self) -> bool:
        print("\n" + "=" * 60)
        print("🔧 Flutter Project Fixer - OryvexVPN (اتصال واقعی WireGuard)")
        print("=" * 60)
        print(f"\nمسیر پروژه: {self.root}\n")

        if not self.check_project():
            return False

        self.fix_main_dart()
        self.fix_pubspec()
        self.fix_wireguard_service()
        self.fix_vpn_service()
        self.fix_settings_dialog()
        self.fix_home_screen()
        self.fix_readme()
        self.fix_workflow()
        self.remove_obsolete_files()
        self.scrub_tokens()
        self.update_gitignore()

        print("\n" + "=" * 60)
        print("📊 گزارش نهایی")
        print("=" * 60)
        if self.fixed_files:
            print("\n📁 فایل‌های اصلاح شده:")
            for f in self.fixed_files:
                print(f"  ✓ {f}")

        print("\n⚠️  یادآوری مهم:")
        print("   - برای اتصال واقعی باید WireGuard for Windows نصب باشد.")
        print("   - برنامه باید با دسترسی Administrator اجرا شود.")
        print("   - در تنظیمات برنامه، آدرس و توکن سرور VPS خودتان را وارد کنید.")
        print("\n✅ همه مشکلات برطرف شد. حالا می‌توانید فایل push.py را اجرا کنید.")
        return True


def main():
    try:
        if len(sys.argv) > 1:
            root = sys.argv[1]
        else:
            root = os.getcwd()
        fixer = FlutterProjectFixer(root)
        success = fixer.run()
        sys.exit(0 if success else 1)
    except KeyboardInterrupt:
        print("\n⏹️ عملیات توسط کاربر لغو شد.")
        sys.exit(0)
    except Exception as e:
        print(f"\n❌ خطای غیرمنتظره: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()