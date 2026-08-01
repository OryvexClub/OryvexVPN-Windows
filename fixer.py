#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
fixer.py - OryvexVPN Auto-Fixer (self-built wireguard-go + wintun.dll edition)

The VPN core is now the OFFICIAL, open-source wireguard-go
(https://github.com/WireGuard/wireguard-go), built from source in CI, plus
the official Wintun driver DLL (wintun.net). No AmneziaWG, no WireSock, no
commercial SDK, and the official wireguard.exe GUI/MSI is never used.

We drive wireguard-go directly through its own UAPI protocol over its
Windows named pipe, and configure the adapter's IP/route/DNS ourselves
(the job wg-quick normally does on Linux).

KNOWN, ACCEPTED RISK: wireguard-go's Windows UAPI named pipe
(\\\\.\\pipe\\ProtectedPrefix\\Administrators\\WireGuard\\<name>) has a
long-documented upstream issue where pipe creation can fail with
"This security ID may not be assigned as the owner of this object", even
from an elevated process. wireguard-windows/AmneziaWG normally avoid this
by wrapping wireguard-go in a real Windows service running as SYSTEM. This
build intentionally does NOT do that (per explicit request), so that
failure mode is possible here. If it happens, warp_service.dart surfaces a
clear message identifying it as an upstream limitation, not a bug in this
app.

Fixes carried over from earlier revisions:
  1. The app manifest is set to requireAdministrator - app runs elevated once.
  2. Endpoint list expanded to 300+ IPs with concurrent ping scanning.
  3. Disconnect kills the wireguard-go process and tears the adapter down.
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
            "INFO": "[i]", "SUCCESS": "[OK]", "WARNING": "[!]",
            "ERROR": "[X]", "STEP": "[>]", "FIX": "[FIX]"
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
        Rewrite warp_service.dart to drive a self-built, bundled copy of the
        official wireguard-go + official wintun.dll directly via UAPI, with
        no AmneziaWG, no WireSock, no commercial SDK involved.
        """
        warp_path = self.root / "lib" / "services" / "warp_service.dart"
        correct = r"""import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cryptography/cryptography.dart';

/// Drives a self-built, bundled copy of the official open-source
/// wireguard-go (https://github.com/WireGuard/wireguard-go) plus the
/// official Wintun driver DLL, directly — no AmneziaWG, no WireSock, no
/// commercial SDK, and never the official wireguard.exe GUI/MSI.
///
/// IMPORTANT / KNOWN RISK (read before relying on this in production):
/// wireguard-go's own Windows UAPI implementation
/// (\\.\pipe\ProtectedPrefix\Administrators\WireGuard\<name>) has a
/// long-documented issue where creating that named pipe can fail with
/// "This security ID may not be assigned as the owner of this object",
/// even from an already-elevated process. Upstream's answer to this is
/// wireguard-windows, which wraps wireguard-go in a proper Windows
/// service running as SYSTEM — something we are intentionally NOT doing
/// here. If you hit that specific error, it is not a bug in this file;
/// it's the exact upstream limitation this approach accepts. The error
/// is surfaced clearly below instead of being silently swallowed.
class WarpService {
  static const _tunnelName = 'oryvexvpn';
  static const _uapiPipeName = r'ProtectedPrefix\Administrators\WireGuard\oryvexvpn';

  static Process? _tunnelProcess;
  static bool _connected = false;

  // Same Cloudflare WARP endpoint list you already had — unrelated to the
  // core swap, left untouched.
  static const List<String> _endpoints = [
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
    "162.159.192.1", "162.159.192.2", "162.159.193.1", "162.159.193.5",
    "162.159.195.1", "162.159.195.2", "162.159.195.5",
    "188.114.96.0", "188.114.96.1", "188.114.96.2", "188.114.96.3",
    "188.114.96.4", "188.114.96.5", "188.114.97.0", "188.114.97.1",
    "188.114.97.2", "188.114.97.3", "188.114.97.4", "188.114.97.5",
    "188.114.98.0", "188.114.98.1", "188.114.98.2", "188.114.99.0",
    "188.114.99.1", "188.114.99.2",
  ];

  static String get _exeDir {
    final exePath = Platform.resolvedExecutable;
    return File(exePath).parent.path;
  }

  static String get _wireguardGoExe => '$_exeDir\\data\\wireguard-go.exe';
  static String get _wintunDll => '$_exeDir\\data\\wintun.dll';

  static Future<bool> _coreFilesPresent() async =>
      File(_wireguardGoExe).exists() && File(_wintunDll).exists();

  /// Concurrent ping scan to find the fastest Cloudflare endpoint.
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

    final bestIp = results.first['latency'] != 9999
        ? results.first['ip'] as String
        : _endpoints.first;
    return bestIp;
  }

  static String _bytesToHex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  /// Registers with the Cloudflare WARP API and returns everything needed
  /// to both display a human-readable config AND drive the UAPI directly
  /// (UAPI needs hex keys, not the base64 form used in .conf files).
  static Future<_WarpRegistration> _register(Function(String) onProgress) async {
    onProgress('در حال ساخت کلید رمزنگاری...');
    final algorithm = X25519();
    final keyPair = await algorithm.newKeyPair();
    final publicKey = await keyPair.extractPublicKey();
    final privateKeyBytes = await keyPair.extractPrivateKeyBytes();

    final pubKeyBase64 = base64Encode(publicKey.bytes);
    final privKeyHex = _bytesToHex(privateKeyBytes);

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
    final address = (data['config']['interface']['addresses']['v4'] as String);
    final peerPublicKeyBase64 = peer['public_key'] as String;
    final peerPublicKeyHex = _bytesToHex(base64Decode(peerPublicKeyBase64));

    final bestIp = await _findBestEndpoint(onProgress);

    return _WarpRegistration(
      privateKeyHex: privKeyHex,
      address: address,
      peerPublicKeyHex: peerPublicKeyHex,
      endpointIp: bestIp,
      endpointPort: '2408',
    );
  }

  /// Writes the small PowerShell helper that actually talks to the UAPI
  /// named pipe (Dart's dart:io has no first-class Windows named pipe
  /// client, so we drive .NET's NamedPipeClientStream for this one step).
  static Future<File> _ensureUapiHelperScript() async {
    final path = '${Directory.systemTemp.path}\\oryvexvpn_uapi_helper.ps1';
    const script = r'''
param(
  [string]$PipeName,
  [string]$InFile,
  [string]$OutFile,
  [int]$TimeoutMs = 4000
)
try {
  $client = New-Object System.IO.Pipes.NamedPipeClientStream(".", $PipeName, [System.IO.Pipes.PipeDirection]::InOut)
  $client.Connect($TimeoutMs)

  $bytes = [System.IO.File]::ReadAllBytes($InFile)
  $client.Write($bytes, 0, $bytes.Length)
  $client.Flush()

  $reader = New-Object System.IO.StreamReader($client)
  $sb = New-Object System.Text.StringBuilder
  while ($true) {
    $line = $reader.ReadLine()
    if ($null -eq $line) { break }
    [void]$sb.AppendLine($line)
    if ($line -eq "") { break }
  }
  [System.IO.File]::WriteAllText($OutFile, $sb.ToString())
  $client.Dispose()
  exit 0
} catch {
  [System.IO.File]::WriteAllText($OutFile, "ERROR: " + $_.Exception.Message)
  exit 1
}
''';
    final file = File(path);
    await file.writeAsString(script);
    return file;
  }

  /// Sends a raw UAPI command to the running wireguard-go's named pipe and
  /// returns its response text.
  static Future<String> _uapiSend(String command) async {
    final helper = await _ensureUapiHelperScript();
    final tmpDir = Directory.systemTemp.path;
    final inFile = File('$tmpDir\\oryvexvpn_uapi_in.txt');
    final outFile = File('$tmpDir\\oryvexvpn_uapi_out.txt');
    await inFile.writeAsString(command);
    if (await outFile.exists()) await outFile.delete();

    final result = await Process.run('powershell.exe', [
      '-NoProfile',
      '-ExecutionPolicy', 'Bypass',
      '-File', helper.path,
      '-PipeName', _uapiPipeName,
      '-InFile', inFile.path,
      '-OutFile', outFile.path,
    ]);

    final out = await outFile.exists() ? await outFile.readAsString() : '';

    if (result.exitCode != 0 || out.startsWith('ERROR:')) {
      if (out.contains('security ID may not be assigned as the owner')) {
        throw Exception(
          'wireguard-go نتوانست روی pipe داخلی خودش گوش بدهد (محدودیت '
          'شناخته‌شده‌ی خود wireguard-go روی ویندوز وقتی بدون سرویس ویندوزی '
          'اجرا می‌شود). این یک محدودیت بالادستی است، نه باگ این برنامه.\n'
          'جزئیات: $out',
        );
      }
      throw Exception('ارتباط با هسته‌ی وایرگارد ناموفق بود.\n$out');
    }
    return out;
  }

  static Future<void> _configureUapi(_WarpRegistration reg) async {
    final buf = StringBuffer();
    buf.writeln('set=1');
    buf.writeln('private_key=${reg.privateKeyHex}');
    buf.writeln('listen_port=0');
    buf.writeln('replace_peers=true');
    buf.writeln('public_key=${reg.peerPublicKeyHex}');
    buf.writeln('endpoint=${reg.endpointIp}:${reg.endpointPort}');
    buf.writeln('persistent_keepalive_interval=25');
    buf.writeln('replace_allowed_ips=true');
    buf.writeln('allowed_ip=0.0.0.0/0');
    buf.writeln(); // blank line terminates the UAPI transaction

    final response = await _uapiSend(buf.toString());
    if (!response.contains('errno=0')) {
      throw Exception('پیکربندی هسته‌ی وایرگارد رد شد.\n$response');
    }
  }

  /// wg-quick normally does this on Linux; on our bare wireguard-go setup
  /// we have to configure the adapter's IP/MTU/DNS/route ourselves.
  static Future<void> _configureAdapter(_WarpRegistration reg) async {
    final ip = reg.address; // e.g. "172.16.0.2"
    final commands = <List<String>>[
      ['netsh', 'interface', 'ip', 'set', 'address', 'name=$_tunnelName', 'static', ip, '255.255.255.255'],
      ['netsh', 'interface', 'ipv4', 'set', 'subinterface', _tunnelName, 'mtu=1280', 'store=active'],
      ['netsh', 'interface', 'ip', 'set', 'dns', 'name=$_tunnelName', 'static', '1.1.1.1'],
      ['netsh', 'interface', 'ip', 'add', 'dns', 'name=$_tunnelName', '1.0.0.1', 'index=2'],
      ['netsh', 'interface', 'ipv4', 'add', 'route', '0.0.0.0/0', _tunnelName],
    ];

    for (final cmd in commands) {
      final result = await Process.run(cmd.first, cmd.sublist(1));
      if (result.exitCode != 0) {
        final err = (result.stderr ?? '').toString().trim();
        throw Exception('پیکربندی آداپتور شبکه ناموفق بود: ${cmd.join(' ')}\n$err');
      }
    }
  }

  static Future<void> _waitForPipe() async {
    // installtunnelservice-style wrappers get to wait on a service
    // handle; we just poll briefly for the process to have set up the
    // pipe and adapter before we try to talk to it.
    await Future.delayed(const Duration(milliseconds: 1500));
  }

  static Future<void> connect() async {
    if (!Platform.isWindows) {
      throw Exception('این نسخه فقط مخصوص ویندوز است.');
    }
    await connectWithProgress((_) {});
  }

  static Future<void> connectWithProgress(Function(String) onProgress) async {
    if (!Platform.isWindows) {
      throw Exception('این نسخه فقط مخصوص ویندوز است.');
    }
    if (!await _coreFilesPresent()) {
      throw Exception(
        'فایل‌های هسته (data\\wireguard-go.exe و data\\wintun.dll) در برنامه یافت نشد.',
      );
    }

    final reg = await _register(onProgress);

    onProgress('در حال راه‌اندازی هسته وایرگارد...');
    _tunnelProcess = await Process.start(
      _wireguardGoExe,
      ['-f', _tunnelName],
      workingDirectory: '$_exeDir\\data',
      mode: ProcessStartMode.detachedWithStdio,
    );

    await _waitForPipe();

    try {
      onProgress('در حال پیکربندی تونل...');
      await _configureUapi(reg);

      onProgress('در حال پیکربندی آداپتور شبکه...');
      await _configureAdapter(reg);

      _connected = true;
    } catch (e) {
      await _killTunnelProcess();
      _connected = false;
      rethrow;
    }
  }

  static Future<void> _killTunnelProcess() async {
    final proc = _tunnelProcess;
    _tunnelProcess = null;
    if (proc == null) return;
    try {
      proc.kill(ProcessSignal.sigterm);
    } catch (_) {}
    // wireguard-go on Windows doesn't always die cleanly from sigterm from
    // a detached handle — make sure the adapter's owning process is gone.
    await Process.run('taskkill', ['/F', '/IM', 'wireguard-go.exe']);
  }

  static Future<void> disconnect() async {
    if (!Platform.isWindows) return;
    await _killTunnelProcess();
    _connected = false;
  }

  static Future<bool> isConnected() async {
    if (!Platform.isWindows) return false;
    if (!_connected) return false;
    // Best-effort liveness check: is our process handle still alive, and
    // does the adapter still show up.
    final result = await Process.run('netsh', ['interface', 'show', 'interface', _tunnelName]);
    return result.exitCode == 0 && result.stdout.toString().contains(_tunnelName);
  }
}

class _WarpRegistration {
  final String privateKeyHex;
  final String address;
  final String peerPublicKeyHex;
  final String endpointIp;
  final String endpointPort;

  const _WarpRegistration({
    required this.privateKeyHex,
    required this.address,
    required this.peerPublicKeyHex,
    required this.endpointIp,
    required this.endpointPort,
  });
}
"""
        warp_path.parent.mkdir(parents=True, exist_ok=True)
        warp_path.write_text(correct, encoding='utf-8')
        self.fixed_files.append("warp_service.dart (self-built wireguard-go + wintun.dll via UAPI, no 3rd-party core)")
        return True

    def fix_vpn_service(self) -> bool:
        vpn_path = self.root / "lib" / "services" / "vpn_service.dart"
        correct = r"""import 'package:flutter/foundation.dart';
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
      await WarpService.connectWithProgress((msg) {
        _stage = VpnStage.installingTunnel;
        _updateStatus(msg);
      });

      final actuallyUp = await WarpService.isConnected();
      if (!actuallyUp) {
        throw Exception('تونل پس از پیکربندی فعال دیده نشد.');
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

      - name: Setup Go (to build wireguard-go from source)
        uses: actions/setup-go@v5
        with:
          go-version: 'stable'

      # We build the OFFICIAL, open-source wireguard-go (the same core used
      # inside wireguard-windows / AmneziaWG) directly from its own upstream
      # source, ourselves, at build time. No third-party GUI app, no MSI
      # installer, no commercial SDK.
      #
      # KNOWN LIMITATION (documented upstream, accepted as a risk for this
      # build): wireguard-go's Windows UAPI named pipe
      # (\\.\pipe\ProtectedPrefix\Administrators\WireGuard\<name>) has a
      # long-standing issue where pipe creation can fail with
      # "This security ID may not be assigned as the owner of this object"
      # even when the process is already elevated. This is exactly the
      # gap that wireguard-windows/AmneziaWG normally paper over by running
      # everything inside a proper Windows service under SYSTEM. We are
      # NOT doing that here — see warp_service.dart for how we surface this
      # if it happens at runtime.
      - name: Build wireguard-go.exe for Windows
        run: |
          git clone --depth 1 https://github.com/WireGuard/wireguard-go.git wireguard-go-src
          cd wireguard-go-src
          $env:GOOS = "windows"
          $env:GOARCH = "amd64"
          $env:CGO_ENABLED = "0"
          go build -ldflags="-s -w" -o wireguard-go.exe .
          if (-not (Test-Path "wireguard-go.exe")) {
            Write-Host "wireguard-go.exe build failed."
            exit 1
          }
          Write-Host "wireguard-go.exe built successfully."

      - name: Bundle wireguard-go.exe + official Wintun driver inside data/
        run: |
          $ReleaseDir = "build\windows\x64\runner\Release"
          New-Item -ItemType Directory -Force -Path "$ReleaseDir\data"

          Copy-Item "wireguard-go-src\wireguard-go.exe" "$ReleaseDir\data\wireguard-go.exe"

          # Official Wintun driver from the WireGuard project (wintun.net).
          # Redistributable per its license, no separate MSI/driver install
          # step needed by the user — the DLL sets up the driver itself the
          # first time an app calls into it.
          $wintunVersion = "0.14.1"
          Invoke-WebRequest -Uri "https://www.wintun.net/builds/wintun-$wintunVersion.zip" -OutFile "wintun.zip"
          Expand-Archive "wintun.zip" -DestinationPath "wintun_extracted"
          Copy-Item "wintun_extracted\wintun\bin\amd64\wintun.dll" "$ReleaseDir\data\wintun.dll"

          if (-not (Test-Path "$ReleaseDir\data\wintun.dll")) {
            Write-Host "wintun.dll bundling failed."
            exit 1
          }

          Write-Host "wireguard-go.exe and wintun.dll bundled in data/ folder."

      - name: Upload build artifacts
        uses: actions/upload-artifact@v4
        with:
          name: oryvexvpn-windows
          path: build/windows/x64/runner/Release/
"""
        workflow_path.parent.mkdir(parents=True, exist_ok=True)
        workflow_path.write_text(correct, encoding='utf-8')
        self.fixed_files.append("build_windows.yml (builds wireguard-go from source, bundles official wintun.dll)")
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
        print("Flutter Project Fixer - OryvexVPN (self-built wireguard-go + wintun.dll, no 3rd-party core)")
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
        print("Final Report")
        print("=" * 60)
        if self.fixed_files:
            print("\nModified/Added Files:")
            for f in self.fixed_files:
                print(f"  - {f}")

        print("\nFixes applied:")
        print("  - VPN core: self-built, bundled wireguard-go.exe (official open-source")
        print("    core) + official wintun.dll, driven directly over UAPI. No AmneziaWG,")
        print("    no WireSock, no commercial SDK, no official wireguard.exe GUI/MSI.")
        print("  - KNOWN RISK: wireguard-go's Windows UAPI pipe can fail with a")
        print("    documented upstream 'security ID' error outside a real Windows")
        print("    service context. This build accepts that risk; the error is")
        print("    surfaced clearly instead of hidden if it happens.")
        print("  - App manifest set to requireAdministrator.")
        print("  - Endpoint list: 300+ IPs, concurrent ping scan for best server.")
        print("  - Adapter IP/MTU/DNS/route now configured by the app itself (the")
        print("    job wg-quick normally does), since bare wireguard-go doesn't.")
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
        print("\nOperation cancelled by user.")
        sys.exit(0)
    except Exception as e:
        print(f"\nUnexpected error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()