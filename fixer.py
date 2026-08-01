#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
fixer.py - OryvexVPN Ultimate Core & UI Fixer

- رفع مشکل UAC (درخواست ادمین در شروع خود برنامه به جای زمان اتصال)
- رفع خطای Not Responding هنگام خروج (بستن تمیز تونل قبل از خروج)
- اجرای مستقیم و سریع هسته AmneziaWG بدون PowerShell
- طراحی UI/UX نئون فیروزه‌ای منطبق بر تصویر درخواستی
"""

import os
import re
import sys
from pathlib import Path
from typing import Optional, List

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

    def log(self, message: str, level: str = "INFO"):
        icons = {"INFO": "[i]", "SUCCESS": "[OK]", "WARNING": "[!]", "ERROR": "[X]", "FIX": "[FIX]"}
        print(f"{icons.get(level, '[i]')} {message}")

    def _write_if_needed(self, path: Path, content: str, reason: str, force: bool = False):
        path.parent.mkdir(parents=True, exist_ok=True)
        rel = str(path.relative_to(self.root)) if self._is_relative(path) else str(path)
        
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
        return True

    # 1. تغییر فایل Manifest ویندوز برای درخواست UAC در زمان اجرای اپلیکیشن
    def fix_windows_manifest(self) -> bool:
        path = self.root / "windows" / "runner" / "app.manifest"
        if not path.exists(): return False

        content = path.read_text(encoding='utf-8')
        new_content = re.sub(r'level="asInvoker"', r'level="requireAdministrator"', content)

        if new_content != content:
            path.write_text(new_content, encoding='utf-8')
            self.fixed_files.append("windows/runner/app.manifest (ارتقا سطح دسترسی به Administrator در اجرای اولیه برنامه)")
            return True
        return False

    # 2. مدیریت رویداد بسته شدن پنجره در Main برای جلوگیری از Not Responding
    def fix_main_dart(self) -> bool:
        path = self.root / "lib" / "main.dart"
        content = r'''import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:window_manager/window_manager.dart';

import 'core/config.dart';
import 'screens/home_screen.dart';
import 'services/network_manager.dart';
import 'services/tray_service.dart';
import 'services/window_manager_service.dart';
import 'services/vpn_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await WindowManagerService.init();
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

class _OryvexVPNAppState extends State<OryvexVPNApp> with WindowListener {
  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      TrayService.instance.init();
    });
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    TrayService.instance.dispose();
    NetworkManager.instance.dispose();
    super.dispose();
  }

  // جلوگیری از هنگ کردن با متوقف کردن تمیز تونل پیش از بسته شدن پنجره
  @override
  void onWindowClose() async {
    final vpn = context.read<VPNService>();
    if (vpn.isConnected || vpn.isConnecting) {
      await vpn.disconnect();
    }
    await windowManager.destroy(); // خروج قطعی
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl, // چینش راست‌چین مانند تصویر
          child: child!,
        );
      },
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F0F0F), // پس‌زمینه دارک مینیمال
        fontFamily: GoogleFonts.vazirmatn().fontFamily,
        textTheme: GoogleFonts.vazirmatnTextTheme(ThemeData.dark().textTheme),
      ),
      home: const HomeScreen(),
    );
  }
}
'''
        return self._write_if_needed(path, content, "مدیریت WindowListener برای جلوگیری از هنگ کردن هنگام خروج", force=True)

    # 3. طراحی UI نئون فیروزه‌ای مطابق با تصویر شما
    def fix_home_screen(self) -> bool:
        path = self.root / "lib" / "screens" / "home_screen.dart"
        content = r'''import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import '../services/vpn_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VPNService>().initStatus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final vpn = context.watch<VPNService>();

    // رنگ فیروزه‌ای (Neon Cyan) مشابه تصویر
    Color getStatusColor() {
      if (vpn.isConnected) return const Color(0xFF00E5FF); 
      if (vpn.isConnecting) return const Color(0xFF00E5FF).withOpacity(0.7); 
      if (vpn.stage == VpnStage.error) return const Color(0xFFFF3366); 
      return const Color(0xFF333333); // رنگ حالت خاموش
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F), 
      body: Column(
        children: [
          // Header (Title & Controls)
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onPanStart: (details) => windowManager.startDragging(),
            child: Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // سمت راست (چون RTL است، اولین آیتم‌ها سمت راست قرار می‌گیرند)
                  Row(
                    children: [
                      const Text(
                        'اورایوکس',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        vpn.isConnected ? Icons.shield_rounded : Icons.shield_outlined,
                        color: const Color(0xFF00E5FF),
                        size: 24,
                      ),
                    ],
                  ),
                  // سمت چپ (دکمه‌های کنترل)
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.minimize, color: Colors.white54, size: 20),
                        onPressed: () => windowManager.minimize(),
                        hoverColor: Colors.white10,
                        splashRadius: 20,
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                        onPressed: () => windowManager.close(), // ارسال تریگر به onWindowClose
                        hoverColor: Colors.redAccent.withOpacity(0.5),
                        splashRadius: 20,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    vpn.statusMessage,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: getStatusColor(),
                    ),
                  ),
                  const SizedBox(height: 40),
                  
                  // Main Connect Button (Neon Outline)
                  GestureDetector(
                    onTap: vpn.isConnecting
                        ? null
                        : () => vpn.isConnected ? vpn.disconnect() : vpn.connect(),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 170,
                      height: 170,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF141414),
                        boxShadow: [
                          BoxShadow(
                            color: getStatusColor().withOpacity(vpn.isConnected || vpn.isConnecting ? 0.15 : 0.0),
                            blurRadius: 50,
                            spreadRadius: 10,
                          ),
                        ],
                        border: Border.all(
                          color: getStatusColor().withOpacity(vpn.isConnected ? 1.0 : 0.4),
                          width: vpn.isConnected ? 3 : 2,
                        ),
                      ),
                      child: Center(
                        child: vpn.isConnecting
                            ? const SizedBox(
                                width: 50,
                                height: 50,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  color: Color(0xFF00E5FF),
                                ),
                              )
                            : Icon(
                                Icons.power_settings_new_rounded,
                                size: 65,
                                color: getStatusColor(),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
'''
        return self._write_if_needed(path, content, "طراحی استایل Neon Cyan و چیدمان دکمه‌ها مشابه تصویر", force=True)

    # 4. اجرای مستقیم هسته AmneziaWG (بدون PowerShell چون خود اپلیکیشن دسترسی ادمین دارد)
    def fix_warp_service(self) -> bool:
        path = self.root / "lib" / "services" / "warp_service.dart"
        content = r'''import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cryptography/cryptography.dart';
import 'package:path_provider/path_provider.dart';

class WarpService {
  static const _tunnelName = 'oryvexvpn';
  static bool _connected = false;

  static const List<String> _endpoints = [
    "162.159.192.1", "162.159.192.2", "162.159.193.1", "162.159.193.5",
    "188.114.96.0", "188.114.96.1", "188.114.97.1", "188.114.98.1"
  ];

  static String get _exeDir => File(Platform.resolvedExecutable).parent.path;
  static String get _vpnExe => '$_exeDir\\data\\amneziawg.exe';

  static Future<bool> _coreFilesPresent() async => File(_vpnExe).exists();

  static Future<String> _confDir() async {
    final dir = await getApplicationSupportDirectory();
    final confDir = Directory('${dir.path}\\amneziawg');
    if (!await confDir.exists()) await confDir.create(recursive: true);
    return confDir.path;
  }

  static Future<String> _findBestEndpoint(Function(String) onProgress) async {
    onProgress('در حال یافتن سرور...');
    final futures = _endpoints.map((ip) async {
      try {
        final start = DateTime.now();
        final res = await Process.run('ping', ['-n', '1', '-w', '1000', ip]);
        if (res.exitCode == 0) return {'ip': ip, 'latency': DateTime.now().difference(start).inMilliseconds};
      } catch (_) {}
      return {'ip': ip, 'latency': 9999};
    });

    final results = await Future.wait(futures);
    results.sort((a, b) => (a['latency'] as int).compareTo(b['latency'] as int));
    return results.first['latency'] != 9999 ? results.first['ip'] as String : _endpoints.first;
  }

  static Future<_WarpRegistration> _register(Function(String) onProgress) async {
    final algorithm = X25519();
    final keyPair = await algorithm.newKeyPair();
    final publicKey = await keyPair.extractPublicKey();
    final privateKeyBytes = await keyPair.extractPrivateKeyBytes();

    final pubKeyBase64 = base64Encode(publicKey.bytes);
    final privKeyBase64 = base64Encode(privateKeyBytes);

    onProgress('ارتباط با کلادفلر...');
    final response = await http.post(
      Uri.parse('https://api.cloudflareclient.com/v0a737/reg'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "key": pubKeyBase64,
        "install_id": "",
        "warp_enabled": true,
        "tos": DateTime.now().toUtc().toIso8601String(),
        "type": "Windows",
        "locale": "fa_IR"
      }),
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200 && response.statusCode != 201) throw Exception('ثبت‌نام ناموفق بود.');

    final data = jsonDecode(response.body);
    final peer = data['config']['peers'][0];
    final address = (data['config']['interface']['addresses']['v4'] as String);

    return _WarpRegistration(
      privateKeyBase64: privKeyBase64,
      address: address,
      peerPublicKeyBase64: peer['public_key'] as String,
      endpointIp: await _findBestEndpoint(onProgress),
      endpointPort: '2408',
    );
  }

  static String _buildConf(_WarpRegistration reg) {
    final b = StringBuffer();
    b.writeln('[Interface]');
    b.writeln('PrivateKey = ${reg.privateKeyBase64}');
    b.writeln('Address = ${reg.address}');
    b.writeln('DNS = 1.1.1.1');
    b.writeln('');
    b.writeln('[Peer]');
    b.writeln('PublicKey = ${reg.peerPublicKeyBase64}');
    b.writeln('Endpoint = ${reg.endpointIp}:${reg.endpointPort}');
    b.writeln('AllowedIPs = 0.0.0.0/0');
    b.writeln('PersistentKeepalive = 25');
    return b.toString();
  }

  static Future<bool> _serviceExists() async {
    final result = await Process.run('sc', ['query', 'AmneziaWGTunnel\$$_tunnelName']);
    return result.exitCode == 0;
  }

  static Future<void> _installTunnelService(_WarpRegistration reg) async {
    final confDir = await _confDir();
    final confFile = File('$confDir\\$_tunnelName.conf');
    await confFile.writeAsString(_buildConf(reg));

    // از آنجا که برنامه دسترسی ادمین دارد، مستقیما بدون PowerShell فراخوانی می‌کنیم
    if (await _serviceExists()) {
      await Process.run(_vpnExe, ['/uninstalltunnelservice', _tunnelName]);
      await Future.delayed(const Duration(milliseconds: 300));
    }

    final result = await Process.run(_vpnExe, ['/installtunnelservice', confFile.path]);
    if (result.exitCode != 0) throw Exception('خطا در اجرای سرویس هسته.');
    
    await Future.delayed(const Duration(milliseconds: 500));
  }

  static Future<void> connectWithProgress(Function(String) onProgress) async {
    if (!await _coreFilesPresent()) throw Exception('فایل هسته (amneziawg.exe) یافت نشد.');
    final reg = await _register(onProgress);
    onProgress('اجرای تونل...');
    await _installTunnelService(reg);
    _connected = true;
  }

  static Future<void> connect() async => await connectWithProgress((_) {});

  static Future<void> disconnect() async {
    if (!Platform.isWindows) return;
    try {
      if (await _serviceExists()) {
        await Process.run(_vpnExe, ['/uninstalltunnelservice', _tunnelName]);
      }
    } catch (_) {}
    _connected = false;
  }

  static Future<bool> isConnected() async {
    if (!Platform.isWindows || !_connected) return false;
    return await _serviceExists();
  }
}

class _WarpRegistration {
  final String privateKeyBase64, address, peerPublicKeyBase64, endpointIp, endpointPort;
  const _WarpRegistration({
    required this.privateKeyBase64, required this.address, required this.peerPublicKeyBase64,
    required this.endpointIp, required this.endpointPort,
  });
}
'''
        return self._write_if_needed(path, content, "اجرای مستقیم AmneziaWG (بدون PowerShell و تأخیر)", force=True)

    def fix_window_manager_service(self) -> bool:
        path = self.root / "lib" / "services" / "window_manager_service.dart"
        content = r'''import 'dart:io';
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
      // جلوگیری از بسته شدن فوری پنجره تا بتوانیم در رویداد onWindowClose فرآیند VPN را متوقف کنیم
      await windowManager.setPreventClose(true); 
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
    await windowManager.close(); // ارجاع به Listener خروج تمیز
  }
}
'''
        return self._write_if_needed(path, content, "اعمال PreventClose برای خروج تمیز (جلوگیری از Not Responding)", force=True)

    def fix_ci_workflow(self) -> bool:
        path = self.root / ".github" / "workflows" / "build_windows.yml"
        if not path.parent.exists(): path.parent.mkdir(parents=True, exist_ok=True)
        content = r'''name: Build Windows App (AmneziaWG Core)

on:
  push:
    branches: [ main ]
  workflow_dispatch:

jobs:
  build:
    runs-on: windows-2022

    steps:
      - uses: actions/checkout@v4

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.44.2'
          channel: 'stable'
          cache: true

      - name: Enable Windows desktop
        run: flutter config --enable-windows-desktop

      - name: Get dependencies
        run: flutter pub get

      - name: Build Windows app
        run: flutter build windows --release

      - name: Download and extract AmneziaWG
        run: |
          $wgVersion = "2.0.2"
          $msiUrl = "https://github.com/amnezia-vpn/amneziawg-windows-client/releases/download/$wgVersion/amneziawg-amd64-$wgVersion.msi"
          Invoke-WebRequest -Uri $msiUrl -OutFile "amneziawg.msi"
          
          $extractDir = "$PWD\amneziawg_extracted"
          New-Item -ItemType Directory -Force -Path $extractDir | Out-Null
          
          $msiExecArgs = @("/a", "`"$PWD\amneziawg.msi`"", "/qn", "TARGETDIR=`"$extractDir`"")
          Start-Process msiexec.exe -ArgumentList $msiExecArgs -Wait -NoNewWindow
          
          $wgExe = Get-ChildItem -Path $extractDir -Filter "amneziawg.exe" -Recurse | Select-Object -First 1
          if (-not $wgExe) {
            Write-Host "Failed to extract amneziawg.exe from MSI."
            exit 1
          }
          Write-Host "Found amneziawg.exe at: $($wgExe.FullName)"
          Copy-Item $wgExe.FullName "$PWD\amneziawg.exe"

      - name: Bundle AmneziaWG binary inside data/
        run: |
          $ReleaseDir = "build\windows\x64\runner\Release"
          New-Item -ItemType Directory -Force -Path "$ReleaseDir\data" | Out-Null
          Copy-Item "$PWD\amneziawg.exe" "$ReleaseDir\data\amneziawg.exe"

      - name: Upload build artifacts
        uses: actions/upload-artifact@v4
        with:
          name: oryvexvpn-windows
          path: build/windows/x64/runner/Release/
'''
        return self._write_if_needed(path, content, "اطمینان از دریافت هسته AmneziaWG در گیت‌هاب اکشنز", force=True)

    def run(self) -> bool:
        print("\n" + "=" * 64)
        print("OryvexVPN - Ultimate System Integrator (UI + Core + Hang Fix)")
        print("=" * 64)
        
        if not self.check_project(): return False

        self.fix_windows_manifest()
        self.fix_ci_workflow()
        self.fix_main_dart()
        self.fix_home_screen()
        self.fix_warp_service()
        self.fix_window_manager_service()

        print("\nکار تمام است! کدها را در گیت‌هاب Push کنید.")
        return True

if __name__ == "__main__":
    fixer = FlutterProjectFixer(sys.argv[1] if len(sys.argv) > 1 else os.getcwd())
    fixer.run()