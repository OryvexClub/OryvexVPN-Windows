import 'package:flutter/foundation.dart';
import 'wireguard_service.dart';

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
  String _serverUrl = '';
  String _token = '';

  VpnStage get stage => _stage;
  bool get isConnected => _stage == VpnStage.connected;
  bool get isConnecting =>
      _stage == VpnStage.fetchingConfig || _stage == VpnStage.installingTunnel;
  String get statusMessage => _statusMessage;
  String? get lastError => _lastError;
  String get serverUrl => _serverUrl;

  Future<void> loadSettings() async {
    final s = await WireGuardService.loadServerSettings();
    _serverUrl = s['url'] ?? '';
    _token = s['token'] ?? '';

    // وضعیت واقعی سرویس ویندوز را چک می‌کنیم تا اگر تانل از قبل بالا بود
    // رابط کاربری با واقعیت هماهنگ باشد (نه صرفاً یک متغیر محلی).
    if (await WireGuardService.isConnected()) {
      _stage = VpnStage.connected;
      _statusMessage = 'متصل';
      notifyListeners();
    }
  }

  Future<void> saveSettings(String url, String token) async {
    _serverUrl = url;
    _token = token;
    await WireGuardService.saveServerSettings(url, token);
    notifyListeners();
  }

  Future<void> connect() async {
    if (isConnecting) return;

    if (_serverUrl.trim().isEmpty) {
      _lastError = 'ابتدا آدرس سرور VPS را در تنظیمات وارد کنید';
      _stage = VpnStage.error;
      _statusMessage = 'اتصال ناموفق بود';
      notifyListeners();
      return;
    }

    _lastError = null;
    _stage = VpnStage.fetchingConfig;
    _statusMessage = 'در حال دریافت کانفیگ از سرور...';
    notifyListeners();

    try {
      final config = await WireGuardService.fetchConfig(
        serverUrl: _serverUrl,
        token: _token,
      );

      _stage = VpnStage.installingTunnel;
      _statusMessage = 'در حال برقراری تانل WireGuard...';
      notifyListeners();

      await WireGuardService.connect(config);

      // هرگز صرفاً بر اساس موفقیت فراخوانی ادعای اتصال نمی‌کنیم؛ از خود
      // ویندوز می‌پرسیم که سرویس واقعاً در حال اجراست یا نه.
      final actuallyUp = await WireGuardService.isConnected();
      if (!actuallyUp) {
        throw Exception(
          'تانل نصب شد ولی سرویس ویندوز آن را «در حال اجرا» گزارش نمی‌دهد',
        );
      }

      _stage = VpnStage.connected;
      _statusMessage = 'متصل';
    } catch (e) {
      _stage = VpnStage.error;
      _lastError = e.toString().replaceFirst('Exception: ', '');
      _statusMessage = 'اتصال ناموفق بود';
    }
    notifyListeners();
  }

  Future<void> disconnect() async {
    _stage = VpnStage.disconnecting;
    _statusMessage = 'در حال قطع اتصال...';
    notifyListeners();

    await WireGuardService.disconnect();

    _stage = VpnStage.idle;
    _statusMessage = 'قطع شد';
    notifyListeners();
  }
}
