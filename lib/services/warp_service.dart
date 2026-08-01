import 'dart:io';
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
