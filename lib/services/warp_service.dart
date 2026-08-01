import 'dart:io';
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
  static String get _wireguardExe => '$_exeDir\\data\\wireguard.exe';

  static Future<bool> _coreFilesPresent() async => File(_wireguardExe).exists();

  static Future<String> _confDir() async {
    final dir = await getApplicationSupportDirectory();
    final confDir = Directory('${dir.path}\\wireguard');
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
    final confFile = File('$confDir\\$_tunnelName.conf');
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
    final result = await Process.run('sc', ['query', 'WireGuardTunnel\\$$_tunnelName']);
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
