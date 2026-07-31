import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';
import 'package:http/http.dart' as http;


class WARPGenerator {
  static const String WARP_API_URL = "https://api.cloudflareclient.com/v0a737/reg";
  String? privateKey, publicKey;
  Map<String, dynamic>? responseData;

  static final List<Map<String, String>> endpoints = [
    {"ip": "8.6.112.165", "port": "928"}, {"ip": "8.6.112.139", "port": "7281"},
    {"ip": "8.6.112.178", "port": "942"}, {"ip": "8.6.112.205", "port": "3581"},
    {"ip": "8.6.112.176", "port": "8319"}, {"ip": "8.6.112.190", "port": "5279"},
    {"ip": "8.6.112.121", "port": "500"}, {"ip": "8.6.112.202", "port": "878"},
    {"ip": "8.6.112.223", "port": "7559"}, {"ip": "8.6.112.230", "port": "1843"},
    {"ip": "8.6.112.200", "port": "4198"}, {"ip": "8.6.112.233", "port": "7152"},
    {"ip": "8.6.112.4", "port": "4233"}, {"ip": "8.6.112.159", "port": "878"},
    {"ip": "8.6.112.4", "port": "859"}, {"ip": "8.6.112.233", "port": "880"},
    {"ip": "8.6.112.93", "port": "942"}, {"ip": "8.6.112.93", "port": "945"},
    {"ip": "8.6.112.182", "port": "945"}, {"ip": "8.6.112.133", "port": "968"},
    {"ip": "8.6.112.52", "port": "928"}, {"ip": "8.6.112.121", "port": "1180"},
    {"ip": "8.6.112.78", "port": "859"}, {"ip": "8.6.112.205", "port": "891"},
    {"ip": "8.6.112.248", "port": "903"}, {"ip": "8.6.112.246", "port": "894"},
    {"ip": "8.6.112.230", "port": "878"}, {"ip": "8.6.112.246", "port": "859"},
    {"ip": "8.6.112.172", "port": "878"}, {"ip": "8.6.112.104", "port": "4233"},
    {"ip": "8.6.112.249", "port": "891"}, {"ip": "8.6.112.46", "port": "4198"},
    {"ip": "8.6.112.234", "port": "3854"}, {"ip": "8.6.112.136", "port": "4177"},
    {"ip": "8.6.112.224", "port": "8886"}, {"ip": "8.6.112.251", "port": "1387"},
    {"ip": "8.6.112.127", "port": "4198"}, {"ip": "8.6.112.200", "port": "1010"},
    {"ip": "8.6.112.237", "port": "946"}, {"ip": "8.6.112.82", "port": "891"},
    {"ip": "8.6.112.170", "port": "1180"}, {"ip": "8.6.112.29", "port": "7152"},
    {"ip": "8.6.112.7", "port": "1180"}, {"ip": "8.6.112.182", "port": "891"},
    {"ip": "8.6.112.67", "port": "7103"}, {"ip": "188.114.97.6", "port": "7281"},
    {"ip": "8.6.112.235", "port": "1070"}, {"ip": "8.6.112.228", "port": "1843"},
    {"ip": "8.6.112.19", "port": "908"}, {"ip": "8.6.112.184", "port": "7281"},
    {"ip": "8.6.112.51", "port": "2506"}, {"ip": "188.114.97.6", "port": "859"},
    {"ip": "8.6.112.8", "port": "1014"}, {"ip": "8.6.112.253", "port": "854"},
    {"ip": "8.6.112.221", "port": "500"}, {"ip": "8.6.112.96", "port": "903"},
    {"ip": "8.6.112.174", "port": "1014"}, {"ip": "8.6.112.212", "port": "880"},
    {"ip": "8.6.112.154", "port": "7281"}, {"ip": "8.6.112.65", "port": "2506"},
    {"ip": "8.6.112.171", "port": "946"}, {"ip": "8.6.112.160", "port": "3854"},
    {"ip": "8.6.112.86", "port": "1387"}, {"ip": "8.6.112.163", "port": "7281"},
    {"ip": "8.6.112.29", "port": "3581"}, {"ip": "8.6.112.122", "port": "4177"},
    {"ip": "8.6.112.154", "port": "891"}, {"ip": "8.6.112.174", "port": "939"},
    {"ip": "8.6.112.70", "port": "945"}, {"ip": "8.6.112.53", "port": "7156"},
    {"ip": "8.6.112.165", "port": "7281"}, {"ip": "8.6.112.181", "port": "7152"},
    {"ip": "8.6.112.122", "port": "894"}, {"ip": "8.6.112.191", "port": "908"},
    {"ip": "8.6.112.79", "port": "8854"}, {"ip": "8.6.112.180", "port": "928"},
    {"ip": "8.6.112.61", "port": "3581"}, {"ip": "8.6.112.224", "port": "854"},
    {"ip": "8.6.112.77", "port": "1070"}, {"ip": "8.6.112.107", "port": "3138"},
    {"ip": "8.6.112.106", "port": "3138"}, {"ip": "8.6.112.60", "port": "8854"},
    {"ip": "162.159.192.1", "port": "2408"}, {"ip": "162.159.192.1", "port": "500"},
    {"ip": "162.159.192.1", "port": "4500"}, {"ip": "162.159.192.2", "port": "2408"},
    {"ip": "162.159.193.1", "port": "2408"}, {"ip": "162.159.193.5", "port": "2408"},
    {"ip": "162.159.195.1", "port": "2408"}, {"ip": "188.114.97.6", "port": "7281"},
    {"ip": "188.114.97.6", "port": "859"}, {"ip": "104.16.248.249", "port": "2408"},
    {"ip": "104.16.249.249", "port": "2408"},
  ];

  static List<Map<String, String>> get uniqueEndpoints {
    final seen = <String>{};
    final unique = <Map<String, String>>[];
    for (var ep in endpoints) {
      final key = '${ep['ip']}:${ep['port']}';
      if (!seen.contains(key)) { seen.add(key); unique.add(ep); }
    }
    return unique;
  }

  static Map<String, String> getRandomEndpoint() {
    final list = uniqueEndpoints;
    return list[Random().nextInt(list.length)];
  }

  bool generateKeypair() {
    privateKey = base64.encode(List.generate(32, (_) => Random().nextInt(256)));
    publicKey = base64.encode(List.generate(32, (_) => Random().nextInt(256)));
    return true;
  } catch (_) { return false; }
  }

  Future<bool> registerWithWarp() async {
    if (publicKey == null) return false;
    final now = DateTime.now().toUtc();
    final tosDate = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}T${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}.000+00:00';
    final payload = {"key": publicKey, "install_id": "", "warp_enabled": true, "tos": tosDate, "type": "Windows", "locale": "fa_IR"};
    try {
      final response = await http.post(Uri.parse(WARP_API_URL), headers: {'Content-Type': 'application/json'}, body: jsonEncode(payload));
      if (response.statusCode == 200) { responseData = jsonDecode(response.body); return true; }
      return false;
    } catch (_) { return false; }
  }

  String generateConfig({String? customIp, String? customPort}) {
    if (responseData == null) return '';
    final config = responseData!['config'];
    final peer = config['peers'][0];
    final interface = config['interface']['addresses'];
    final peerPublicKey = peer['public_key'] as String?;
    String endpointHost = peer['endpoint']?['host'] ?? '';
    final interfaceIpv4 = interface['v4'] as String?;
    final interfaceIpv6 = interface['v6'] as String?;
    if (peerPublicKey == null || endpointHost.isEmpty || interfaceIpv4 == null) return '';
    if (customIp != null && customIp.isNotEmpty) {
      final ipStr = customIp.contains(':') ? '[$customIp]' : customIp;
      endpointHost = '$ipStr:${customPort ?? '2408'}';
    }
    final address = (interfaceIpv6 != null && interfaceIpv6 != 'null') ? '$interfaceIpv4/32, $interfaceIpv6/128' : '$interfaceIpv4/32';
    final buffer = StringBuffer();
    buffer.writeln('[Interface]');
    buffer.writeln('PrivateKey = $privateKey');
    buffer.writeln('Address = $address');
    buffer.writeln('DNS = 1.1.1.1, 1.0.0.1, 2606:4700:4700::1111, 2606:4700:4700::1001');
    buffer.writeln('MTU = 1280');
    buffer.writeln();
    buffer.writeln('[Peer]');
    buffer.writeln('PublicKey = $peerPublicKey');
    buffer.writeln('AllowedIPs = 0.0.0.0/0, ::/0');
    buffer.writeln('Endpoint = $endpointHost');
    buffer.writeln('PersistentKeepalive = 25');
    return buffer.toString();
  }

  Map<String, dynamic> getAccountInfo() {
    if (responseData == null) return {};
    final account = responseData!['account'] ?? {};
    final warpPlus = account['warp_plus'] ?? false;
    return {
      'account_id': account['id'] ?? '-',
      'device_id': responseData!['id'] ?? '-',
      'account_type': '${warpPlus ? 'WARP+ ' : ''}${account['account_type'] ?? 'free'}',
    };
  }

  Future<String> generateFullConfig({String? customIp, String? customPort}) async {
    if (!generateKeypair()) throw Exception('Failed to generate keypair');
    if (!await registerWithWarp()) throw Exception('Failed to register with WARP API');
    final config = generateConfig(customIp: customIp, customPort: customPort);
    if (config.isEmpty) throw Exception('Failed to generate config');
    return config;
  }
}
