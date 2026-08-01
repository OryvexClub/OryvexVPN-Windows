import 'dart:io';
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
    final file = File('${dir.path}\\_tunnelName.conf');
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
        'Failed to install tunnel. Please run this app as Administrator.\n'
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
        ['query', 'WireGuardTunnel\$$_tunnelName'],
        runInShell: true,
      );
      return result.stdout.toString().contains('RUNNING');
    } catch (_) {
      return false;
    }
  }
}
