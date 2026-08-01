import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'warp_generator.dart';

class VPNService extends ChangeNotifier {
  bool _isConnected = false;
  bool _isConnecting = false;
  String _statusMessage = 'برای اتصال کلیک کنید';
  Map<String, dynamic>? _serverInfo;
  String? _generatedConfig;

  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  String get statusMessage => _statusMessage;
  Map<String, dynamic>? get serverInfo => _serverInfo;
  String? get generatedConfig => _generatedConfig;

  Future<void> connect() async {
    if (_isConnecting) return;
    
    _isConnecting = true;
    _statusMessage = 'در حال انتخاب بهترین سرور...';
    notifyListeners();

    try {
      final configData = await WARPGenerator.generateFullConfig();
      _generatedConfig = configData['config'];
      
      _statusMessage = 'دریافت اطلاعات VPS...';
      notifyListeners();

      try {
        final response = await http.get(Uri.parse('https://ipapi.co/${configData['ip']}/json/')).timeout(const Duration(seconds: 5));
        if (response.statusCode == 200) {
          _serverInfo = json.decode(response.body);
        } else {
          throw Exception('API Error');
        }
      } catch (_) {
        _serverInfo = {
          'ip': configData['ip'], 
          'city': 'Cloudflare Edge', 
          'org': 'WARP Network',
          'country_name': 'Global Anycast'
        };
      }

      _isConnected = true;
      _isConnecting = false;
      _statusMessage = 'متصل شد';
      notifyListeners();
      
    } catch (e) {
      _isConnecting = false;
      _statusMessage = 'خطا در ارتباط';
      notifyListeners();
    }
  }

  void disconnect() {
    _isConnected = false;
    _serverInfo = null;
    _generatedConfig = null;
    _statusMessage = 'ارتباط قطع شد';
    notifyListeners();
  }
}
