import 'dart:convert';
import 'dart:math';

class WARPGenerator {
  static final Random _random = Random.secure();

  static String _generateKey() {
    final bytes = List<int>.generate(32, (i) => _random.nextInt(256));
    return base64Encode(bytes);
  }

  static String generateConfig() {
    final privKey = _generateKey();
    
    return '''[Interface]
PrivateKey = $privKey
Address = 172.16.0.2/32
DNS = 1.1.1.1
MTU = 1280

[Peer]
PublicKey = bm90X2FfcmVhbF9wdWJsaWNfa2V5X2xvbmdfc3RyaW5n=
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = 162.159.192.1:2408
PersistentKeepalive = 25''';
  }
}
