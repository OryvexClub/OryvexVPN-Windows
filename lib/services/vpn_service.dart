import 'package:flutter/foundation.dart';
import 'warp_service.dart';

enum VpnStage {
  idle,
  fetchingConfig,
  installingTunnel,
  connected,
  error,
  disconnecting,
}

class VPNService extends ChangeNotifier {
  VpnStage _stage = VpnStage.idle;
  String _statusMessage = 'برای اتصال کلیک کنید';
  String? _lastError;

  VpnStage get stage => _stage;
  bool get isConnected => _stage == VpnStage.connected;
  bool get isConnecting =>
      _stage == VpnStage.fetchingConfig || _stage == VpnStage.installingTunnel;
  String get statusMessage => _statusMessage;
  String? get lastError => _lastError;

  void _updateStatus(String msg) {
    _statusMessage = msg;
    notifyListeners();
  }

  Future<void> initStatus() async {
    if (await WarpService.isConnected()) {
      _stage = VpnStage.connected;
      _statusMessage = 'متصل شد';
      notifyListeners();
    }
  }

  Future<void> connect() async {
    if (isConnecting) return;

    _lastError = null;
    _stage = VpnStage.fetchingConfig;
    notifyListeners();

    try {
      final config = await WarpService.generateConfig(_updateStatus);

      _stage = VpnStage.installingTunnel;
      _updateStatus('در حال درخواست مجوز ادمین برای نصب تونل...');

      await WarpService.connect(config);

      final actuallyUp = await WarpService.isConnected();
      if (!actuallyUp) {
        throw Exception('سرویس ویندوز اجرا نشد.');
      }

      _stage = VpnStage.connected;
      _updateStatus('متصل شد');
    } catch (e) {
      _stage = VpnStage.error;
      _lastError = e.toString().replaceFirst('Exception: ', '');
      _updateStatus('اتصال ناموفق بود');
    }
    notifyListeners();
  }

  Future<void> disconnect() async {
    _stage = VpnStage.disconnecting;
    _updateStatus('در حال قطع اتصال...');

    await WarpService.disconnect();

    _stage = VpnStage.idle;
    _updateStatus('قطع شد');
  }
}
