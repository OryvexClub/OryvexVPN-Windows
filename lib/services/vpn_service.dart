import 'package:flutter/foundation.dart';
import 'dart:io';
import 'warp_generator.dart';
import '../constants/strings.dart';

class VPNService extends ChangeNotifier {
  bool _isConnected = false, _isConnecting = false;
  String _statusMessage = Strings.statusReady;
  String? _currentConfig, _errorMessage;
  Map<String, dynamic>? _accountInfo;
  String _selectedEndpoint = '';
  final WARPGenerator _generator = WARPGenerator();

  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  String get statusMessage => _statusMessage;
  Map<String, dynamic>? get accountInfo => _accountInfo;
  String get selectedEndpoint => _selectedEndpoint;
  String? get errorMessage => _errorMessage;

  Future<bool> generateAndConnect({String? customIp, String? customPort}) async {
    if (_isConnected) await disconnect();
    _isConnecting = true;
    _statusMessage = Strings.statusGenerating;
    _errorMessage = null;
    notifyListeners();

    try {
      _statusMessage = Strings.statusGeneratingKey;
      notifyListeners();

      final config = await _generator.generateFullConfig(
          customIp: customIp, customPort: customPort);

      _accountInfo = _generator.getAccountInfo();
      _currentConfig = config;

      final lines = config.split('\n');
      for (var line in lines) {
        if (line.startsWith('Endpoint = ')) {
          _selectedEndpoint = line.replaceFirst('Endpoint = ', '');
          break;
        }
      }

      _statusMessage = Strings.statusConnecting;
      notifyListeners();

      // Mock connection logic for UI Dashboard
      await Future.delayed(const Duration(seconds: 2));

      _isConnected = true;
      _statusMessage = Strings.statusConnected;
      _isConnecting = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isConnecting = false;
      _statusMessage = Strings.statusError;
      _errorMessage = e.toString();
      _isConnected = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> disconnect() async {
    _isConnected = false;
    _currentConfig = null;
    _statusMessage = Strings.statusDisconnected;
    notifyListeners();
  }

  String? getConfig() => _currentConfig;
}
