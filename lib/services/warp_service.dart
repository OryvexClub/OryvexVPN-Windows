import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cryptography/cryptography.dart';

/// Drives a self‑built copy of Cloudflare BoringTun
/// (https://github.com/cloudflare/boringtun) plus the official Wintun driver.
///
/// BoringTun is started with all necessary parameters on the command line.
/// For endpoint changes we simply kill and restart the process.
class WarpService {
  static const _tunnelName = 'oryvexvpn';
  static Process? _tunnelProcess;
  static bool _connected = false;

  // Cloudflare WARP endpoint list (unchanged).
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

  static String get _boringTunExe => '$_exeDir\\data\\boringtun.exe';
  static String get _wintunDll => '$_exeDir\\data\\wintun.dll';

  /// Check that both core files exist.
  static Future<bool> _coreFilesPresent() async {
    final goExists = await File(_boringTunExe).exists();
    final wintunExists = await File(_wintunDll).exists();
    return goExists && wintunExists;
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

  static String _bytesToHex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  /// Register with Cloudflare WARP API and return the needed parameters.
  static Future<_WarpRegistration> _register(Function(String) onProgress) async {
    onProgress('در حال ساخت کلید رمزنگاری...');
    final algorithm = X25519();
    final keyPair = await algorithm.newKeyPair();
    final publicKey = await keyPair.extractPublicKey();
    final privateKeyBytes = await keyPair.extractPrivateKeyBytes();

    final pubKeyBase64 = base64Encode(publicKey.bytes);
    final privKeyBase64 = base64Encode(privateKeyBytes);  // BoringTun expects base64

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

  /// Start BoringTun with the given parameters.
  /// BoringTun CLI: boringtun <iface> --private-key <key> --peer-public-key <key>
  /// --endpoint <ip:port> --allowed-ips <ips> --address <ip> --dns <dns> --mtu <mtu>
  static Future<void> _startBoringTun(_WarpRegistration reg) async {
    final args = [
      _tunnelName,
      '--private-key', reg.privateKeyBase64,
      '--peer-public-key', reg.peerPublicKeyBase64,
      '--endpoint', '${reg.endpointIp}:${reg.endpointPort}',
      '--allowed-ips', '0.0.0.0/0',
      '--address', reg.address,         // e.g. 172.16.0.2/32? BoringTun accepts CIDR
      '--dns', '1.1.1.1',
      '--mtu', '1280',
      '--persistent-keepalive', '25',
    ];

    _tunnelProcess = await Process.start(
      _boringTunExe,
      args,
      workingDirectory: '$_exeDir\\data',
      mode: ProcessStartMode.detachedWithStdio,
    );

    // Give it a moment to set up the adapter.
    await Future.delayed(const Duration(seconds: 2));

    // Check if the process is still alive; if not, something went wrong.
    if (_tunnelProcess == null || !(await _tunnelProcess!.exitCode.timeout(
        const Duration(milliseconds: 100), onTimeout: () => null))?.isCompleted == false) {
      // Process seems to be running.
    } else {
      throw Exception('BoringTun exited unexpectedly.');
    }
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
        'فایل‌های هسته (data\\boringtun.exe و data\\wintun.dll) در برنامه یافت نشد.',
      );
    }

    final reg = await _register(onProgress);

    onProgress('در حال راه‌اندازی تونل BoringTun...');
    await _startBoringTun(reg);

    _connected = true;
  }

  static Future<void> _killTunnelProcess() async {
    final proc = _tunnelProcess;
    _tunnelProcess = null;
    if (proc == null) return;
    try {
      proc.kill(ProcessSignal.sigterm);
      await proc.exitCode.timeout(const Duration(seconds: 2), onTimeout: () {
        proc.kill(ProcessSignal.sigkill);
        return null;
      });
    } catch (_) {}
    // Clean up any remaining processes.
    await Process.run('taskkill', ['/F', '/IM', 'boringtun.exe']);
  }

  static Future<void> disconnect() async {
    if (!Platform.isWindows) return;
    await _killTunnelProcess();
    _connected = false;
  }

  static Future<bool> isConnected() async {
    if (!Platform.isWindows) return false;
    if (!_connected) return false;
    // Check if the adapter still exists.
    final result = await Process.run('netsh', ['interface', 'show', 'interface', _tunnelName]);
    return result.exitCode == 0 && result.stdout.toString().contains(_tunnelName);
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
