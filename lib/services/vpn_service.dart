import 'package:flutter/material.dart';
import '../main.dart';
import 'system_check_service.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'wireguard_service.dart';
import 'oryvex_service.dart';
import 'vpn_core.dart';
import 'ipinfo_service.dart';
import '../utils/error_handler.dart';
import 'system_proxy.dart';

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
  Timer? _systemCheckTimer;

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

  String _antiDpiPreset = 'standard';
  String get antiDpiPreset => _antiDpiPreset;

  void setAntiDpiPreset(String preset) {
    _antiDpiPreset = preset;
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('anti_dpi_preset', preset);
    });
    notifyListeners();
  }

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

  VPNService() {
    _loadFullTunnelSetting();
    _startSystemMonitoring();
  }

  Future<void> _loadFullTunnelSetting() async {
    final prefs = await SharedPreferences.getInstance();
    _antiDpiPreset = prefs.getString('anti_dpi_preset') ?? 'standard';
    notifyListeners();
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
    _statsTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      await _updateStats();
    });
    _updateStats();
  }

  void _stopStatsMonitoring() {
    _statsTimer?.cancel();
    _statsTimer = null;
  }


  bool _isModalShowing = false;

  void _startSystemMonitoring() {
    _systemCheckTimer?.cancel();
    _systemCheckTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      bool clockSynced = await SystemCheckService.isClockSynced();
      List<String> procs = await SystemCheckService.getConflictingProcesses();

      if (!clockSynced || procs.isNotEmpty) {
        if (isConnected || isConnecting) {
          _stage = VpnStage.error;
          _lastError = 'Disconnected: clock out of sync or conflicting programs';
          _statusMessage = 'Disconnected';
          _stopStatsMonitoring();
          _stopConnectionMonitoring();
          await WireGuardService.disconnect();
          notifyListeners();
        }

        if (!_isModalShowing && navigatorKey.currentContext != null) {
          _isModalShowing = true;

          showDialog(
            context: navigatorKey.currentContext!,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              backgroundColor: const Color(0xFF111111),
              title: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange[400]),
                  const SizedBox(width: 10),
                  Text(
                    !clockSynced ? 'System Clock Error' : 'Conflicting Programs',
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ],
              ),
              content: Text(
                !clockSynced
                    ? 'Your system clock is out of sync. This will prevent the VPN from connecting properly.\n\nPlease sync your Windows clock to continue.'
                    : 'The following programs might conflict with the VPN:\n\n${procs.join(', ')}\n\nPlease close them to prevent connection issues.',
                style: const TextStyle(color: Colors.white70),
              ),
              actions: [
                if (procs.isNotEmpty && clockSynced)
                  TextButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      _isModalShowing = false;
                      for (final p in procs) {
                        try {
                          await Process.run('taskkill', ['/F', '/IM', p], runInShell: true);
                        } catch (_) {}
                      }
                    },
                    child: const Text('Kill All', style: TextStyle(color: Colors.redAccent)),
                  ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _isModalShowing = false;
                  },
                  child: const Text('Dismiss', style: TextStyle(color: Colors.white54)),
                ),
              ],
            ),
          ).then((_) {
            _isModalShowing = false;
          });
        }
      }
    });
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

    if (!alive) {
      // Service is dead — only then consider it dropped
      VpnLogger.warn(_tag, 'Tunnel service is not running');
    } else {
      // Service is running. Check handshake health but don't kill connection
      // just because handshake is slow. Only log warnings.
      try {
        final stats = await WireGuardService.getTunnelStats();
        final handshakeAge = stats['handshake_age'] as int?;
        final rx = stats['rx_bytes'] as int? ?? 0;
        VpnLogger.debug(_tag, 'Health check: handshake_age=$handshakeAge, rx=$rx');
      } catch (e) {
        VpnLogger.debug(_tag, 'Health check stats read failed: $e');
      }
      _reconnectAttempts = 0;
      return;
    }

    // Tunnel dropped unexpectedly. Try to auto-recover a few times.
    // Ensure we are waiting at least 25 seconds since connected before testing dropping connection
    if (_connectedAt != null && DateTime.now().difference(_connectedAt!).inSeconds < 25) {
      return; // Give it some time to establish and report status properly
    }

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
      // Disconnect oryvex if it's running
      await OryvexService.disconnect();
      await WireGuardService.disconnect();

      // Try oryvex with protocol fallback first
      if (await OryvexService.isAvailable()) {
        VpnLogger.info(_tag, 'Reconnecting via oryvex protocol fallback');
        await OryvexService.connectWithFallback(
          onProgress: (msg, stage) {
            _stage = stage;
            _statusMessage = msg;
            notifyListeners();
          },
        );
      } else {
        // Fallback to AmneziaWG WireGuard
        await WireGuardService.connectWithProgress(
          isFullTunnel: true,
          antiDpiPreset: _antiDpiPreset,
          onProgress: (msg, stage) {
            _stage = stage;
            _statusMessage = msg;
            notifyListeners();
          },
        );
      }

      final ok = await WireGuardService.isConnected() || await OryvexService.isPort1819Active();
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

  // Counter to avoid fetching IP every cycle
  int _statsCycleCount = 0;

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

    // Fetch IP info only every 10 cycles (~30 seconds) to avoid rate limiting
    _statsCycleCount++;
    IPInfoModel ipInfo = _stats.ipInfo;
    if (_statsCycleCount >= 10 || _stats.ipInfo.ip == 'N/A') {
      _statsCycleCount = 0;
      ipInfo = await ErrorHandler.tryCatch(
        () => IPInfoService.getIPInfo(),
        fallback: _stats.ipInfo,
        context: 'Get IP Info',
      ) ?? _stats.ipInfo;
    }

    // Ping always updates
    final ping = await ErrorHandler.tryCatch(
      () => IPInfoService.measurePing('1.1.1.1'),
      fallback: _stats.ping,
      context: 'Measure Ping',
    );

    _stats = ConnectionStats(
      ping: (ping ?? 0) > 0 ? ping! : 0,
      downloadSpeed: downloadSpeed > 0 ? downloadSpeed : 0.0,
      uploadSpeed: uploadSpeed > 0 ? uploadSpeed : 0.0,
      ipInfo: ipInfo,
      timestamp: now,
    );
    notifyListeners();
  }

  Future<void> _attemptConnectionRound() async {
    // Try oryvex binary with protocol fallback first (MASQUE -> WireGuard -> WARP-in-WARP)
    if (await OryvexService.isAvailable()) {
      VpnLogger.info(_tag, 'Using oryvex binary with protocol fallback');
      await OryvexService.connectWithFallback(
        onProgress: (msg, stage) {
          _stage = stage;
          AppLogger.info(msg, 'VPN');
          _updateStatus(msg);
        },
      );

      // Wait for tunnel to fully establish
      VpnLogger.info(_tag, 'Waiting for tunnel to establish...');
      await Future.delayed(const Duration(seconds: 3));

      // Verify connection
      final running = await WireGuardService.isConnected() || await OryvexService.isPort1819Active();
      VpnLogger.info(_tag, 'Tunnel service running (oryvex): $running');

      if (!running) {
        throw const FormatException('Tunnel failed to start. Please try again.');
      }

      VpnLogger.info(_tag, 'Connection established via oryvex protocol fallback');
      return;
    }

    // Fallback to AmneziaWG WireGuard if oryvex is not available
    VpnLogger.info(_tag, 'oryvex not available, falling back to AmneziaWG WireGuard');

    // Always use full tunnel for WireGuard routing.
    // When in proxy mode, local proxies handle selective routing.
    await WireGuardService.connectWithProgress(
      isFullTunnel: true,
      antiDpiPreset: _antiDpiPreset,
      onProgress: (msg, stage) {
        _stage = stage;
        AppLogger.info(msg, 'VPN');
        _updateStatus(msg);
      },
    );

    // Wait for tunnel to fully establish
    VpnLogger.info(_tag, 'Waiting for tunnel to establish...');
    await Future.delayed(const Duration(seconds: 3));

    // Verify tunnel service is actually running
    final running = await WireGuardService.isConnected();
    VpnLogger.info(_tag, 'Tunnel service running: $running');

    if (!running) {
      VpnLogger.error(_tag, 'Tunnel service not running after install');
      throw const FormatException('Tunnel failed to start. Please try again.');
    }

    // Verify handshake occurred (tunnel is actually communicating)
    bool hasHandshake = false;
    try {
      final stats = await WireGuardService.getTunnelStats();
      final handshakeAge = stats['handshake_age'] as int?;
      final rx = stats['rx_bytes'] as int? ?? 0;
      final tx = stats['tx_bytes'] as int? ?? 0;
      VpnLogger.info(_tag, 'Tunnel stats: handshake_age=$handshakeAge, rx=$rx, tx=$tx');
      hasHandshake = handshakeAge != null || rx > 0 || tx > 0;
    } catch (e) {
      VpnLogger.warn(_tag, 'Could not read tunnel stats: $e');
    }

    if (!hasHandshake) {
      VpnLogger.warn(_tag, 'No handshake yet, waiting longer...');
      await Future.delayed(const Duration(seconds: 5));
      try {
        final stats = await WireGuardService.getTunnelStats();
        final handshakeAge = stats['handshake_age'] as int?;
        final rx = stats['rx_bytes'] as int? ?? 0;
        hasHandshake = handshakeAge != null || rx > 0;
        VpnLogger.info(_tag, 'Retry stats: handshake_age=$handshakeAge, rx=$rx');
      } catch (e) {
        VpnLogger.warn(_tag, 'Retry stats failed: $e');
      }
    }

    // Even without handshake yet, if service is running, consider it connected.
    // The handshake may take a moment but traffic will start flowing.
    VpnLogger.info(_tag, 'Connection established (service running=$running, handshake=$hasHandshake)');
  }

  Future<void> connect() async {
    if (isConnecting) return;

    VpnLogger.info(_tag, '=== CONNECT START ===');

    try {
      if (isConnected || _stage == VpnStage.error) {
         VpnLogger.info(_tag, 'Cleaning up previous connection state...');
         await WireGuardService.disconnect();
         await VpnCore.fullCleanup();
      }
    } catch (e) {
      VpnLogger.warn(_tag, 'Pre-connect cleanup error: $e');
    }

    AppLogger.connectionState('Connecting');
    _lastError = null;
    _reconnectAttempts = 0;

    // Save the current system proxy and disable it so the tunneled traffic
    // isn't forced through a stale local proxy (which causes
    // ERR_PROXY_CONNECTION_FAILED in browsers).
    await SystemProxyService.saveState();
    await SystemProxyService.disable();

    _stage = VpnStage.fetchingConfig;
    _statusMessage = 'Finding fastest server...';
    notifyListeners();

    int attempts = 0;
    bool connected = false;

    while (attempts < 3 && !connected) {
      attempts++;
      try {
        await _attemptConnectionRound();
        connected = true;
      } catch (e, stackTrace) {
        if (e is FormatException && attempts < 3) {
           VpnLogger.warn(_tag, 'Connection round $attempts failed verification, retrying...');
           _updateStatus('Retrying connection ($attempts/3)...');
           await WireGuardService.disconnect();
           await VpnCore.fullCleanup();
        } else {
          VpnLogger.error(_tag, '=== CONNECT FAILED: $e ===');
          AppLogger.error('Connection failed', e, stackTrace, 'VPN');
          _stage = VpnStage.error;
          _lastError = ErrorHandler.getUserFriendlyMessage(e);
          _updateStatus('Connection failed');
          _stopStatsMonitoring();
          _stopConnectionMonitoring();
          await SystemProxyService.restore();
          notifyListeners();
          return;
        }
      }
    }

    if (connected) {
      _stage = VpnStage.connected;
      _connectedAt = DateTime.now();
      _updateStatus('Connected');
      AppLogger.connectionState('Connected');
      _startStatsMonitoring();
      _startConnectionMonitoring();

      // Flush DNS so the tunnel's DNS servers take effect immediately
      VpnCore.flushDns().catchError((_) {});

      VpnLogger.info(_tag, '=== CONNECT SUCCESS ===');
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    VpnLogger.info(_tag, '=== DISCONNECT START ===');
    AppLogger.connectionState('Disconnecting');
    _stage = VpnStage.disconnecting;
    _updateStatus('Disconnecting...');
    _stopStatsMonitoring();
    _stopConnectionMonitoring();

    try {
      // Disconnect oryvex if it's running
      await OryvexService.disconnect();

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
      // Restore the system proxy that was disabled during connection.
      await SystemProxyService.restore();
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
    _systemCheckTimer?.cancel();
    _stopStatsMonitoring();
    _stopConnectionMonitoring();
    super.dispose();
  }
}