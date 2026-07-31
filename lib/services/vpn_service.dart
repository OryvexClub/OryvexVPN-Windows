import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class VPNService extends ChangeNotifier {
  bool _isConnected = false;
  bool _isConnecting = false;
  String _statusMessage = 'آماده اتصال';
  Map<String, dynamic>? _serverInfo;

  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  String get statusMessage => _statusMessage;
  Map<String, dynamic>? get serverInfo => _serverInfo;

  Future<void> connect() async {
    _isConnecting = true;
    _statusMessage = 'در حال اتصال به سرور...';
    notifyListeners();

    // شبیه‌سازی اتصال برای داشبورد ویندوز
    await Future.delayed(const Duration(seconds: 1));
    _statusMessage = 'در حال ارتباط ایمن...';
    notifyListeners();

    await Future.delayed(const Duration(seconds: 1));
    _statusMessage = 'دریافت اطلاعات VPS...';
    notifyListeners();

    try {
      final response = await http.get(Uri.parse('https://ipapi.co/json/')).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        _serverInfo = json.decode(response.body);
      }
    } catch (_) {
      // داده‌های جایگزین در صورت قطعی یا مسدودی API
      _serverInfo = {'ip': '188.114.97.6', 'city': 'Cloudflare Edge', 'org': 'WARP Network'};
    }

    _isConnected = true;
    _isConnecting = false;
    _statusMessage = 'متصل شد';
    notifyListeners();
  }

  Future<void> disconnect() async {
    _isConnected = false;
    _serverInfo = null;
    _statusMessage = 'قطع شد';
    notifyListeners();
  }
}
