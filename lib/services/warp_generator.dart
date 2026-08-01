import 'dart:convert';
import 'dart:math';

class WARPGenerator {
  static final List<Map<String, String>> endpoints = [
    {"ip": "8.6.112.165", "port": "928"}, {"ip": "8.6.112.139", "port": "7281"},
    {"ip": "162.159.192.1", "port": "2408"}, {"ip": "188.114.97.6", "port": "7281"},
    {"ip": "104.16.248.249", "port": "2408"}
  ];

  static Map<String, String> getRandomEndpoint() {
    return endpoints[Random().nextInt(endpoints.length)];
  }

  static String _generateMockKey() {
    final bytes = List<int>.generate(32, (i) => Random().nextInt(256));
    return base64Encode(bytes);
  }

  static Future<Map<String, dynamic>> generateFullConfig() async {
    final privateKey = _generateMockKey();
    final publicKey = _generateMockKey();
    final endpoint = getRandomEndpoint();
    
    await Future.delayed(const Duration(milliseconds: 800));
    final endpointHost = '${endpoint['ip']}:${endpoint['port']}';
    
    final buffer = StringBuffer();
    buffer.writeln('[Interface]');
    buffer.writeln('PrivateKey = $privateKey');
    buffer.writeln('Address = 172.16.0.2/32, 2606:4700:1111::2/128');
    buffer.writeln('DNS = 1.1.1.1, 1.0.0.1');
    buffer.writeln('MTU = 1280');
    buffer.writeln();
    buffer.writeln('[Peer]');
    buffer.writeln('PublicKey = $publicKey');
    buffer.writeln('AllowedIPs = 0.0.0.0/0, ::/0');
    buffer.writeln('Endpoint = $endpointHost');
    buffer.writeln('PersistentKeepalive = 25');

    return {
      'config': buffer.toString(),
      'endpoint': endpointHost,
      'ip': endpoint['ip'],
    };
  }
}
