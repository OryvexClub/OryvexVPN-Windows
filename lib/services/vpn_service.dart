import 'package:flutter/foundation.dart';
import 'dart:async';
import 'wireguard_service.dart';
import 'ipinfo_service.dart';

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
  String _statusMessage = 'Click to connect';
  String? _lastError;
  ConnectionStats _stats = ConnectionStats.initial();
  Timer? _statsTimer;

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
    if (await WireGuardService.isConnected()) {
      _stage = VpnStage.connected;
      _statusMessage = 'Connected';
      _startStatsMonitoring();
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

  Future<void> _updateStats() async {
    if (!isConnected) return;

    try {
      // Get IP info
      final ipInfo = await IPInfoService.getIPInfo();

      // Measure ping to Cloudflare
      final ping = await IPInfoService.measurePing('1.1.1.1');

      // Get connection statistics
      final networkStats = await WireGuardService.getConnectionStats();
      final now = DateTime.now();
      final timeDiff = now.difference(_lastStatsUpdate).inSeconds;

      double downloadSpeed = 0.0;
      double uploadSpeed = 0.0;

      if (timeDiff > 0) {
        final txBytes = networkStats['tx_bytes'] as int;
        final rxBytes = networkStats['rx_bytes'] as int;

        // Calculate speeds in KB/s
        downloadSpeed = (rxBytes - _previousRxBytes) / timeDiff / 1024;
        uploadSpeed = (txBytes - _previousTxBytes) / timeDiff / 1024;

        _previousRxBytes = rxBytes;
        _previousTxBytes = txBytes;
      }

      _lastStatsUpdate = now;

      _stats = ConnectionStats(
        ping: ping > 0 ? ping : 0,
        downloadSpeed: downloadSpeed > 0 ? downloadSpeed : 0.0,
        uploadSpeed: uploadSpeed > 0 ? uploadSpeed : 0.0,
        ipInfo: ipInfo,
        timestamp: now,
      );

      notifyListeners();
    } catch (e) {
      print('Error updating stats: $e');
    }
  }

  Future<void> connect() async {
    if (isConnecting) return;

    _lastError = null;
    _stage = VpnStage.fetchingConfig;
    notifyListeners();

    try {
      await WireGuardService.connectWithProgress((msg) {
        _stage = VpnStage.installingTunnel;
        _updateStatus(msg);
      });

      final actuallyUp = await WireGuardService.isConnected();
      if (!actuallyUp) {
        throw Exception('Tunnel not active after configuration.');
      }

      _stage = VpnStage.connected;
      _updateStatus('Connected');
      _startStatsMonitoring();
    } catch (e) {
      _stage = VpnStage.error;
      _lastError = e.toString().replaceFirst('Exception: ', '');
      _updateStatus('Connection failed');
      _stopStatsMonitoring();
    }
    notifyListeners();
  }

  Future<void> disconnect() async {
    _stage = VpnStage.disconnecting;
    _updateStatus('Disconnecting...');
    _stopStatsMonitoring();

    try {
      await WireGuardService.disconnect();
      _stage = VpnStage.idle;
      _updateStatus('Disconnected');
    } catch (e) {
      _stage = VpnStage.error;
      _lastError = e.toString().replaceFirst('Exception: ', '');
      _updateStatus('Disconnect failed');
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _stopStatsMonitoring();
    super.dispose();
  }
}
