import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

class WARPGenerator {
  static const String WARP_API_URL = "https://api.cloudflareclient.com/v0a737/reg";
  String? privateKey, publicKey;
  Map<String, dynamic>? responseData;

  static final List<Map<String, String>> endpoints = [
    {"ip": "162.159.192.1", "port": "2408"},
    {"ip": "188.114.97.6", "port": "7281"},
    {"ip": "8.6.112.165", "port": "928"}
  ];

  static List<Map<String, String>> get uniqueEndpoints => endpoints;

  static Map<String, String> getRandomEndpoint() {
    return endpoints[Random().nextInt(endpoints.length)];
  }

  bool generateKeypair() {
    privateKey = base64.encode(List.generate(32, (_) => Random().nextInt(256)));
    publicKey = base64.encode(List.generate(32, (_) => Random().nextInt(256)));
    return true;
  }

  Future<bool> registerWithWarp() async {
    await Future.delayed(const Duration(milliseconds: 500));
    responseData = {
      'config': {
        'peers': [{'public_key': 'mock_pub_key', 'endpoint': {'host': '162.159.192.1'}}],
        'interface': {'addresses': {'v4': '172.16.0.2', 'v6': '2606:4700::1'}}
      },
      'account': {'id': 'mock_acc', 'account_type': 'free'},
      'id': 'mock_dev'
    };
    return true;
  }

  String generateConfig({String? customIp, String? customPort}) {
    if (responseData == null) return '';
    String endpointHost = '162.159.192.1:2408';
    if (customIp != null && customIp.isNotEmpty) {
      final ipStr = customIp.contains(':') ? '[$customIp]' : customIp;
      endpointHost = '$ipStr:${customPort ?? '2408'}';
    }
    final buffer = StringBuffer();
    buffer.writeln('[Interface]');
    buffer.writeln('PrivateKey = $privateKey');
    buffer.writeln('Address = 172.16.0.2/32');
    buffer.writeln('DNS = 1.1.1.1');
    buffer.writeln('MTU = 1280');
    buffer.writeln();
    buffer.writeln('[Peer]');
    buffer.writeln('PublicKey = mock_pub_key');
    buffer.writeln('AllowedIPs = 0.0.0.0/0, ::/0');
    buffer.writeln('Endpoint = $endpointHost');
    buffer.writeln('PersistentKeepalive = 25');
    return buffer.toString();
  }

  Map<String, dynamic> getAccountInfo() {
    return {
      'account_id': 'mock_account',
      'device_id': 'mock_device_id',
      'account_type': 'free',
    };
  }

  Future<String> generateFullConfig({String? customIp, String? customPort}) async {
    generateKeypair();
    await registerWithWarp();
    return generateConfig(customIp: customIp, customPort: customPort);
  }
}
