#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
fixer.py - OryvexVPN CI-Ready Project Fixer

- Fixes "Access is denied" via PowerShell UAC elevation (RunAs).
- Restores custom window controls (Close/Minimize).
- Applies GoogleFonts (Vazirmatn) and a high-contrast minimalist dark theme.
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

    # 1. Fix Main Dart (RTL + Google Fonts)
    def fix_main_dart(self) -> bool:
        path = self.root / "lib" / "main.dart"
        content = '''import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

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
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        textTheme: GoogleFonts.vazirmatnTextTheme(ThemeData.dark().textTheme),
      ),
      home: const HomeScreen(),
    );
  }
}
'''
        return self._write_if_needed(path, content, "افزودن فونت وزیرمتن و راست‌چین (RTL)", force=True)

    # 2. Fix Home Screen (Add Window Controls & High-Contrast Theme)
    def fix_home_screen(self) -> bool:
        path = self.root / "lib" / "screens" / "home_screen.dart"
        content = '''import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import '../services/vpn_service.dart';
import '../services/window_manager_service.dart';

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

    Color getStatusColor() {
      if (vpn.isConnected) return const Color(0xFF00E5FF); 
      if (vpn.isConnecting) return const Color(0xFF00FFCC); 
      if (vpn.stage == VpnStage.error) return const Color(0xFFFF3366); 
      return const Color(0xFF555555);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A), 
      body: Column(
        children: [
          // Custom Window Controls
          GestureDetector(
            onPanStart: (details) => windowManager.startDragging(),
            child: Container(
              color: Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        vpn.isConnected ? Icons.shield_rounded : Icons.shield_outlined,
                        color: getStatusColor(),
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'اورایوکس',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.minimize, color: Colors.white54, size: 20),
                        onPressed: () => windowManager.minimize(),
                        splashRadius: 20,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 16),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                        onPressed: () => WindowManagerService.quit(),
                        hoverColor: Colors.redAccent,
                        splashRadius: 20,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  )
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
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: getStatusColor(),
                    ),
                  ),
                  if (vpn.lastError != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 32),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF3366).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFF3366).withOpacity(0.3)),
                      ),
                      child: Text(
                        vpn.lastError!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFFFF3366),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 50),
                  
                  // Main Connect Button
                  GestureDetector(
                    onTap: vpn.isConnecting
                        ? null
                        : () => vpn.isConnected ? vpn.disconnect() : vpn.connect(),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF141414),
                        boxShadow: [
                          BoxShadow(
                            color: getStatusColor().withOpacity(vpn.isConnected || vpn.isConnecting ? 0.2 : 0.0),
                            blurRadius: 40,
                            spreadRadius: vpn.isConnected || vpn.isConnecting ? 5 : 0,
                          ),
                        ],
                        border: Border.all(
                          color: getStatusColor().withOpacity(vpn.isConnected ? 0.8 : 0.3),
                          width: vpn.isConnected ? 3 : 1.5,
                        ),
                      ),
                      child: Center(
                        child: vpn.isConnecting
                            ? const SizedBox(
                                width: 50,
                                height: 50,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  color: Color(0xFF00FFCC),
                                ),
                              )
                            : Icon(
                                Icons.power_settings_new_rounded,
                                size: 60,
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
        return self._write_if_needed(path, content, "طراحی رابط کاربری تاریک، افزودن دکمه‌های پنجره", force=True)

    # 3. Fix Warp Service (UAC Elevation via PowerShell)
    def fix_warp_service(self) -> bool:
        path = self.root / "lib" / "services" / "warp_service.dart"
        content = '''import 'dart:io';
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
  static String get _wireguardExe => '$_exeDir\\\\data\\\\wireguard.exe';

  static Future<bool> _coreFilesPresent() async => File(_wireguardExe).exists();

  static Future<String> _confDir() async {
    final dir = await getApplicationSupportDirectory();
    final confDir = Directory('${dir.path}\\\\wireguard');
    if (!await confDir.exists()) await confDir.create(recursive: true);
    return confDir.path;
  }

  static Future<String> _findBestEndpoint(Function(String) onProgress) async {
    onProgress('در حال جستجوی سریع‌ترین سرور...');
    final futures = _endpoints.map((ip) async {
      try {
        final start = DateTime.now();
        final res = await Process.run('ping', ['-n', '1', '-w', '1000', ip]);
        if (res.exitCode == 0) {
          return {'ip': ip, 'latency': DateTime.now().difference(start).inMilliseconds};
        }
      } catch (_) {}
      return {'ip': ip, 'latency': 9999};
    });

    final results = await Future.wait(futures);
    results.sort((a, b) => (a['latency'] as int).compareTo(b['latency'] as int));
    return results.first['latency'] != 9999 ? results.first['ip'] as String : _endpoints.first;
  }

  static Future<_WarpRegistration> _register(Function(String) onProgress) async {
    onProgress('در حال ساخت کلید رمزنگاری...');
    final algorithm = X25519();
    final keyPair = await algorithm.newKeyPair();
    final publicKey = await keyPair.extractPublicKey();
    final privateKeyBytes = await keyPair.extractPrivateKeyBytes();

    final pubKeyBase64 = base64Encode(publicKey.bytes);
    final privKeyBase64 = base64Encode(privateKeyBytes);

    onProgress('در حال ارتباط با کلادفلر...');
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

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('ثبت‌نام دستگاه ناموفق بود.');
    }

    final data = jsonDecode(response.body);
    final peer = data['config']['peers'][0];
    final address = (data['config']['interface']['addresses']['v4'] as String);
    final peerPublicKeyBase64 = peer['public_key'] as String;

    final bestIp = await _findBestEndpoint(onProgress);

    return _WarpRegistration(
      privateKeyBase64: privKeyBase64,
      address: address,
      peerPublicKeyBase64: peerPublicKeyBase64,
      endpointIp: bestIp,
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

  static Future<void> _installTunnelService(_WarpRegistration reg) async {
    final confDir = await _confDir();
    final confFile = File('$confDir\\\\$_tunnelName.conf');
    await confFile.writeAsString(_buildConf(reg));

    // Force UAC Prompt using PowerShell to resolve "Access is denied"
    final uninstallCmd = 'Start-Process -FilePath "$_wireguardExe" -ArgumentList "/uninstalltunnelservice $_tunnelName" -Verb RunAs -WindowStyle Hidden -Wait';
    await Process.run('powershell', ['-NoProfile', '-Command', uninstallCmd]);
    await Future.delayed(const Duration(milliseconds: 500));

    final installCmd = 'Start-Process -FilePath "$_wireguardExe" -ArgumentList "/installtunnelservice `"${confFile.path}`"" -Verb RunAs -WindowStyle Hidden -Wait';
    final result = await Process.run('powershell', ['-NoProfile', '-Command', installCmd]);

    if (result.exitCode != 0) {
      throw Exception('اتصال لغو شد یا دسترسی ادمین (UAC) داده نشد.');
    }
    await Future.delayed(const Duration(seconds: 1));
  }

  static Future<void> connectWithProgress(Function(String) onProgress) async {
    if (!await _coreFilesPresent()) throw Exception('فایل هسته (wireguard.exe) یافت نشد.');
    final reg = await _register(onProgress);
    onProgress('درخواست دسترسی مدیریت (UAC)...');
    await _installTunnelService(reg);
    _connected = true;
  }

  static Future<void> connect() async => await connectWithProgress((_) {});

  static Future<void> disconnect() async {
    if (!Platform.isWindows) return;
    try {
      final uninstallCmd = 'Start-Process -FilePath "$_wireguardExe" -ArgumentList "/uninstalltunnelservice $_tunnelName" -Verb RunAs -WindowStyle Hidden -Wait';
      await Process.run('powershell', ['-NoProfile', '-Command', uninstallCmd]);
    } catch (_) {}
    _connected = false;
  }

  static Future<bool> isConnected() async {
    if (!Platform.isWindows || !_connected) return false;
    final result = await Process.run('sc', ['query', 'WireGuardTunnel\\\\$$_tunnelName']);
    return result.exitCode == 0 && result.stdout.toString().contains('RUNNING');
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
        return self._write_if_needed(path, content, "افزودن دریافت دسترسی UAC برای رفع ارور Access is denied", force=True)

    # 4. Fix Pubspec Dependencies
    def fix_pubspec_dependencies(self) -> bool:
        path = self.root / "pubspec.yaml"
        if not path.exists(): return False

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
            "google_fonts": "^6.1.0",
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
        missing = {name: ver for name, ver in required_deps.items() if re.search(rf'^\s*{re.escape(name)}\s*:', block, re.MULTILINE) is None}

        if not missing: return False

        insertion = "\n".join(f"  {name}: {ver}" for name, ver in missing.items())
        new_lines = lines[:end_idx] + [insertion] + lines[end_idx:]
        path.write_text("\n".join(new_lines) + "\n", encoding='utf-8')
        self.fixed_files.append(f"pubspec.yaml (افزودن کتابخانه‌های: {', '.join(missing.keys())})")
        return True

    def fix_sdk_constraint(self) -> bool:
        pubspec = self.root / "pubspec.yaml"
        if pubspec.exists():
            text = pubspec.read_text(encoding='utf-8')
            new_text, count = re.subn(r"sdk:\s*['\"][^'\"]*['\"]", "sdk: '>=3.0.0 <4.0.0'", text, count=1)
            if count > 0 and new_text != text:
                pubspec.write_text(new_text, encoding='utf-8')
                self.fixed_files.append("pubspec.yaml (اصلاح رنج نسخه Dart)")
                return True
        return False

    def run(self) -> bool:
        print("\n" + "=" * 64)
        print("OryvexVPN UAC & UI Fixer")
        print("=" * 64)
        
        if not self.check_project(): return False

        self.fix_main_dart()
        self.fix_home_screen()
        self.fix_warp_service()
        self.fix_pubspec_dependencies()
        self.fix_sdk_constraint()

        print("\nکار تمام است! کدها را در گیت‌هاب Push کنید تا مشکل دسترسی (UAC) و طراحی UI برطرف شود.")
        return True

if __name__ == "__main__":
    fixer = FlutterProjectFixer(sys.argv[1] if len(sys.argv) > 1 else os.getcwd())
    fixer.run()