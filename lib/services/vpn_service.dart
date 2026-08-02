import 'package:flutter/foundation.dart';
import 'dart:async';
import 'wireguard_service.dart';
import 'vpn_core.dart';
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
  String _statusMessage = 'Click to connect';
  String? _lastError;
  ConnectionStats _stats = ConnectionStats.initial();
  Timer? _statsTimer;
  Timer? _connectionCheckTimer;

  DateTime? _connectedAt;
  int _totalDownload = 0;
  int _totalUpload = 0;

  // Previous stats for speed calculation.
  int _previousRxBytes = 0;
  int _previousTxBytes = 0;
  DateTime _lastStatsUpdate = DateTime.now();

  // Auto-recovery bookkeeping.
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 3;
  static const String _tag = 'VPNService';

  VpnStage get stage => _stage;
  bool get isConnected => _stage == VpnStage.connected;
  bool get isConnecting =>
      _stage == VpnStage.fetchingConfig || _stage == VpnStage.installingTunnel;
  String get statusMessage => _statusMessage;
  String? get lastError => _lastError;
  ConnectionStats get stats => _stats;
  DateTime? get connectedAt => _connectedAt;
  int get totalDownload => _totalDownload;
  int get totalUpload => _totalUpload;
  String get currentEndpoint => WireGuardService.currentEndpoint?.hostPort ?? '—';

  /// Human-readable connection duration, or '—' when not connected.
  String get connectedDuration {
    final at = _connectedAt;
    if (at == null) return '—';
    final d = DateTime.now().difference(at);
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  void _updateStatus(String msg) {
    _statusMessage = msg;
    VpnLogger.info(_tag, 'Status: $msg');
    notifyListeners();
  }

  Future<void> initStatus() async {
    VpnLogger.info(_tag, 'initStatus: checking current state...');
    final actuallyConnected = await WireGuardService.isConnected();
    VpnLogger.info(_tag, 'initStatus: actuallyConnected=$actuallyConnected');
    if (actuallyConnected) {
      _stage = VpnStage.connected;
      _connectedAt = DateTime.now();
      _statusMessage = 'Connected';
      _startStatsMonitoring();
      _startConnectionMonitoring();
    } else {
      _stage = VpnStage.idle;
      _statusMessage = 'Click to connect';
    }
    notifyListeners();
  }

  void _startStatsMonitoring() {
    _statsTimer?.cancel();
    _statsTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      await _updateStats();
    });
    _updateStats();
  }

  void _stopStatsMonitoring() {
    _statsTimer?.cancel();
    _statsTimer = null;
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

    final alive = await WireGuardService.isConnected();
    if (alive) {
      _reconnectAttempts = 0;
      return;
    }

    // Tunnel dropped unexpectedly. Try to auto-recover a few times.
    _reconnectAttempts++;
    VpnLogger.warn(_tag,
        'Connection dropped! Attempt $_reconnectAttempts/$_maxReconnectAttempts');
    if (_reconnectAttempts <= _maxReconnectAttempts) {
      _statusMessage = 'Connection lost, retrying ($_reconnectAttempts/$_maxReconnectAttempts)...';
      notifyListeners();
      await _reconnect();
    } else {
      _reconnectAttempts = 0;
      _stage = VpnStage.error;
      _lastError = 'Connection dropped unexpectedly';
      _statusMessage = 'Disconnected';
      _stopStatsMonitoring();
      _stopConnectionMonitoring();
      notifyListeners();
    }
  }

  Future<void> _reconnect() async {
    VpnLogger.info(_tag, 'Starting auto-reconnect...');
    _stopStatsMonitoring();
    _stopConnectionMonitoring();
    try {
      await WireGuardService.disconnect();
      await WireGuardService.connectWithProgress(
        onProgress: (msg, stage) {
          _stage = stage;
          _statusMessage = msg;
          notifyListeners();
        },
      );
      final ok = await WireGuardService.isConnected();
      if (ok) {
        VpnLogger.info(_tag, 'Auto-reconnect SUCCESS');
        _stage = VpnStage.connected;
        _connectedAt = DateTime.now();
        _statusMessage = 'Connected';
        _startStatsMonitoring();
        _startConnectionMonitoring();
      } else {
        VpnLogger.warn(_tag, 'Auto-reconnect: still no handshake');
      }
    } catch (e) {
      VpnLogger.error(_tag, 'Auto-reconnect failed: $e');
    }
    notifyListeners();
  }

  Future<void> _updateStats() async {
    if (!isConnected) return;

    final tunnelStats = await ErrorHandler.tryCatch(
      () => WireGuardService.getTunnelStats(),
      fallback: {'rx_bytes': 0, 'tx_bytes': 0, 'handshake_age': null},
      context: 'Get Tunnel Stats',
    );

    final rxBytes = (tunnelStats?['rx_bytes'] as int?) ?? 0;
    final txBytes = (tunnelStats?['tx_bytes'] as int?) ?? 0;
    _totalDownload = rxBytes;
    _totalUpload = txBytes;

    final now = DateTime.now();
    final timeDiff = now.difference(_lastStatsUpdate).inSeconds;

    double downloadSpeed = 0.0;
    double uploadSpeed = 0.0;
    if (timeDiff > 0) {
      if (rxBytes > 0 && rxBytes >= _previousRxBytes) {
        downloadSpeed = (rxBytes - _previousRxBytes) / timeDiff / 1024;
      }
      if (txBytes > 0 && txBytes >= _previousTxBytes) {
        uploadSpeed = (txBytes - _previousTxBytes) / timeDiff / 1024;
      }
      _previousRxBytes = rxBytes;
      _previousTxBytes = txBytes;
    }
    _lastStatsUpdate = now;

    // IP + ping.
    final ipInfo = await ErrorHandler.tryCatch(
      () => IPInfoService.getIPInfo(),
      fallback: _stats.ipInfo,
      context: 'Get IP Info',
    );
    final ping = await ErrorHandler.tryCatch(
      () => IPInfoService.measurePing('1.1.1.1'),
      fallback: _stats.ping,
      context: 'Measure Ping',
    );

    _stats = ConnectionStats(
      ping: (ping ?? 0) > 0 ? ping! : 0,
      downloadSpeed: downloadSpeed > 0 ? downloadSpeed : 0.0,
      uploadSpeed: uploadSpeed > 0 ? uploadSpeed : 0.0,
      ipInfo: ipInfo ?? _stats.ipInfo,
      timestamp: now,
    );
    notifyListeners();
  }

  Future<void> connect() async {
    if (isConnecting) return;

    VpnLogger.info(_tag, '=== CONNECT START ===');
    AppLogger.connectionState('Connecting');
    _lastError = null;
    _reconnectAttempts = 0;
    _stage = VpnStage.fetchingConfig;
    _statusMessage = 'Finding fastest server...';
    notifyListeners();

    try {
      await WireGuardService.connectWithProgress(
        onProgress: (msg, stage) {
          _stage = stage;
          AppLogger.info(msg, 'VPN');
          _updateStatus(msg);
        },
      );

      // Tunnel installed successfully — mark as connected
      _stage = VpnStage.connected;
      _connectedAt = DateTime.now();
      _updateStatus('Connected');
      AppLogger.connectionState('Connected');
      _startStatsMonitoring();
      _startConnectionMonitoring();
      VpnLogger.info(_tag, '=== CONNECT SUCCESS ===');
    } catch (e, stackTrace) {
      VpnLogger.error(_tag, '=== CONNECT FAILED: $e ===');
      AppLogger.error('Connection failed', e, stackTrace, 'VPN');
      _stage = VpnStage.error;
      _lastError = ErrorHandler.getUserFriendlyMessage(e);
      _updateStatus('Connection failed');
      _stopStatsMonitoring();
      _stopConnectionMonitoring();
    }
    notifyListeners();
  }

  Future<void> disconnect() async {
    VpnLogger.info(_tag, '=== DISCONNECT START ===');
    AppLogger.connectionState('Disconnecting');
    _stage = VpnStage.disconnecting;
    _updateStatus('Disconnecting...');
    _stopStatsMonitoring();
    _stopConnectionMonitoring();

    try {
      await WireGuardService.disconnect();

      final stillConnected = await WireGuardService.isConnected();
      if (stillConnected) {
        VpnLogger.warn(_tag, 'Tunnel still running after disconnect, force killing...');
        await VpnCore.fullCleanup();
      }

      _stage = VpnStage.idle;
      _connectedAt = null;
      _totalDownload = 0;
      _totalUpload = 0;
      _previousRxBytes = 0;
      _previousTxBytes = 0;
      _stats = ConnectionStats.initial();
      _updateStatus('Disconnected');
      _lastError = null;
      AppLogger.connectionState('Disconnected');
      VpnLogger.info(_tag, '=== DISCONNECT SUCCESS ===');
    } catch (e, stackTrace) {
      VpnLogger.error(_tag, '=== DISCONNECT FAILED: $e ===');
      AppLogger.error('Disconnect failed', e, stackTrace, 'VPN');
      _stage = VpnStage.error;
      _lastError = ErrorHandler.getUserFriendlyMessage(e);
      _updateStatus('Disconnect failed');
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
