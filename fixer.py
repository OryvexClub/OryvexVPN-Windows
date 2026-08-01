#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
fixer.py - OryvexVPN Auto-Fixer
Implements automatic Cloudflare WARP key generation, endpoint sweeping,
and real WireGuard connection without any manual configuration.
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

    def fix_main_dart(self) -> bool:
        main_path = self.root / "lib" / "main.dart"
        correct = """import 'package:flutter/material.dart';
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

  // Hand-picked reliable endpoints
  static const List<String> _endpoints = [
    "162.159.192.1", "162.159.193.1", "162.159.195.1",
    "188.114.96.1", "188.114.97.1", "188.114.98.1",
    "8.6.112.165", "8.6.112.139", "8.6.112.178",
    "104.16.248.249", "103.21.244.0"
  ];

  static Future<String> _findBestEndpoint(Function(String) onProgress) async {
    onProgress('Scanning endpoints for best latency...');
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
    onProgress('Generating X25519 keypair...');
    final algorithm = X25519();
    final keyPair = await algorithm.newKeyPair();
    final publicKey = await keyPair.extractPublicKey();
    final privateKeyBytes = await keyPair.extractPrivateKeyBytes();

    final pubKeyBase64 = base64Encode(publicKey.bytes);
    final privKeyBase64 = base64Encode(privateKeyBytes);

    onProgress('Registering with Cloudflare WARP...');
    final response = await http.post(
      Uri.parse('https://api.cloudflareclient.com/v0a737/reg'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "key": pubKeyBase64,
        "install_id": "",
        "warp_enabled": true,
        "tos": DateTime.now().toUtc().toIso8601String(),
        "type": "Windows",
        "locale": "en_US"
      }),
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to register device.');
    }

    final data = jsonDecode(response.body);
    final peer = data['config']['peers'][0];
    final address = data['config']['interface']['addresses']['v4'];
    final peerPublicKey = peer['public_key'];

    final bestEndpoint = await _findBestEndpoint(onProgress);

    onProgress('Building configuration...');
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
    final file = File('${dir.path}\\\\_tunnelName.conf');
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

  static Future<void> connect(String config) async {
    if (!Platform.isWindows) {
      throw Exception('Currently only supports Windows.');
    }
    if (!await isWireGuardInstalled()) {
      throw Exception('WireGuard for Windows is not installed. Download from wireguard.com');
    }

    final file = await _writeConfigFile(config);
    final result = await Process.run(
      'wireguard.exe',
      ['/installtunnelservice', file.path],
      runInShell: true,
    );

    if (result.exitCode != 0) {
      throw Exception(
        'Failed to install tunnel. Please run this app as Administrator.\\n'
        '${result.stderr}'
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
        self.fixed_files.append("warp_service.dart (NEW)")
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
  String _statusMessage = 'Click to Connect';
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
      _statusMessage = 'Connected';
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
      _updateStatus('Establishing WireGuard tunnel...');

      await WarpService.connect(config);

      final actuallyUp = await WarpService.isConnected();
      if (!actuallyUp) {
        throw Exception('Windows service failed to start.');
      }

      _stage = VpnStage.connected;
      _updateStatus('Connected');
    } catch (e) {
      _stage = VpnStage.error;
      _lastError = e.toString().replaceFirst('Exception: ', '');
      _updateStatus('Connection Failed');
    }
    notifyListeners();
  }

  Future<void> disconnect() async {
    _stage = VpnStage.disconnecting;
    _updateStatus('Disconnecting...');

    await WarpService.disconnect();

    _stage = VpnStage.idle;
    _updateStatus('Disconnected');
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
                                        'WireGuard Tunnel Active',
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
        self.fixed_files.append("pubspec.yaml (Added cryptography, removed unused)")
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
        print("🔧 Flutter Project Fixer - OryvexVPN (Automatic Generation)")
        print("=" * 60)
        print(f"\nProject Path: {self.root}\n")

        if not self.check_project():
            return False

        self.fix_main_dart()
        self.fix_pubspec()
        self.fix_warp_service()
        self.fix_vpn_service()
        self.fix_home_screen()
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

        print("\n✅ All issues resolved and parameters ported successfully. You can now execute push.py.")
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