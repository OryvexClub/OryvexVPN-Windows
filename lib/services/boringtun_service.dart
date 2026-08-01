import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cryptography/cryptography.dart';
import 'package:path_provider/path_provider.dart';

class BoringTunService {
  static const _tunnelName = 'oryvexvpn';
  static Process? _tunnelProcess;
  static bool _connected = false;

  static const List<String> _endpoints = [
    "162.159.192.1", "162.159.192.2", "162.159.193.1", "162.159.193.5",
    "188.114.96.0", "188.114.96.1", "188.114.97.1", "188.114.98.1"
  ];

  static String get _exeDir => File(Platform.resolvedExecutable).parent.path;
  static String get _boringTunExe => '$_exeDir\\data\\boringtun.exe';

  static Future<bool> _coreFilesPresent() async => File(_boringTunExe).exists();

  static Future<String> _confDir() async {
    final dir = await getApplicationSupportDirectory();
    final confDir = Directory('${dir.path}\\oryvexvpn');
    if (!await confDir.exists()) await confDir.create(recursive: true);
    return confDir.path;
  }

  static Future<Map<String, dynamic>> _findBestEndpoint(Function(String) onProgress) async {
    onProgress('Finding best server...');
    final futures = _endpoints.map((ip) async {
      try {
        final start = DateTime.now();
        final res = await Process.run('ping', ['-n', '1', '-w', '2000', ip]);
        if (res.exitCode == 0) {
          final latency = DateTime.now().difference(start).inMilliseconds;
          return {'ip': ip, 'latency': latency};
        }
      } catch (_) {}
      return {'ip': ip, 'latency': 9999};
    });

    final results = await Future.wait(futures);
    results.sort((a, b) => (a['latency'] as int).compareTo(b['latency'] as int));

    final best = results.first['latency'] != 9999 ? results.first : {'ip': _endpoints.first, 'latency': 100};
    return best as Map<String, dynamic>;
  }

  static Future<_WarpRegistration> _register(Function(String) onProgress) async {
    final algorithm = X25519();
    final keyPair = await algorithm.newKeyPair();
    final publicKey = await keyPair.extractPublicKey();
    final privateKeyBytes = await keyPair.extractPrivateKeyBytes();

    final pubKeyBase64 = base64Encode(publicKey.bytes);
    final privKeyBase64 = base64Encode(privateKeyBytes);

    onProgress('Registering with Cloudflare...');
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
      throw Exception('Device registration failed.');
    }

    final data = jsonDecode(response.body);
    final peer = data['config']['peers'][0];
    final address = (data['config']['interface']['addresses']['v4'] as String);

    final endpointData = await _findBestEndpoint(onProgress);

    return _WarpRegistration(
      privateKeyBase64: privKeyBase64,
      address: address,
      peerPublicKeyBase64: peer['public_key'] as String,
      endpointIp: endpointData['ip'] as String,
      endpointPort: '2408',
      serverLatency: endpointData['latency'] as int,
    );
  }

  static String _buildConf(_WarpRegistration reg) {
    final b = StringBuffer();
    b.writeln('[Interface]');
    b.writeln('PrivateKey = ${reg.privateKeyBase64}');
    b.writeln('Address = ${reg.address}');
    b.writeln('DNS = 1.1.1.1, 1.0.0.1');
    b.writeln('MTU = 1420');
    b.writeln('');
    b.writeln('[Peer]');
    b.writeln('PublicKey = ${reg.peerPublicKeyBase64}');
    b.writeln('Endpoint = ${reg.endpointIp}:${reg.endpointPort}');
    b.writeln('AllowedIPs = 0.0.0.0/0, ::/0');
    b.writeln('PersistentKeepalive = 25');
    return b.toString();
  }

  static Future<void> _startBoringTun(_WarpRegistration reg) async {
    final confDir = await _confDir();
    final confFile = File('$confDir\\$_tunnelName.conf');
    await confFile.writeAsString(_buildConf(reg));

    // Create TUN interface using netsh
    try {
      // Add route to ensure traffic goes through VPN
      await Process.run('netsh', ['interface', 'ip', 'set', 'dns', 'name=OryvexVPN', 'static', '1.1.1.1']);
    } catch (_) {}

    // Start BoringTun userspace implementation
    _tunnelProcess = await Process.start(
      _boringTunExe,
      [
        '--disable-drop-privileges',
        '--foreground',
        'OryvexVPN',
      ],
      environment: {
        'WG_QUICK_USERSPACE_IMPLEMENTATION': _boringTunExe,
        'WG_SUDO': '1',
      },
    );

    // Monitor process output
    _tunnelProcess!.stdout.transform(utf8.decoder).listen((data) {
      print('BoringTun: $data');
    });

    _tunnelProcess!.stderr.transform(utf8.decoder).listen((data) {
      print('BoringTun Error: $data');
    });

    await Future.delayed(const Duration(milliseconds: 1500));
  }

  static Future<void> connectWithProgress(Function(String) onProgress) async {
    if (!await _coreFilesPresent()) {
      throw Exception('BoringTun core files not found.');
    }

    final reg = await _register(onProgress);
    onProgress('Starting tunnel...');
    await _startBoringTun(reg);
    _connected = true;
  }

  static Future<void> connect() async => await connectWithProgress((_) {});

  static Future<void> disconnect() async {
    if (!Platform.isWindows) return;

    try {
      _tunnelProcess?.kill(ProcessSignal.sigterm);
      _tunnelProcess = null;

      // Clean up interface
      await Process.run('netsh', ['interface', 'ip', 'delete', 'address', 'OryvexVPN', 'all']);
    } catch (_) {}

    _connected = false;
  }

  static Future<bool> isConnected() async {
    if (!Platform.isWindows) return false;
    return _tunnelProcess != null && _connected;
  }

  static Future<Map<String, dynamic>> getConnectionStats() async {
    if (!_connected) {
      return {
        'tx_bytes': 0,
        'rx_bytes': 0,
        'tx_speed': 0.0,
        'rx_speed': 0.0,
      };
    }

    try {
      // Get network statistics from netsh
      final result = await Process.run('netsh', ['interface', 'ipv4', 'show', 'interfaces']);

      // Parse output for OryvexVPN interface
      // This is a simplified version - in production, parse actual statistics
      return {
        'tx_bytes': 0,
        'rx_bytes': 0,
        'tx_speed': 0.0,
        'rx_speed': 0.0,
      };
    } catch (_) {
      return {
        'tx_bytes': 0,
        'rx_bytes': 0,
        'tx_speed': 0.0,
        'rx_speed': 0.0,
      };
    }
  }
}

class _WarpRegistration {
  final String privateKeyBase64, address, peerPublicKeyBase64, endpointIp, endpointPort;
  final int serverLatency;

  const _WarpRegistration({
    required this.privateKeyBase64,
    required this.address,
    required this.peerPublicKeyBase64,
    required this.endpointIp,
    required this.endpointPort,
    required this.serverLatency,
  });
}
