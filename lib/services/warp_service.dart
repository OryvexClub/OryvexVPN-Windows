import 'dart:io';
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
    return '\$exeDir\\data\\wireguard.exe';
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
    return '\$bestIp:2408';
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
PrivateKey = \$privKeyBase64
Address = \$address/32
DNS = 1.1.1.1, 1.0.0.1
MTU = 1280

[Peer]
PublicKey = \$peerPublicKey
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = \$bestEndpoint
PersistentKeepalive = 25''';
  }

  static Future<File> _writeConfigFile(String config) async {
    final dir = Directory.systemTemp;
    final file = File('\${dir.path}\\\$_tunnelName.conf');
    return file.writeAsString(config);
  }

  static Future<bool> isWireGuardInstalled() async {
    return File(_wireguardExe).exists();
  }

  /// Escapes a string for safe embedding inside a single-quoted
  /// PowerShell string literal (doubles any embedded single quotes).
  static String _psQuote(String value) => "'${value.replaceAll("'", "''")}'";

  /// Runs [exePath] with [args] fully elevated, regardless of whether
  /// this Dart process itself is elevated. Uses PowerShell's
  /// Start-Process -Verb RunAs -Wait so a UAC prompt is triggered if
  /// needed, and waits for the launched process to actually finish
  /// before returning its exit code.
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
      throw Exception(
        'اجرای مجوز-بالا (Elevated) ناموفق بود. کد خطا: \${result.exitCode}'
        '${detail.isNotEmpty ? '\nجزئیات: $detail' : ''}',
      );
    }
    return result.exitCode;
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
      await _runElevated(_wireguardExe, ['/installtunnelservice', file.path]);
    } catch (e) {
      throw Exception(
        'نصب تونل ناموفق بود. اطمینان حاصل کنید که در پنجره UAC روی "بله" کلیک کرده‌اید.\n'
        '\$e',
      );
    }
  }

  static Future<void> disconnect() async {
    if (!Platform.isWindows) return;
    try {
      await _runElevated(_wireguardExe, ['/uninstalltunnelservice', _tunnelName]);
    } catch (_) {
      // Best-effort: if the tunnel was already gone/never installed,
      // don't block the UI from returning to idle state.
    }
  }

  static Future<bool> isConnected() async {
    if (!Platform.isWindows) return false;
    try {
      final result = await Process.run(
        'sc.exe',
        ['query', 'WireGuardTunnel\\$\$_tunnelName'],
      );
      return result.stdout.toString().contains('RUNNING');
    } catch (_) {
      return false;
    }
  }
}
