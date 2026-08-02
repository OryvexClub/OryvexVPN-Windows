import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cryptography/cryptography.dart';

import '../core/config.dart';
import 'endpoints.dart';

/// Everything needed to build a working WireGuard `.conf` for the Cloudflare
/// WARP tunnel.
class WarpRegistration {
  final String privateKey;
  final String addressV4;
  final String addressV6;
  final String peerPublicKey;
  final VpnEndpoint endpoint;

  const WarpRegistration({
    required this.privateKey,
    required this.addressV4,
    required this.addressV6,
    required this.peerPublicKey,
    required this.endpoint,
  });

  /// Produces the AmneziaWG configuration text with junk packet obfuscation.
  String buildConf() {
    final b = StringBuffer();
    b.writeln('# AmneziaWG WARP Config - Optimized for Iran');
    b.writeln('# Generated: ${DateTime.now().toIso8601String()}');
    b.writeln('');
    b.writeln('[Interface]');
    b.writeln('PrivateKey = $privateKey');
    b.writeln(
      'Address = $addressV4/32, $addressV6/128',
    );
    b.writeln('DNS = 1.1.1.1, 1.0.0.1, 2606:4700:4700::1111, 2606:4700:4700::1001');
    b.writeln('MTU = ${AppConfig.mtu}');

    // AmneziaWG junk packet parameters (Iran-optimized)
    b.writeln('Jc = ${AppConfig.junkPacketCount}');
    b.writeln('Jmin = ${AppConfig.junkPacketMinSize}');
    b.writeln('Jmax = ${AppConfig.junkPacketMaxSize}');
    b.writeln('S1 = ${AppConfig.initPacketJunkSize}');
    b.writeln('S2 = ${AppConfig.responsePacketJunkSize}');
    b.writeln('H1 = ${AppConfig.initPacketMagicHeader}');
    b.writeln('H2 = ${AppConfig.responsePacketMagicHeader}');
    b.writeln('H3 = ${AppConfig.underloadPacketMagicHeader}');
    b.writeln('H4 = ${AppConfig.transportPacketMagicHeader}');

    b.writeln('');
    b.writeln('[Peer]');
    b.writeln('PublicKey = $peerPublicKey');
    b.writeln('AllowedIPs = 0.0.0.0/0, ::/0');
    b.writeln('Endpoint = ${endpoint.hostPort}');
    b.writeln('PersistentKeepalive = ${AppConfig.persistentKeepaliveSeconds}');
    return b.toString();
  }
}

/// Registers a fresh device with Cloudflare WARP and returns the parsed
/// [WarpRegistration] ready to build a config.
class WarpRegistrationService {
  static const String _publicKey = 'bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=';

  static Future<WarpRegistration> register({
    required Future<VpnEndpoint?> Function() resolveEndpoint,
  }) async {
    final algorithm = X25519();
    final keyPair = await algorithm.newKeyPair();
    final publicKeyBytes = await keyPair.extractPublicKey();
    final privateKeyBytes = await keyPair.extractPrivateKeyBytes();

    final pubKeyBase64 = base64Encode(publicKeyBytes.bytes);
    final privKeyBase64 = base64Encode(privateKeyBytes);

    final response = await http.post(
      Uri.parse(AppConfig.warpRegisterUrl),
      headers: {
        'Content-Type': 'application/json',
        'CF-Client-Version': 'a-6.30-3596',
      },
      body: jsonEncode({
        "key": pubKeyBase64,
        "install_id": "",
        "fcm_token": "",
        "warp_enabled": true,
        "tos": DateTime.now().toUtc().toIso8601String(),
        "type": "Windows",
        "model": "PC",
        "locale": "en_US",
      }),
    ).timeout(AppConfig.registerTimeout);

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Registration failed: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    final addressV4 = (data['config']['interface']['addresses']['v4'] as String);
    final addressV6 = data['config']['interface']['addresses']['v6'] as String? ?? '';
    final peerPublicKey = data['config']['peers'][0]['public_key'] as String? ?? _publicKey;

    // Resolve a live endpoint (fastest reachable).
    final endpoint = await resolveEndpoint() ?? const VpnEndpoint('162.159.192.1', 2408);

    return WarpRegistration(
      privateKey: privKeyBase64,
      addressV4: addressV4,
      addressV6: addressV6,
      peerPublicKey: peerPublicKey,
      endpoint: endpoint,
    );
  }
}
