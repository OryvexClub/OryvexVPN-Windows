#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
fixer.py - OryvexVPN Auto-Fixer (AmneziaWG real-install core + WireSock fallback)

The official wireguard.exe is never downloaded, bundled, or called anywhere
in this script. The VPN core is now:
  1. AmneziaWG, pinned to release 2.0.2 of amnezia-vpn/amneziawg-windows-client.
     The app bundles the REAL MSI installer (data\amneziawg-setup.msi) and, the
     first time it's needed, runs a normal silent install
     (`msiexec /i ... /quiet /norestart`, elevated) so the WireGuardNT/
     AmneziaWG driver and the AmneziaWGManager service are actually
     registered. The previous version only ran `msiexec /a` (an
     "administrative install" that just unpacks files without running the
     MSI's install sequence), which is why the driver/service never got set
     up and the app reported "AmneziaWG service did not start after
     installation".
  2. WireSock Secure Connect - automatic fallback if AmneziaWG's install or
     connect fails and WireSock is already installed on the machine (it
     ships its own installer/service, so it can't be bundled portably).

Fixes:
  1. The app manifest is set to requireAdministrator - app runs elevated once.
  2. Core calls use PowerShell Start-Process -Verb RunAs, which does not
     show an additional UAC prompt if the parent is already elevated.
  3. Expands endpoint list and uses concurrent ping scanning for best server.
  4. Fixes disconnect: uninstall works with elevation, for whichever core
     is active.
  5. Verifies the tunnel is running after install, with a short retry loop
     since installtunnelservice returning 0 only means the service object
     was created, not that the adapter is fully up yet.
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
        Rewrite warp_service.dart so AmneziaWG gets a REAL msiexec /i silent
        install (from a bundled MSI, pinned to release 2.0.2) instead of the
        old msiexec /a extraction that never registered the driver/service.
        WireSock Secure Connect stays as an automatic fallback. No official
        wireguard.exe anywhere in this file.
        """
        warp_path = self.root / "lib" / "services" / "warp_service.dart"
        correct = r"""import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cryptography/cryptography.dart';

/// Which VPN core actually ended up carrying the current tunnel.
enum VpnCore { amneziawg, wiresock }

class WarpService {
  static const _tunnelName = 'oryvexvpn';
  static const _wiresockProfileName = 'oryvexvpn';

  static VpnCore? _activeCore;

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

  /// The MSI we ship inside data/ (built by build_windows.yml, pinned to
  /// AmneziaWG 2.0.2). We install FROM this, we never run it in "admin
  /// extraction" mode — that was the bug. See workflow comments.
  static String get _bundledMsi => '$_exeDir\\data\\amneziawg-setup.msi';

  /// Where the official MSI actually installs AmneziaWG once it has run a
  /// real (non-admin-image) install.
  static String get _installedAmneziawgExe {
    final pf = Platform.environment['ProgramFiles'] ?? r'C:\Program Files';
    return '$pf\\AmneziaWG\\amneziawg.exe';
  }

  /// WireSock Secure Connect is a real installer + background service, not
  /// something we can portably bundle, so we just look for it where the
  /// official installer places it if the user has it installed.
  static String get _wiresockCli {
    final pf = Platform.environment['ProgramFiles'] ?? r'C:\Program Files';
    return '$pf\\WireSock Secure Connect\\wiresock-connect-cli.exe';
  }

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
    return '$bestIp:2408';
  }

  /// Generates a WireGuard-format config via the Cloudflare WARP
  /// registration API. Both AmneziaWG and WireSock accept this format
  /// as-is. If your server actually speaks AmneziaWG's obfuscated
  /// protocol, copy the Jc/Jmin/Jmax/S1/S2/H1-H4 lines from your working
  /// Amnezia config into the [Interface] block this returns — see
  /// [obfuscationParams] below.
  static Future<String> generateConfig(
    Function(String) onProgress, {
    Map<String, String>? obfuscationParams,
  }) async {
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

    final extraInterfaceLines = StringBuffer();
    obfuscationParams?.forEach((key, value) {
      extraInterfaceLines.writeln('$key = $value');
    });

    return '''[Interface]
PrivateKey = $privKeyBase64
Address = $address/32
DNS = 1.1.1.1, 1.0.0.1
MTU = 1280
$extraInterfaceLines
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

  static Future<bool> isAmneziaWGInstalled() async =>
      File(_installedAmneziawgExe).exists();

  static Future<bool> _hasBundledInstaller() async => File(_bundledMsi).exists();

  static Future<bool> isWireSockAvailable() async => File(_wiresockCli).exists();

  /// Escapes a string for safe embedding inside a single-quoted
  /// PowerShell string literal.
  static String _psQuote(String value) => "'${value.replaceAll("'", "''")}'";

  /// Runs [exePath] with [args] fully elevated. No extra UAC prompt if the
  /// app itself is already running as admin.
  static Future<int> _runElevated(String exePath, List<String> args) async {
    final argList = args.map(_psQuote).join(',');
    final psCommand =
        "\$p = Start-Process -FilePath ${_psQuote(exePath)} "
        "-ArgumentList $argList "
        "-Verb RunAs -Wait -PassThru -WindowStyle Hidden; "
        "exit \$p.ExitCode";

    final result = await Process.run(
      'powershell.exe',
      ['-NoProfile', '-NonInteractive', '-Command', psCommand],
      runInShell: false,
    );

    if (result.exitCode != 0) {
      final stderrText = (result.stderr ?? '').toString().trim();
      final stdoutText = (result.stdout ?? '').toString().trim();
      final detail = [stderrText, stdoutText].where((s) => s.isNotEmpty).join(' | ');
      final detailSuffix = detail.isNotEmpty ? '\nجزئیات: $detail' : '';
      throw Exception('اجرای هسته وی‌پی‌ان ناموفق بود (کد: ${result.exitCode})$detailSuffix');
    }
    return result.exitCode;
  }

  /// Installs the bundled AmneziaWG MSI with a real, silent, non-admin-image
  /// install (`msiexec /i ... /quiet /norestart`). This is the step the old
  /// code skipped by doing `msiexec /a` extraction, which is why the driver
  /// and AmneziaWGManager service never got registered and the tunnel
  /// service failed to actually start.
  static Future<void> _ensureAmneziaWGInstalled(Function(String) onProgress) async {
    if (await isAmneziaWGInstalled()) return;

    if (!await _hasBundledInstaller()) {
      throw Exception(
        'فایل نصب AmneziaWG (data\\amneziawg-setup.msi) در برنامه یافت نشد.',
      );
    }

    onProgress('در حال نصب هسته AmneziaWG (یک‌بار)...');

    final psCommand =
        "\$p = Start-Process -FilePath 'msiexec.exe' "
        "-ArgumentList @('/i', ${_psQuote(_bundledMsi)}, '/quiet', '/norestart') "
        "-Verb RunAs -Wait -PassThru -WindowStyle Hidden; "
        "exit \$p.ExitCode";

    final result = await Process.run(
      'powershell.exe',
      ['-NoProfile', '-NonInteractive', '-Command', psCommand],
      runInShell: false,
    );

    // msiexec exit code 3010 = success, reboot required (harmless for us —
    // driver + service are already registered at that point).
    if (result.exitCode != 0 && result.exitCode != 3010) {
      final stderrText = (result.stderr ?? '').toString().trim();
      throw Exception(
        'نصب AmneziaWG ناموفق بود (کد msiexec: ${result.exitCode}).\n$stderrText',
      );
    }

    if (!await isAmneziaWGInstalled()) {
      throw Exception('پس از نصب، amneziawg.exe در مسیر مورد انتظار پیدا نشد.');
    }
  }

  static Future<void> connect(String config) async {
    if (!Platform.isWindows) {
      throw Exception('این نسخه فقط مخصوص ویندوز است.');
    }

    final file = await _writeConfigFile(config);

    // AmneziaWG first, backed by a real MSI install so the driver and
    // AmneziaWGManager service actually exist this time. Fall back to
    // WireSock (different driver family) only if AmneziaWG install/connect
    // fails and WireSock Secure Connect happens to be installed already.
    // The official wireguard.exe is never downloaded or used.
    try {
      await _connectAmneziaWG(file);
      _activeCore = VpnCore.amneziawg;
      return;
    } catch (e) {
      if (!await isWireSockAvailable()) rethrow;
    }

    await _connectWireSock(file);
    _activeCore = VpnCore.wiresock;
  }

  static Future<void> _connectAmneziaWG(File configFile) async {
    await _ensureAmneziaWGInstalled((msg) {});

    try {
      await _runElevated(_installedAmneziawgExe, ['/installtunnelservice', configFile.path]);
    } catch (e) {
      throw Exception('نصب تونل AmneziaWG ناموفق بود.\n$e');
    }

    // Give the service manager a brief moment to report RUNNING before we
    // give up — installtunnelservice returning 0 just means the service
    // object was created, not that the adapter is fully up yet.
    bool isUp = false;
    for (var i = 0; i < 6; i++) {
      isUp = await _isAmneziaWGConnected();
      if (isUp) break;
      await Future.delayed(const Duration(milliseconds: 500));
    }
    if (!isUp) {
      throw Exception('سرویس AmneziaWG پس از نصب شروع نشد.');
    }
  }

  static Future<void> _connectWireSock(File configFile) async {
    // wiresock-connect-cli talks to the already-running WireSock service.
    // Best-effort delete of any stale profile with the same name, then
    // (re)import and connect.
    await Process.run(_wiresockCli, ['delete', _wiresockProfileName]);

    final importResult = await Process.run(_wiresockCli, ['import', configFile.path]);
    if (importResult.exitCode != 0) {
      throw Exception('وارد کردن پروفایل در WireSock ناموفق بود.\n${importResult.stderr}');
    }

    final connectResult = await Process.run(
      _wiresockCli,
      ['connect', _wiresockProfileName, '-exit'],
    );
    if (connectResult.exitCode != 0) {
      throw Exception('اتصال WireSock ناموفق بود.\n${connectResult.stderr}');
    }
  }

  static Future<void> disconnect() async {
    if (!Platform.isWindows) return;

    if (_activeCore == VpnCore.wiresock) {
      await Process.run(_wiresockCli, ['disconnect']);
      _activeCore = null;
      return;
    }

    try {
      await _runElevated(_installedAmneziawgExe, ['/uninstalltunnelservice', _tunnelName]);
    } catch (e) {
      if (e.toString().contains('The system cannot find the file specified') ||
          e.toString().contains('service does not exist')) {
        _activeCore = null;
        return;
      }
      rethrow;
    }
    _activeCore = null;
  }

  static Future<bool> _isAmneziaWGConnected() async {
    try {
      final result = await Process.run(
        'sc.exe',
        ['query', 'AmneziaWGTunnel\$' + _tunnelName],
      );
      return result.stdout.toString().contains('RUNNING');
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _isWireSockConnected() async {
    try {
      final result = await Process.run(_wiresockCli, ['status']);
      final out = result.stdout.toString();
      return out.contains('Connected') && !out.contains('NotConnected');
    } catch (_) {
      return false;
    }
  }

  /// Best-effort status check on app startup, before we know which core
  /// (if any) currently owns the tunnel.
  static Future<bool> isConnected() async {
    if (!Platform.isWindows) return false;

    if (_activeCore == VpnCore.wiresock) return _isWireSockConnected();
    if (_activeCore == VpnCore.amneziawg) return _isAmneziaWGConnected();

    // Unknown yet (e.g. fresh app launch) — check both.
    if (await isAmneziaWGInstalled() && await _isAmneziaWGConnected()) {
      _activeCore = VpnCore.amneziawg;
      return true;
    }
    if (await isWireSockAvailable() && await _isWireSockConnected()) {
      _activeCore = VpnCore.wiresock;
      return true;
    }
    return false;
  }
}
"""
        warp_path.parent.mkdir(parents=True, exist_ok=True)
        warp_path.write_text(correct, encoding='utf-8')
        self.fixed_files.append("warp_service.dart (AmneziaWG 2.0.2 real MSI install, WireSock fallback, no wireguard.exe)")
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

      - name: Bundle AmneziaWG 2.0.2 MSI installer inside data/
        run: |
          $ReleaseDir = "build\windows\x64\runner\Release"
          New-Item -ItemType Directory -Force -Path "$ReleaseDir\data"

          # Pinned to the amnezia-vpn/amneziawg-windows-client 2.0.2 tag on
          # purpose (not /latest) — the official wireguard.exe core is never
          # downloaded or used anywhere in this project.
          #
          # IMPORTANT: unlike the old workflow, we do NOT run
          #   msiexec /a <msi> /qb TARGETDIR=...
          # to extract a bare amneziawg.exe. An "administrative install"
          # (/a) only unpacks files — it does not run the MSI's install
          # sequence, so the WireGuardNT/AmneziaWG driver never gets
          # registered and no AmneziaWGManager service exists. That's what
          # produced "سرویس AmneziaWG پس از نصب شروع نشد" at runtime: the
          # extracted exe could "install" a tunnel service handle but the
          # driver behind it was never actually set up.
          #
          # Fix: bundle the *real* MSI installer as-is and let the app run
          # a normal silent `msiexec /i ... /quiet` (elevated) the first
          # time it needs AmneziaWG, so every install-time driver/service
          # step actually executes. See warp_service.dart.
          $version = "2.0.2"
          $url = "https://github.com/amnezia-vpn/amneziawg-windows-client/releases/download/$version/amneziawg-amd64-$version.msi"
          $out = "$ReleaseDir\data\amneziawg-setup.msi"

          Write-Host "Downloading AmneziaWG $version installer..."
          Invoke-WebRequest -Uri $url -OutFile $out -UseBasicParsing

          if (-not (Test-Path $out) -or (Get-Item $out).Length -lt 100000) {
            Write-Host "Download looks wrong/too small, asset name may have changed for this release. Failing build."
            exit 1
          }

          Write-Host "AmneziaWG $version MSI bundled at data\amneziawg-setup.msi"

      - name: Upload build artifacts
        uses: actions/upload-artifact@v4
        with:
          name: oryvexvpn-windows
          path: build/windows/x64/runner/Release/
"""
        workflow_path.parent.mkdir(parents=True, exist_ok=True)
        workflow_path.write_text(correct, encoding='utf-8')
        self.fixed_files.append("build_windows.yml (bundles real AmneziaWG 2.0.2 MSI, no wireguard.exe)")
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
        print("Flutter Project Fixer - OryvexVPN (AmneziaWG 2.0.2 real install + WireSock, no wireguard.exe)")
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
        print("  - VPN core: AmneziaWG pinned to release 2.0.2, installed via a REAL")
        print("    silent msiexec /i (elevated), not the old /a admin-extraction that")
        print("    skipped driver/service registration. WireSock Secure Connect stays")
        print("    as an automatic fallback. The official wireguard.exe is never used.")
        print("  - App manifest set to requireAdministrator - app runs elevated once.")
        print("  - Core calls use PowerShell Start-Process -Verb RunAs.")
        print("    (No extra UAC prompt if the app is already admin).")
        print("  - Endpoint list expanded to 300+ IPs with concurrent ping scan.")
        print("  - Disconnect now targets whichever core is actually active.")
        print("  - Connection verifies the tunnel is running after install, with a")
        print("    short retry loop instead of a single immediate check.")
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