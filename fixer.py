#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
fixer.py - OryvexVPN Auto-Fixer (Access Denied / Tunnel Install Fix)

Fixes the "نصب تونل ناموفق بود ... Access is denied" error by:
  1. Setting the app manifest to requireAdministrator so the whole app
     runs elevated once (no extra UAC prompt for wireguard.exe).
  2. Removing the PowerShell elevation layer – directly calling
     wireguard.exe with Process.run since the app is already admin.
  3. Expanding the endpoint list and using concurrent ping scanning
     to find the best server, improving connection success.
  4. Fixing disconnect by ensuring the uninstall command can run
     without permission issues.
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
        """
        Rewrite warp_service.dart with:

        - Direct Process.run calls (no PowerShell elevation) because
          the app now runs as admin via manifest.
        - Much larger endpoint list and concurrent ping scanning.
        - Proper disconnect (uninstall tunnel) that actually works.
        - Verify the service is running after install.
        """
        warp_path = self.root / "lib" / "services" / "warp_service.dart"
        correct = r"""import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cryptography/cryptography.dart';

class WarpService {
  static const _tunnelName = 'oryvexvpn';

  // Expanded endpoint list (same as your Python script)
  static const List<String> _endpoints = [
    // Original 8.6.112.x
    "8.6.112.165", "8.6.112.139", "8.6.112.178", "8.6.112.205",
    "8.6.112.176", "8.6.112.190", "8.6.112.121", "8.6.112.202",
    "8.6.112.223", "8.6.112.230", "8.6.112.200", "8.6.112.233",
    "8.6.112.4", "8.6.112.159", "8.6.112.93", "8.6.112.182",
    "8.6.112.133", "8.6.112.52", "8.6.112.78", "8.6.112.248",
    "8.6.112.246", "8.6.112.172", "8.6.112.104", "8.6.112.249",
    "8.6.112.46", "8.6.112.234", "8.6.112.136", "8.6.112.224",
    "8.6.112.251", "8.6.112.127", "8.6.112.237", "8.6.112.82",
    "8.6.112.170", "8.6.112.29", "8.6.112.7", "8.6.112.67",
    "188.114.97.6", "8.6.112.235", "8.6.112.228", "8.6.112.19",
    "8.6.112.184", "8.6.112.51", "8.6.112.8", "8.6.112.253",
    "8.6.112.221", "8.6.112.96", "8.6.112.174", "8.6.112.212",
    "8.6.112.154", "8.6.112.65", "8.6.112.171", "8.6.112.160",
    "8.6.112.86", "8.6.112.163", "8.6.112.122", "8.6.112.70",
    "8.6.112.53", "8.6.112.181", "8.6.112.191", "8.6.112.79",
    "8.6.112.180", "8.6.112.61", "8.6.112.77", "8.6.112.107",
    "8.6.112.106", "8.6.112.60",
    // 8.6.112.x with port 2408
    "8.6.112.1", "8.6.112.2", "8.6.112.3", "8.6.112.5",
    "8.6.112.6", "8.6.112.9", "8.6.112.10", "8.6.112.11",
    "8.6.112.12", "8.6.112.13", "8.6.112.14", "8.6.112.15",
    "8.6.112.16", "8.6.112.17", "8.6.112.18", "8.6.112.20",
    "8.6.112.21", "8.6.112.22", "8.6.112.23", "8.6.112.24",
    "8.6.112.25", "8.6.112.26", "8.6.112.27", "8.6.112.28",
    "8.6.112.30", "8.6.112.31", "8.6.112.32", "8.6.112.33",
    "8.6.112.34", "8.6.112.35", "8.6.112.36", "8.6.112.37",
    "8.6.112.38", "8.6.112.39", "8.6.112.40", "8.6.112.41",
    "8.6.112.42", "8.6.112.43", "8.6.112.44", "8.6.112.45",
    "8.6.112.47", "8.6.112.48", "8.6.112.49", "8.6.112.50",
    "8.6.112.54", "8.6.112.55", "8.6.112.56", "8.6.112.57",
    "8.6.112.58", "8.6.112.59", "8.6.112.62", "8.6.112.63",
    "8.6.112.64", "8.6.112.66", "8.6.112.68", "8.6.112.69",
    "8.6.112.71", "8.6.112.72", "8.6.112.73", "8.6.112.74",
    "8.6.112.75", "8.6.112.76", "8.6.112.80", "8.6.112.81",
    "8.6.112.83", "8.6.112.84", "8.6.112.85", "8.6.112.87",
    "8.6.112.88", "8.6.112.89", "8.6.112.90", "8.6.112.91",
    "8.6.112.92", "8.6.112.94", "8.6.112.95", "8.6.112.97",
    "8.6.112.98", "8.6.112.99", "8.6.112.100", "8.6.112.101",
    "8.6.112.102", "8.6.112.103", "8.6.112.105", "8.6.112.108",
    "8.6.112.109", "8.6.112.110", "8.6.112.111", "8.6.112.112",
    "8.6.112.113", "8.6.112.114", "8.6.112.115", "8.6.112.116",
    "8.6.112.117", "8.6.112.118", "8.6.112.119", "8.6.112.120",
    "8.6.112.123", "8.6.112.124", "8.6.112.125", "8.6.112.126",
    "8.6.112.128", "8.6.112.129", "8.6.112.130", "8.6.112.131",
    "8.6.112.132", "8.6.112.134", "8.6.112.135", "8.6.112.137",
    "8.6.112.138", "8.6.112.140", "8.6.112.141", "8.6.112.142",
    "8.6.112.143", "8.6.112.144", "8.6.112.145", "8.6.112.146",
    "8.6.112.147", "8.6.112.148", "8.6.112.149", "8.6.112.150",
    "8.6.112.151", "8.6.112.152", "8.6.112.153", "8.6.112.155",
    "8.6.112.156", "8.6.112.157", "8.6.112.158", "8.6.112.161",
    "8.6.112.162", "8.6.112.164", "8.6.112.166", "8.6.112.167",
    "8.6.112.168", "8.6.112.169", "8.6.112.173", "8.6.112.175",
    "8.6.112.177", "8.6.112.179", "8.6.112.183", "8.6.112.185",
    "8.6.112.186", "8.6.112.187", "8.6.112.188", "8.6.112.189",
    "8.6.112.192", "8.6.112.193", "8.6.112.194", "8.6.112.195",
    "8.6.112.196", "8.6.112.197", "8.6.112.198", "8.6.112.199",
    "8.6.112.201", "8.6.112.203", "8.6.112.204", "8.6.112.206",
    "8.6.112.207", "8.6.112.208", "8.6.112.209", "8.6.112.210",
    "8.6.112.211", "8.6.112.213", "8.6.112.214", "8.6.112.215",
    "8.6.112.216", "8.6.112.217", "8.6.112.218", "8.6.112.219",
    "8.6.112.220", "8.6.112.222", "8.6.112.225", "8.6.112.226",
    "8.6.112.227", "8.6.112.229", "8.6.112.231", "8.6.112.232",
    "8.6.112.236", "8.6.112.238", "8.6.112.239", "8.6.112.240",
    "8.6.112.241", "8.6.112.242", "8.6.112.243", "8.6.112.244",
    "8.6.112.245", "8.6.112.247", "8.6.112.250", "8.6.112.252",
    "8.6.112.254", "8.6.112.255",
    // Cloudflare Anycast
    "162.159.192.1", "162.159.192.2", "162.159.193.1", "162.159.193.5",
    "162.159.195.1", "162.159.195.2", "162.159.195.5",
    // 188.114.x.x
    "188.114.96.0", "188.114.96.1", "188.114.96.2", "188.114.96.3",
    "188.114.96.4", "188.114.96.5", "188.114.97.0", "188.114.97.1",
    "188.114.97.2", "188.114.97.3", "188.114.97.4", "188.114.97.5",
    "188.114.98.0", "188.114.98.1", "188.114.98.2", "188.114.99.0",
    "188.114.99.1", "188.114.99.2", "188.114.97.6",
    // 104.x.x.x
    "104.16.248.249", "104.16.249.249", "104.17.248.249", "104.17.249.249",
    "104.18.0.0", "104.18.1.0", "104.18.2.0", "104.18.3.0",
    // 141.101.x.x
    "141.101.64.0", "141.101.65.0", "141.101.66.0", "141.101.67.0",
    "141.101.68.0", "141.101.69.0", "141.101.70.0", "141.101.71.0",
    // 173.245.x.x
    "173.245.48.0", "173.245.49.0", "173.245.50.0", "173.245.51.0",
    "173.245.52.0", "173.245.53.0", "173.245.54.0", "173.245.55.0",
    // 103.x.x.x
    "103.21.244.0", "103.21.245.0", "103.21.246.0", "103.21.247.0",
    "103.22.200.0", "103.22.201.0", "103.22.202.0", "103.22.203.0",
    "103.31.4.0", "103.31.5.0", "103.31.6.0", "103.31.7.0",
  ];

  static String get _wireguardExe {
    final exePath = Platform.resolvedExecutable;
    final exeDir = File(exePath).parent.path;
    return '$exeDir\\data\\wireguard.exe';
  }

  /// Concurrent ping scan to find the fastest endpoint.
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
    // Use default port 2408 (WireGuard standard)
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
    final file = File('${dir.path}\\$_tunnelName.conf');
    return file.writeAsString(config);
  }

  static Future<bool> isWireGuardInstalled() async {
    return File(_wireguardExe).exists();
  }

  /// Direct execution – app must be running as admin (manifest enforces this).
  static Future<void> _runWireGuard(List<String> args) async {
    final result = await Process.run(
      _wireguardExe,
      args,
      runInShell: false,
    );
    if (result.exitCode != 0) {
      final stderrText = (result.stderr ?? '').toString().trim();
      final stdoutText = (result.stdout ?? '').toString().trim();
      final detail = [stderrText, stdoutText].where((s) => s.isNotEmpty).join(' | ');
      throw Exception(
        'اجرای وایرگارد ناموفق بود (کد: ${result.exitCode})${detail.isNotEmpty ? '\nجزئیات: $detail' : ''}',
      );
    }
  }

  static Future<void> connect(String config) async {
    if (!Platform.isWindows) {
      throw Exception('این نسخه فقط مخصوص ویندوز است.');
    }
    if (!await isWireGuardInstalled()) {
      throw Exception('هسته وایرگارد در پوشه data یافت نشد. لطفاً برنامه را مجدد دانلود کنید.');
    }

    final file = await _writeConfigFile(config);

    try {
      await _runWireGuard(['/installtunnelservice', file.path]);
    } catch (e) {
      throw Exception(
        'نصب تونل ناموفق بود. مطمئن شوید برنامه با دسترسی ادمین اجرا شده است.\n$e',
      );
    }

    // Verify the service is actually running
    final isUp = await isConnected();
    if (!isUp) {
      throw Exception('سرویس وایرگارد پس از نصب شروع نشد.');
    }
  }

  static Future<void> disconnect() async {
    if (!Platform.isWindows) return;
    try {
      await _runWireGuard(['/uninstalltunnelservice', _tunnelName]);
    } catch (e) {
      // If the tunnel wasn't installed, ignore the error
      if (e.toString().contains('The system cannot find the file specified') ||
          e.toString().contains('service does not exist')) {
        return;
      }
      // Rethrow other errors so the UI can show them
      rethrow;
    }
  }

  static Future<bool> isConnected() async {
    if (!Platform.isWindows) return false;
    try {
      final result = await Process.run(
        'sc.exe',
        ['query', 'WireGuardTunnel\$' + _tunnelName],
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
        self.fixed_files.append("warp_service.dart (direct admin calls + huge endpoint list)")
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
      _updateStatus('در حال نصب تونل...');

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

    try {
      await WarpService.disconnect();
      _stage = VpnStage.idle;
      _updateStatus('قطع شد');
    } catch (e) {
      _stage = VpnStage.error;
      _lastError = e.toString().replaceFirst('Exception: ', '');
      _updateStatus('قطع اتصال ناموفق بود');
    }
    notifyListeners();
  }
}
"""
        vpn_path.parent.mkdir(parents=True, exist_ok=True)
        vpn_path.write_text(correct, encoding='utf-8')
        self.fixed_files.append("vpn_service.dart")
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
        if not manifest_path.exists():
            self.log("Manifest not found! Ensure initialization worked.", "ERROR")
            return False
        content = manifest_path.read_text(encoding='utf-8')
        new_content = re.sub(r'level="asInvoker"', 'level="requireAdministrator"', content)
        if content != new_content:
            manifest_path.write_text(new_content, encoding='utf-8')
            self.fixed_files.append("windows/runner/runner.exe.manifest (requireAdministrator)")
            return True
        return False

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

      - name: Get dependencies
        run: flutter pub get

      - name: Build Windows app
        run: flutter build windows --release

      - name: Bundle WireGuard inside data/
        run: |
          $ReleaseDir = "build\windows\x64\runner\Release"
          New-Item -ItemType Directory -Force -Path "$ReleaseDir\data"
          Invoke-WebRequest -Uri "https://download.wireguard.com/windows-client/wireguard-amd64-0.5.3.msi" -OutFile "wg.msi"
          Start-Process -FilePath "msiexec.exe" -ArgumentList "/a `"$PWD\wg.msi`" /qb TARGETDIR=`"$PWD\wg_extract`"" -Wait -NoNewWindow
          if (Test-Path "wg_extract\WireGuard\wireguard.exe") {
            Copy-Item -Path "wg_extract\WireGuard\wireguard.exe" -Destination "$ReleaseDir\data\wireguard.exe"
            Copy-Item -Path "wg_extract\WireGuard\wg.exe" -Destination "$ReleaseDir\data\wg.exe"
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
        self.fixed_files.append("build_windows.yml (unchanged, clean CI build)")
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
                f.write("\n" + "\n".join(missing) + "\n")
            self.fixed_files.append(".gitignore")
        return True

    def run(self) -> bool:
        print("\n" + "=" * 60)
        print("🔧 Flutter Project Fixer - OryvexVPN (Admin + Disconnect + Endpoint Fix)")
        print("=" * 60)
        print(f"\nProject Path: {self.root}\n")

        if not self.check_project():
            return False

        self.initialize_windows()

        self.fix_windows_main_cpp()
        self.fix_windows_manifest()

        self.fix_main_dart()
        self.fix_pubspec()
        self.fix_warp_service()
        self.fix_vpn_service()
        self.fix_workflow()
        self.remove_obsolete_files()
        self.scrub_tokens()
        self.update_gitignore()

        print("\n" + "=" * 60)
        print("📊 Final Report")
        print("=" * 60)
        if self.fixed_files:
            print("\n📁 Modified/Added Files:")
            for f in self.fixed_files:
                print(f"  ✓ {f}")

        print("\n✅ Fixes applied:")
        print("  • App manifest set to requireAdministrator – app runs elevated once.")
        print("  • wireguard.exe now called directly (no extra UAC prompt).")
        print("  • Endpoint list expanded to 300+ IPs with concurrent ping scan.")
        print("  • Disconnect now actually uninstalls the tunnel service.")
        print("  • Connection verifies the service is running after install.")
        print("\nRun push.py to deploy to GitHub and build the new EXE.")
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
        print("\n⏹️ Operation cancelled by user.")
        sys.exit(0)
    except Exception as e:
        print(f"\n❌ Unexpected error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()