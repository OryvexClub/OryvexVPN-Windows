import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cryptography/cryptography.dart';

import '../core/config.dart';
import 'endpoints.dart';

/// Everything needed to build a working `.conf` for the Cloudflare
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

  /// Produces the configuration text with junk packet obfuscation.
  /// [antiDpiPreset] selects the obfuscation profile (e.g. 'standard', 'minimal').
  String buildConf({bool isFullTunnel = true, String antiDpiPreset = 'standard'}) {
    final antiDpi = AppConfig.getAntiDpiValues(antiDpiPreset);
    final b = StringBuffer();
    b.writeln('# Generated OryvexVPN Config');
    b.writeln('[Interface]');
    b.writeln('PrivateKey = $privateKey');

    // Format address exactly like Python script output
    if (addressV6.isNotEmpty && addressV6 != 'null') {
      b.writeln('Address = $addressV4/32, $addressV6/128');
    } else {
      b.writeln('Address = $addressV4/32');
    }

    b.writeln('DNS = 1.1.1.1, 1.0.0.1, 2606:4700:4700::1111, 2606:4700:4700::1001');
    b.writeln('MTU = ${AppConfig.mtu}');

    b.writeln('Jc = ${antiDpi['jc']}');
    b.writeln('Jmin = ${antiDpi['jmin']}');
    b.writeln('Jmax = ${antiDpi['jmax']}');
    b.writeln('S1 = ${antiDpi['s1']}');
    b.writeln('S2 = ${antiDpi['s2']}');
    b.writeln('H1 = ${antiDpi['h1']}');
    b.writeln('H2 = ${antiDpi['h2']}');
    b.writeln('H3 = ${antiDpi['h3']}');
    b.writeln('H4 = ${antiDpi['h4']}');

    b.writeln('');
    b.writeln('[Peer]');
    b.writeln('PublicKey = $peerPublicKey');

    if (isFullTunnel) {
      b.writeln('AllowedIPs = 0.0.0.0/0, ::/0');
    } else {
      // Split tunnel: Route all public IPs, but bypass local LAN (10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16)
      b.writeln('AllowedIPs = 0.0.0.0/5, 8.0.0.0/7, 11.0.0.0/8, 12.0.0.0/6, 16.0.0.0/4, 32.0.0.0/3, 64.0.0.0/2, 128.0.0.0/3, 160.0.0.0/5, 168.0.0.0/6, 172.0.0.0/12, 172.32.0.0/11, 172.64.0.0/10, 172.128.0.0/9, 173.0.0.0/8, 174.0.0.0/7, 176.0.0.0/4, 192.0.0.0/9, 192.128.0.0/11, 192.160.0.0/13, 192.169.0.0/16, 192.170.0.0/15, 192.172.0.0/14, 192.176.0.0/12, 192.192.0.0/10, 193.0.0.0/8, 194.0.0.0/7, 196.0.0.0/6, 200.0.0.0/5, 208.0.0.0/4');
    }

    b.writeln('Endpoint = ${endpoint.hostPort}');
    b.writeln('PersistentKeepalive = ${AppConfig.persistentKeepaliveSeconds}');
    return b.toString();
  }

  /// Produces a standard configuration without obfuscation parameters.
  String buildStandardConf({bool isFullTunnel = true, String antiDpiPreset = 'standard'}) {
    final b = StringBuffer();
    b.writeln('# Standard OryvexVPN Config');
    b.writeln('[Interface]');
    b.writeln('PrivateKey = $privateKey');

    if (addressV6.isNotEmpty && addressV6 != 'null') {
      b.writeln('Address = $addressV4/32, $addressV6/128');
    } else {
      b.writeln('Address = $addressV4/32');
    }

    b.writeln('DNS = 1.1.1.1, 1.0.0.1');
    b.writeln('MTU = ${AppConfig.mtu}');
    b.writeln('');
    b.writeln('[Peer]');
    b.writeln('PublicKey = $peerPublicKey');

    if (isFullTunnel) {
      b.writeln('AllowedIPs = 0.0.0.0/0, ::/0');
    } else {
      b.writeln('AllowedIPs = 0.0.0.0/5, 8.0.0.0/7, 11.0.0.0/8, 12.0.0.0/6, 16.0.0.0/4, 32.0.0.0/3, 64.0.0.0/2, 128.0.0.0/3, 160.0.0.0/5, 168.0.0.0/6, 172.0.0.0/12, 172.32.0.0/11, 172.64.0.0/10, 172.128.0.0/9, 173.0.0.0/8, 174.0.0.0/7, 176.0.0.0/4, 192.0.0.0/9, 192.128.0.0/11, 192.160.0.0/13, 192.169.0.0/16, 192.170.0.0/15, 192.172.0.0/14, 192.176.0.0/12, 192.192.0.0/10, 193.0.0.0/8, 194.0.0.0/7, 196.0.0.0/6, 200.0.0.0/5, 208.0.0.0/4');
    }

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
        "type": AppConfig.deviceType,
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
