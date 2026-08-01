#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
fixer.py - OryvexVPN Auto-Fixer
Implements automatic Cloudflare WARP key generation, endpoint sweeping, 
real WireGuard connection via bundled data/wireguard.exe, Persian UI, 
forced Administrator privileges, and perfectly clean GitHub Actions CI.
"""

import os
import re
import sys
import subprocess
from pathlib import Path
from typing import Optional

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
        self.fixed_files = []

    def log(self, message: str, level: str = "INFO"):
        icons = {
            "INFO": "[i]", "SUCCESS": "[✓]", "WARNING": "[!]",
            "ERROR": "[✗]", "STEP": "[>]", "FIX": "[🔧]"
        }
        print(f"{icons.get(level, '[i]')} {message}")

    def check_project(self) -> bool:
        if not (self.root / "pubspec.yaml").exists():
            self.log("pubspec.yaml not found! Not a Flutter project.", "ERROR")
            return False
        self.log("Flutter project detected.", "SUCCESS")
        return True

    def initialize_windows(self) -> bool:
        self.log("Ensuring Windows platform is initialized cleanly...", "STEP")
        # --overwrite ensures we have a perfectly clean CMake and project structure locally
        subprocess.run("flutter create --platforms windows --overwrite .", shell=True, cwd=self.root, capture_output=True)
        return True

    def fix_main_dart(self) -> bool:
        main_path = self.root / "lib" / "main.dart"
        correct = """import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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
      title: 'اورایوکس وی‌پی‌ان',
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('fa', 'IR'),
      ],
      locale: const Locale('fa', 'IR'),
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF09090B),
        primaryColor: const Color(0xFF00E5FF),
        fontFamily: 'Vazirmatn',
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E5FF),
          surface: Color(0xFF18181B),
        ),
      ),
      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: HomeScreen(),
      ),
    ),
  );
}
"""
        main_path.parent.mkdir(parents=True, exist_ok=True)
        main_path.write_text(correct, encoding='utf-8')
        self.fixed_files.append("main.dart")
        return True

    def fix_warp_service(self) -> bool:
        warp_path = self.root / "lib" / "services" / "warp_service.dart"
        correct = """import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cryptography/cryptography.dart';

class WarpService {
  static const _tunnelName = 'oryvexvpn';
  
  static const List<String> _endpoints = [
    "162.159.192.1", "162.159.193.1", "162.159.195.1",
    "188.114.96.1", "188.114.97.1", "188.114.98.1",
    "8.6.112.165", "8.6.112.139", "8.6.112.178",
    "104.16.248.249", "103.21.244.0"
  ];

  static String get _wireguardExe {
    final exePath = Platform.resolvedExecutable;
    final exeDir = File(exePath).parent.path;
    return '$exeDir\\\\data\\\\wireguard.exe';
  }

  static Future<String> _findBestEndpoint(Function(String) onProgress) async {
    onProgress('در حال جستجوی سریع‌ترین سرور...');
    final futures = _endpoints.map((ip) async {
      try {
        final start = DateTime.now();
        final res = await Process.run('ping', ['-n', '1', '-w', '1000', ip]);
        if (res.exitCode == 0) {
          final latency = DateTime.now().difference(start).inMilliseconds;
          return {'ip': ip, 'latency': latency};
        }
      } catch (_) {}
      return {'ip': ip, 'latency': 9999};
    });

    final results = await Future.wait(futures);
    results.sort((a, b) => (a['latency'] as int).compareTo(b['latency'] as int));
    
    final bestIp = results.first['latency'] != 9999 ? results.first['ip'] as String : _endpoints.first;
    return '$bestIp:2408';
  }

  static Future<String> generateConfig(Function(String) onProgress) async {
    onProgress('در حال ساخت کلید رمزنگاری...');
    final algorithm = X25519();
    final keyPair = await algorithm.newKeyPair();
    final publicKey = await keyPair.extractPublicKey();
    final privateKeyBytes = await keyPair.extractPrivateKeyBytes();

    final pubKeyBase64 = base64Encode(publicKey.bytes);
    final privKeyBase64 = base64Encode(privateKeyBytes);

    onProgress('در حال ثبت‌نام در شبکه...');
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
    final address = data['config']['interface']['addresses']['v4'];
    final peerPublicKey = peer['public_key'];

    final bestEndpoint = await _findBestEndpoint(onProgress);

    onProgress('در حال آماده‌سازی کانفیگ...');
    return '''[Interface]
PrivateKey = $privKeyBase64
Address = $address/32
DNS = 1.1.1.1, 1.0.0.1
MTU = 1280

[Peer]
PublicKey = $peerPublicKey
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = $bestEndpoint
PersistentKeepalive = 25''';
  }

  static Future<File> _writeConfigFile(String config) async {
    final dir = Directory.systemTemp;
    final file = File('${dir.path}\\\\$_tunnelName.conf');
    return file.writeAsString(config);
  }

  static Future<bool> isWireGuardInstalled() async {
    return File(_wireguardExe).exists();
  }

  static Future<void> connect(String config) async {
    if (!Platform.isWindows) {
      throw Exception('این نسخه فقط مخصوص ویندوز است.');
    }
    if (!await isWireGuardInstalled()) {
      throw Exception('هسته وایرگارد در پوشه data یافت نشد. لطفاً برنامه را مجدد دانلود کنید.');
    }

    final file = await _writeConfigFile(config);
    final result = await Process.run(
      _wireguardExe,
      ['/installtunnelservice', file.path],
      runInShell: true,
    );

    if (result.exitCode != 0) {
      throw Exception(
        'نصب تونل ناموفق بود. خطای سیستمی ویندوز:\\n'
        '${result.stderr}'
      );
    }
  }

  static Future<void> disconnect() async {
    if (!Platform.isWindows) return;
    await Process.run(
      _wireguardExe,
      ['/uninstalltunnelservice', _tunnelName],
      runInShell: true,
    );
  }

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
}
"""
        warp_path.parent.mkdir(parents=True, exist_ok=True)
        warp_path.write_text(correct, encoding='utf-8')
        self.fixed_files.append("warp_service.dart")
        return True

    def fix_vpn_service(self) -> bool:
        vpn_path = self.root / "lib" / "services" / "vpn_service.dart"
        correct = """import 'package:flutter/foundation.dart';
import 'warp_service.dart';

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

  VpnStage get stage => _stage;
  bool get isConnected => _stage == VpnStage.connected;
  bool get isConnecting =>
      _stage == VpnStage.fetchingConfig || _stage == VpnStage.installingTunnel;
  String get statusMessage => _statusMessage;
  String? get lastError => _lastError;

  void _updateStatus(String msg) {
    _statusMessage = msg;
    notifyListeners();
  }

  Future<void> initStatus() async {
    if (await WarpService.isConnected()) {
      _stage = VpnStage.connected;
      _statusMessage = 'متصل شد';
      notifyListeners();
    }
  }

  Future<void> connect() async {
    if (isConnecting) return;

    _lastError = null;
    _stage = VpnStage.fetchingConfig;
    notifyListeners();

    try {
      final config = await WarpService.generateConfig(_updateStatus);

      _stage = VpnStage.installingTunnel;
      _updateStatus('در حال اجرای تونل وایرگارد...');

      await WarpService.connect(config);

      final actuallyUp = await WarpService.isConnected();
      if (!actuallyUp) {
        throw Exception('سرویس ویندوز اجرا نشد.');
      }

      _stage = VpnStage.connected;
      _updateStatus('متصل شد');
    } catch (e) {
      _stage = VpnStage.error;
      _lastError = e.toString().replaceFirst('Exception: ', '');
      _updateStatus('اتصال ناموفق بود');
    }
    notifyListeners();
  }

  Future<void> disconnect() async {
    _stage = VpnStage.disconnecting;
    _updateStatus('در حال قطع اتصال...');
    
    await WarpService.disconnect();

    _stage = VpnStage.idle;
    _updateStatus('قطع شد');
  }
}
"""
        vpn_path.parent.mkdir(parents=True, exist_ok=True)
        vpn_path.write_text(correct, encoding='utf-8')
        self.fixed_files.append("vpn_service.dart")
        return True

    def fix_home_screen(self) -> bool:
        home_path = self.root / "lib" / "screens" / "home_screen.dart"
        correct = """import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/vpn_service.dart';

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
      context.read<VPNService>().initStatus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final vpn = context.watch<VPNService>();

    Color getStatusColor() {
      if (vpn.isConnected) return const Color(0xFF00E5FF);
      if (vpn.isConnecting) return const Color(0xFFFF9800);
      if (vpn.stage == VpnStage.error) return const Color(0xFFFF3B30);
      return Colors.white54;
    }

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF09090B), Color(0xFF18181B)],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  child: Row(
                    children: [
                      Icon(
                        vpn.isConnected ? Icons.shield_rounded : Icons.shield_outlined,
                        color: getStatusColor(),
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'اورایوکس',
                        style: TextStyle(
                          fontFamily: 'Vazirmatn',
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const Spacer(flex: 1),
                
                // Status Text
                Text(
                  vpn.statusMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Vazirmatn',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: getStatusColor(),
                  ),
                ),
                if (vpn.lastError != null) ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF3B30).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFF3B30).withOpacity(0.3)),
                      ),
                      child: Text(
                        vpn.lastError!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Vazirmatn',
                          fontSize: 13,
                          height: 1.5,
                          color: Color(0xFFFF3B30),
                        ),
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
                    duration: const Duration(milliseconds: 400),
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF18181B),
                      boxShadow: [
                        BoxShadow(
                          color: getStatusColor().withOpacity(vpn.isConnected || vpn.isConnecting ? 0.4 : 0.0),
                          blurRadius: vpn.isConnected || vpn.isConnecting ? 60 : 20,
                          spreadRadius: vpn.isConnected || vpn.isConnecting ? 10 : 0,
                        ),
                      ],
                      border: Border.all(
                        color: getStatusColor().withOpacity(vpn.isConnected ? 1.0 : (vpn.isConnecting ? 0.8 : 0.1)),
                        width: vpn.isConnected ? 6 : 2,
                      ),
                    ),
                    child: Center(
                      child: vpn.isConnecting
                          ? const SizedBox(
                              width: 60,
                              height: 60,
                              child: CircularProgressIndicator(
                                strokeWidth: 4,
                                color: Color(0xFFFF9800),
                              ),
                            )
                          : Icon(
                              Icons.power_settings_new_rounded,
                              size: 90,
                              color: getStatusColor(),
                            ),
                    ),
                  ),
                ),

                const Spacer(flex: 2),

                // Bottom Status Card
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 400),
                  opacity: vpn.isConnected ? 1.0 : 0.0,
                  child: vpn.isConnected
                      ? Padding(
                          padding: const EdgeInsets.only(bottom: 40, left: 24, right: 24),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
                            decoration: BoxDecoration(
                              color: const Color(0xFF18181B),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.3)),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.security_rounded, color: Color(0xFF00E5FF), size: 22),
                                SizedBox(width: 12),
                                Text(
                                  'تونل وایرگارد فعال و ایمن است',
                                  style: TextStyle(
                                    fontFamily: 'Vazirmatn',
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : const SizedBox(height: 98),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
"""
        home_path.parent.mkdir(parents=True, exist_ok=True)
        home_path.write_text(correct, encoding='utf-8')
        self.fixed_files.append("home_screen.dart")
        return True

    def fix_pubspec(self) -> bool:
        pubspec_path = self.root / "pubspec.yaml"
        correct = """name: warp_vpn_app
description: OryvexVPN - Automatic Connection Dashboard
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
  cryptography: ^2.7.0
  path_provider: ^2.1.1
  permission_handler: ^11.0.1
  provider: ^6.0.5
  share_plus: ^7.2.1
  connectivity_plus: ^5.0.2

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
"""
        pubspec_path.write_text(correct, encoding='utf-8')
        self.fixed_files.append("pubspec.yaml")
        return True
        
    def fix_windows_main_cpp(self) -> bool:
        main_cpp_path = self.root / "windows" / "runner" / "main.cpp"
        if not main_cpp_path.exists():
            return False
        content = main_cpp_path.read_text(encoding='utf-8')
        
        content = content.replace("Win32Window::Size(1280, 720)", "Win32Window::Size(400, 700)")
        content = content.replace("Win32Window::Point(10, 10)", "Win32Window::Point(100, 100)")
        
        main_cpp_path.write_text(content, encoding='utf-8')
        self.fixed_files.append("windows/runner/main.cpp (Resized to 400x700)")
        return True

    def fix_windows_manifest(self) -> bool:
        manifest_path = self.root / "windows" / "runner" / "runner.exe.manifest"
        manifest_path.parent.mkdir(parents=True, exist_ok=True)
        
        correct = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<assembly xmlns="urn:schemas-microsoft-com:asm.v1" manifestVersion="1.0">
  <assemblyIdentity version="1.0.0.0" name="oryvex_vpn_demo" type="win32"/>
  <description>Oryvex VPN</description>
  <trustInfo xmlns="urn:schemas-microsoft-com:asm.v2">
    <security>
      <requestedPrivileges>
        <requestedExecutionLevel level="requireAdministrator" uiAccess="false"/>
      </requestedPrivileges>
    </security>
  </trustInfo>
  <compatibility xmlns="urn:schemas-microsoft-com:compatibility.v1">
    <application>
      <supportedOS Id="{8e0f7a12-bfb3-4fe8-b9a5-48fd50a15a9a}"/>
      <supportedOS Id="{1f676c76-80e1-4239-95bb-83d0f6d0da78}"/>
      <supportedOS Id="{4a2f28e3-53b9-4441-ba9c-d69d4a4a6e38}"/>
    </application>
  </compatibility>
  <application xmlns="urn:schemas-microsoft-com:asm.v3">
    <windowsSettings>
      <dpiAware xmlns="http://schemas.microsoft.com/SMI/2005/WindowsSettings">true</dpiAware>
      <dpiAwareness xmlns="http://schemas.microsoft.com/SMI/2016/WindowsSettings">PerMonitorV2</dpiAwareness>
    </windowsSettings>
  </application>
</assembly>"""
        
        manifest_path.write_text(correct, encoding='utf-8')
        self.fixed_files.append("windows/runner/runner.exe.manifest (Forced UAC Shield Icon & Admin Privileges)")
        return True

    def fix_workflow(self) -> bool:
        workflow_path = self.root / ".github" / "workflows" / "build_windows.yml"
        
        correct = r"""name: Build Windows App

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
          flutter-version: '3.24.0'
          channel: 'stable'
          cache: true

      - name: Enable Windows desktop
        run: flutter config --enable-windows-desktop

      - name: Precache Windows artifacts
        run: flutter precache --windows

      - name: Clean Project
        run: flutter clean

      - name: Install dependencies
        run: flutter pub get

      - name: Build Windows app
        run: flutter build windows --release

      - name: Bundle WireGuard inside data/
        run: |
          $ReleaseDir = "build/windows/x64/runner/Release"
          New-Item -ItemType Directory -Force -Path "$ReleaseDir/data"
          Invoke-WebRequest -Uri "https://download.wireguard.com/windows-client/wireguard-amd64-0.5.3.msi" -OutFile "wg.msi"
          Start-Process -FilePath "msiexec.exe" -ArgumentList "/a `"$PWD/wg.msi`" /qb TARGETDIR=`"$PWD/wg_extract`"" -Wait -NoNewWindow
          if (Test-Path "wg_extract/WireGuard/wireguard.exe") {
            Copy-Item -Path "wg_extract/WireGuard/wireguard.exe" -Destination "$ReleaseDir/data/wireguard.exe"
            Copy-Item -Path "wg_extract/WireGuard/wg.exe" -Destination "$ReleaseDir/data/wg.exe"
            Write-Host "WireGuard successfully bundled in data/ folder."
          } else {
            Write-Host "Failed to extract WireGuard."
            exit 1
          }

      - name: Upload build artifacts
        uses: actions/upload-artifact@v4
        with:
          name: oryvexvpn-windows
          path: build/windows/x64/runner/Release/
"""
        workflow_path.parent.mkdir(parents=True, exist_ok=True)
        workflow_path.write_text(correct, encoding='utf-8')
        self.fixed_files.append("build_windows.yml (Clean CI with Precache)")
        return True

    def remove_obsolete_files(self) -> bool:
        obsolete = [
            self.root / "lib" / "services" / "warp_generator.dart",
            self.root / "lib" / "services" / "wireguard_service.dart",
            self.root / "lib" / "screens" / "settings_dialog.dart"
        ]
        for path in obsolete:
            if path.exists():
                path.unlink()
                self.fixed_files.append(f"Deleted: {path.relative_to(self.root)}")
        return True

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
                f.write("\\n" + "\\n".join(missing) + "\\n")
            self.fixed_files.append(".gitignore")
        return True

    def run(self) -> bool:
        print("\\n" + "=" * 60)
        print("🔧 Flutter Project Fixer - OryvexVPN (Admin Shield Icon & Clean CI Build)")
        print("=" * 60)
        print(f"\\nProject Path: {self.root}\\n")

        if not self.check_project():
            return False

        # First initialize the full windows architecture LOCALLY
        self.initialize_windows()
        
        # Then patch them dynamically to ensure the Admin shield and sizing are applied
        self.fix_windows_main_cpp()
        self.fix_windows_manifest()

        # Update the Dart code and workflow
        self.fix_main_dart()
        self.fix_pubspec()
        self.fix_warp_service()
        self.fix_vpn_service()
        self.fix_home_screen()
        self.fix_workflow()
        self.remove_obsolete_files()
        self.scrub_tokens()
        self.update_gitignore()

        print("\\n" + "=" * 60)
        print("📊 Final Report")
        print("=" * 60)
        if self.fixed_files:
            print("\\n📁 Modified/Added Files:")
            for f in self.fixed_files:
                print(f"  ✓ {f}")

        print("\\n✅ Local files perfectly initialized and patched. You can now execute push.py.")
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
        print("\\n⏹️ Operation cancelled by user.")
        sys.exit(0)
    except Exception as e:
        print(f"\\n❌ Unexpected error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()