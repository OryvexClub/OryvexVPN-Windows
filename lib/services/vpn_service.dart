import 'package:flutter/foundation.dart';
import 'dart:async';
import 'wireguard_service.dart';
import 'ipinfo_service.dart';
import '../utils/error_handler.dart';

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
  ConnectionStats _stats = ConnectionStats.initial();
  Timer? _statsTimer;
  Timer? _connectionCheckTimer;

  // Previous stats for speed calculation
  int _previousTxBytes = 0;
  int _previousRxBytes = 0;
  DateTime _lastStatsUpdate = DateTime.now();

  VpnStage get stage => _stage;
  bool get isConnected => _stage == VpnStage.connected;
  bool get isConnecting =>
      _stage == VpnStage.fetchingConfig || _stage == VpnStage.installingTunnel;
  String get statusMessage => _statusMessage;
  String? get lastError => _lastError;
  ConnectionStats get stats => _stats;

  void _updateStatus(String msg) {
    _statusMessage = msg;
    notifyListeners();
  }

  Future<void> initStatus() async {
    // Check actual connection status on startup
    final actuallyConnected = await WireGuardService.isConnected();
    if (actuallyConnected) {
      _stage = VpnStage.connected;
      _statusMessage = 'متصل شد';
      _startStatsMonitoring();
      _startConnectionMonitoring();
      notifyListeners();
    } else {
      _stage = VpnStage.idle;
      _statusMessage = 'برای اتصال کلیک کنید';
      notifyListeners();
    }
  }

  void _startStatsMonitoring() {
    _statsTimer?.cancel();
    _statsTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      await _updateStats();
    });
    _updateStats(); // Initial update
  }

  void _stopStatsMonitoring() {
    _statsTimer?.cancel();
    _statsTimer = null;
    _stats = ConnectionStats.initial();
    _previousTxBytes = 0;
    _previousRxBytes = 0;
  }

  void _startConnectionMonitoring() {
    _connectionCheckTimer?.cancel();
    _connectionCheckTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      await _checkConnectionStatus();
    });
  }

  void _stopConnectionMonitoring() {
    _connectionCheckTimer?.cancel();
    _connectionCheckTimer = null;
  }

  Future<void> _checkConnectionStatus() async {
    if (_stage != VpnStage.connected) return;

    try {
      final actuallyConnected = await WireGuardService.isConnected();
      if (!actuallyConnected) {
        // Connection was lost unexpectedly
        _stage = VpnStage.error;
        _lastError = 'اتصال به طور غیرمنتظره قطع شد';
        _statusMessage = 'قطع شد';
        _stopStatsMonitoring();
        _stopConnectionMonitoring();
        notifyListeners();
      }
    } catch (e) {
      print('Error checking connection status: $e');
    }
  }

  Future<void> _updateStats() async {
    if (!isConnected) return;

    try {
      // Get IP info
      final ipInfo = await ErrorHandler.tryCatch(
        () => IPInfoService.getIPInfo(),
        fallback: IPInfoModel.unknown(),
        context: 'Get IP Info',
      );

      // Measure ping to Cloudflare
      final ping = await ErrorHandler.tryCatch(
        () => IPInfoService.measurePing('1.1.1.1'),
        fallback: -1,
        context: 'Measure Ping',
      );

      // Get connection statistics
      final networkStats = await ErrorHandler.tryCatch(
        () => WireGuardService.getConnectionStats(),
        fallback: {'tx_bytes': 0, 'rx_bytes': 0},
        context: 'Get Network Stats',
      );

      final now = DateTime.now();
      final timeDiff = now.difference(_lastStatsUpdate).inSeconds;

      double downloadSpeed = 0.0;
      double uploadSpeed = 0.0;

      if (timeDiff > 0 && networkStats != null) {
        final txBytes = networkStats['tx_bytes'] as int;
        final rxBytes = networkStats['rx_bytes'] as int;

        // Calculate speeds in KB/s
        if (_previousRxBytes > 0 && rxBytes > _previousRxBytes) {
          downloadSpeed = (rxBytes - _previousRxBytes) / timeDiff / 1024;
        }
        if (_previousTxBytes > 0 && txBytes > _previousTxBytes) {
          uploadSpeed = (txBytes - _previousTxBytes) / timeDiff / 1024;
        }

        _previousRxBytes = rxBytes;
        _previousTxBytes = txBytes;
      }

      _lastStatsUpdate = now;

      _stats = ConnectionStats(
        ping: (ping ?? -1) > 0 ? ping! : 0,
        downloadSpeed: downloadSpeed > 0 ? downloadSpeed : 0.0,
        uploadSpeed: uploadSpeed > 0 ? uploadSpeed : 0.0,
        ipInfo: ipInfo ?? IPInfoModel.unknown(),
        timestamp: now,
      );

      notifyListeners();
    } catch (e) {
      AppLogger.error('Error updating stats', e);
    }
  }

  Future<void> connect() async {
    if (isConnecting) return;

    AppLogger.connectionState('Connecting');
    _lastError = null;
    _stage = VpnStage.fetchingConfig;
    _statusMessage = 'در حال دریافت تنظیمات...';
    notifyListeners();

    try {
      await WireGuardService.connectWithProgress((msg) {
        _stage = VpnStage.installingTunnel;
        // Translate progress messages
        String translatedMsg = msg;
        if (msg.contains('Finding fastest server')) {
          translatedMsg = 'در حال یافتن سریع‌ترین سرور...';
        } else if (msg.contains('Registering')) {
          translatedMsg = 'در حال ثبت‌نام با Cloudflare WARP...';
        } else if (msg.contains('Starting secure tunnel')) {
          translatedMsg = 'در حال راه‌اندازی تونل امن...';
        } else if (msg.contains('Verifying')) {
          translatedMsg = 'در حال تایید اتصال...';
        }
        AppLogger.info(translatedMsg, 'VPN');
        _updateStatus(translatedMsg);
      });

      // Verify connection multiple times to ensure stability
      await Future.delayed(const Duration(seconds: 1));
      final actuallyUp = await WireGuardService.isConnected();
      if (!actuallyUp) {
        throw Exception('تونل بعد از تنظیمات فعال نیست');
      }

      // Double-check after another second
      await Future.delayed(const Duration(seconds: 1));
      final stillUp = await WireGuardService.isConnected();
      if (!stillUp) {
        throw Exception('تونل بلافاصله بعد از اتصال قطع شد');
      }

      _stage = VpnStage.connected;
      _updateStatus('متصل شد');
      AppLogger.connectionState('Connected');
      _startStatsMonitoring();
      _startConnectionMonitoring();
    } catch (e, stackTrace) {
      AppLogger.error('Connection failed', e, stackTrace, 'VPN');
      _stage = VpnStage.error;
      _lastError = ErrorHandler.getUserFriendlyMessage(e);
      _updateStatus('اتصال ناموفق بود');
      _stopStatsMonitoring();
      _stopConnectionMonitoring();
    }
    notifyListeners();
  }

  Future<void> disconnect() async {
    AppLogger.connectionState('Disconnecting');
    _stage = VpnStage.disconnecting;
    _updateStatus('در حال قطع اتصال...');
    _stopStatsMonitoring();
    _stopConnectionMonitoring();

    try {
      await WireGuardService.disconnect();

      // Verify disconnection
      await Future.delayed(const Duration(milliseconds: 500));
      final stillConnected = await WireGuardService.isConnected();
      if (stillConnected) {
        throw Exception('تونل هنوز فعال است');
      }

      _stage = VpnStage.idle;
      _updateStatus('قطع شد');
      _lastError = null;
      AppLogger.connectionState('Disconnected');
    } catch (e, stackTrace) {
      AppLogger.error('Disconnect failed', e, stackTrace, 'VPN');
      _stage = VpnStage.error;
      _lastError = ErrorHandler.getUserFriendlyMessage(e);
      _updateStatus('قطع اتصال ناموفق بود');
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _stopStatsMonitoring();
    _stopConnectionMonitoring();
    super.dispose();
  }
}
