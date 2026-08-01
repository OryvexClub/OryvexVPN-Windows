import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cryptography/cryptography.dart';
import 'package:path_provider/path_provider.dart';

/// Drives the OFFICIAL, pre-built WireGuard for Windows client
/// (https://www.wireguard.com/install/) instead of compiling a
/// third-party userspace implementation from source.
///
/// boringtun-cli (Cloudflare's Rust implementation) is documented
/// upstream as Linux/macOS only and cannot be compiled for Windows -
/// it depends on Unix-only APIs (fork, setuid, chroot, flock, unix
/// sockets) that simply don't exist on MSVC. wireguard.exe is the real
/// Windows implementation (WireGuardNT kernel driver + userspace
/// manager), bundled with the app and driven via its documented
/// service-install command line interface:
///
///   wireguard.exe /installtunnelservice <path-to-conf>
///   wireguard.exe /uninstalltunnelservice <tunnel-name>
///
/// Each call installs/removes a real Windows service named
/// "WireGuardTunnel$<tunnel-name>", exactly like the official GUI client.
class WarpService {
  static const _tunnelName = 'oryvexvpn';
  static bool _connected = false;

  // Cloudflare WARP endpoint list.
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

  static String get _wireguardExe => '$_exeDir\\data\\wireguard.exe';

  static Future<bool> _coreFilesPresent() async {
    return File(_wireguardExe).exists();
  }

  static Future<String> _confDir() async {
    final dir = await getApplicationSupportDirectory();
    final confDir = Directory('${dir.path}\\wireguard');
    if (!await confDir.exists()) {
      await confDir.create(recursive: true);
    }
    return confDir.path;
  }

  /// Concurrent ping scan for the fastest endpoint.
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

  /// Register with Cloudflare WARP API and return the needed parameters.
  static Future<_WarpRegistration> _register(Function(String) onProgress) async {
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

  /// Writes the .conf file and installs it as a Windows tunnel service
  /// via the official wireguard.exe CLI.
  static Future<void> _installTunnelService(_WarpRegistration reg) async {
    final confDir = await _confDir();
    final confFile = File('$confDir\\$_tunnelName.conf');
    await confFile.writeAsString(_buildConf(reg));

    // Remove any stale service from a previous run first (ignore errors -
    // it may simply not exist yet).
    await Process.run(_wireguardExe, ['/uninstalltunnelservice', _tunnelName]);
    await Future.delayed(const Duration(milliseconds: 300));

    final result = await Process.run(
      _wireguardExe,
      ['/installtunnelservice', confFile.path],
    );

    if (result.exitCode != 0) {
      final err = (result.stderr ?? '').toString().trim();
      throw Exception(
        err.isNotEmpty ? err : 'نصب سرویس WireGuard ناموفق بود.',
      );
    }

    // Give the service a moment to actually come up before we check it.
    await Future.delayed(const Duration(seconds: 1));
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
        'فایل هسته (data\\wireguard.exe) در برنامه یافت نشد.',
      );
    }

    final reg = await _register(onProgress);

    onProgress('در حال نصب سرویس WireGuard...');
    await _installTunnelService(reg);

    _connected = true;
  }

  static Future<void> disconnect() async {
    if (!Platform.isWindows) return;
    try {
      await Process.run(_wireguardExe, ['/uninstalltunnelservice', _tunnelName]);
    } catch (_) {
      // Non-fatal: service may already be gone.
    }
    _connected = false;
  }

  static Future<bool> isConnected() async {
    if (!Platform.isWindows) return false;
    if (!_connected) return false;
    // WireGuard installs the tunnel as a service named
    // "WireGuardTunnel$<name>". Query the service manager directly
    // rather than netsh, since the interface name WireGuard chooses
    // internally isn't guaranteed to match our tunnel name exactly.
    final result = await Process.run(
      'sc', ['query', 'WireGuardTunnel\$$_tunnelName'],
    );
    return result.exitCode == 0 &&
        result.stdout.toString().contains('RUNNING');
  }
}

class _WarpRegistration {
  final String privateKeyBase64;
  final String address;
  final String peerPublicKeyBase64;
  final String endpointIp;
  final String endpointPort;

  const _WarpRegistration({
    required this.privateKeyBase64,
    required this.address,
    required this.peerPublicKeyBase64,
    required this.endpointIp,
    required this.endpointPort,
  });
}
