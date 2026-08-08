import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'vpn_core.dart';
import 'vpn_service.dart';
import 'system_check_service.dart';

/// Protocol types supported by the oryvex core binary.
enum OryvexProtocol {
  auto,        // Try all protocols in order (MASQUE -> WireGuard -> WARP-in-WARP)
  masque,      // Protocol 1 - Modern, QUIC/H3
  wireguard,   // Protocol 2 - Classic, faster
  warpinwarp,  // Protocol 3 - WARP-in-WARP / gool
}

/// Connection result from an oryvex protocol attempt.
class OryvexConnectionResult {
  final bool success;
  final String protocolName;
  final String? errorMessage;
  final int? port;

  const OryvexConnectionResult({
    required this.success,
    required this.protocolName,
    this.errorMessage,
    this.port,
  });
}

/// Service that wraps the oryvex CLI binary for protocol fallback connections.
///
/// The oryvex binary is invoked in fully non-interactive mode via CLI flags:
///   --masque / --wg / --gool   protocol selection (auto-fills protocol prompt)
///   --h2                        use HTTP/2 TCP transport for MASQUE (auto-fills transport prompt)
///   --no-quick-reconnect        always scan fresh, skip reconnect prompt
///   --turbo                     fast scan mode (auto-fills scan mode prompt)
///   -4                          IPv4 only (auto-fills IP version prompt)
///   --noize firewall            obfuscation profile
///   --bind 127.0.0.1:1819       SOCKS5 listen address
///
/// Automatic fallback: MASQUE -> WireGuard -> WARP-in-WARP.
/// If a protocol fails and doesn't show port 1819, it tries the next method.
class OryvexService {
  static const String _tag = 'OryvexService';
  static Process? _oryvexProcess;
  static bool _isRunning = false;

  /// Log broadcasting — subscribers get every stdout/stderr line.
  static final StreamController<String> _logController =
      StreamController<String>.broadcast();
  static Stream<String> get logStream => _logController.stream;

  /// Recent log lines (last 500) for showing history when dialog opens.
  static final List<String> _recentLogs = [];
  static List<String> get recentLogs => List.unmodifiable(_recentLogs);
  static const int _maxRecentLogs = 500;

  /// Protocol priority order for fallback.
  static const List<OryvexProtocol> _protocolPriority = [
    OryvexProtocol.masque,
    OryvexProtocol.wireguard,
    OryvexProtocol.warpinwarp,
  ];

  /// Human-readable protocol names.
  static String _protocolName(OryvexProtocol p) {
    switch (p) {
      case OryvexProtocol.auto:
        return 'Auto';
      case OryvexProtocol.masque:
        return 'MASQUE';
      case OryvexProtocol.wireguard:
        return 'WireGuard';
      case OryvexProtocol.warpinwarp:
        return 'WARP-in-WARP';
    }
  }

  /// CLI flag for each protocol.
  static String? _protocolFlag(OryvexProtocol p) {
    switch (p) {
      case OryvexProtocol.auto:
        return null; // No flag = default protocol (MASQUE)
      case OryvexProtocol.masque:
        return '--masque';
      case OryvexProtocol.wireguard:
        return '--wg';
      case OryvexProtocol.warpinwarp:
        return '--gool';
    }
  }

  /// Path to the oryvex binary in the data directory.
  static String get _oryvexExe {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    return '$exeDir\\data\\oryvex.exe';
  }

  /// Check if the oryvex binary is available.
  static Future<bool> isAvailable() async {
    final exists = await File(_oryvexExe).exists();
    VpnLogger.info(_tag, 'oryvex binary available: $exists at $_oryvexExe');
    return exists;
  }

  /// PID of the oryvex process we started, if any.
  static int? get currentPid => _oryvexProcess?.pid;

  /// True only when port 1819 is bound by *our* oryvex.exe process — never by
  /// a foreign VPN/proxy app. This is the strict ownership check used for
  /// connect state decisions.
  static Future<bool> isPort1819OwnedByOryvex() async {
    final pids = await SystemCheckService.pidsOnPort(1819);
    if (pids.isEmpty) return false;
    final ourPid = _oryvexProcess?.pid;
    if (ourPid != null && pids.contains(ourPid)) {
      VpnLogger.debug(_tag, 'isPort1819OwnedByOryvex: true (tracked PID $ourPid)');
      return true;
    }
    for (final pid in pids) {
      if (await SystemCheckService.processNameForPid(pid) == 'oryvex.exe') {
        VpnLogger.debug(_tag, 'isPort1819OwnedByOryvex: true (PID $pid is oryvex.exe)');
        return true;
      }
    }
    VpnLogger.debug(_tag, 'isPort1819OwnedByOryvex: false (no oryvex.exe on :1819)');
    return false;
  }

  /// Add a line to the log buffer and broadcast it.
  static void _addLog(String line) {
    final now = DateTime.now();
    final ts = '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';
    final formatted = '[$ts] ORYVEX: $line';

    _recentLogs.add(formatted);
    if (_recentLogs.length > _maxRecentLogs) {
      _recentLogs.removeAt(0);
    }

    if (!_logController.isClosed) {
      _logController.add(formatted);
    }
  }

  /// Clear the log buffer.
  static void clearLogs() {
    _recentLogs.clear();
  }

  /// Kill any running oryvex process.
  static Future<void> killRunning() async {
    if (_oryvexProcess != null) {
      try {
        _oryvexProcess!.kill(ProcessSignal.sigterm);
      } catch (_) {}
      _oryvexProcess = null;
    }
    _isRunning = false;

    // Also kill by process name as fallback
    try {
      await Process.run('taskkill', ['/F', '/IM', 'oryvex.exe'], runInShell: true);
    } catch (_) {}
  }

  /// Try connecting with a specific protocol using non-interactive CLI flags.
  /// Returns true if the connection succeeded and shows port 1819.
  static Future<OryvexConnectionResult> _tryProtocol(
    OryvexProtocol protocol,
    void Function(String msg, VpnStage stage) onProgress,
  ) async {
    final name = _protocolName(protocol);
    final flag = _protocolFlag(protocol);

    VpnLogger.info(_tag, '=== Trying protocol: $name ===');
    onProgress('Connecting via $name...', VpnStage.fetchingConfig);

    try {
      // Kill any existing oryvex process first
      await killRunning();

      // Build non-interactive CLI arguments.
      // All interactive prompts are auto-filled via CLI flags:
      //   --masque/--wg/--gool  — protocol selection (skips protocol prompt)
      //   --h2                  — use HTTP/2 TCP transport for MASQUE (skips transport prompt)
      //   --no-quick-reconnect  — always scan fresh, ignore saved last-connection gateway
      //   --turbo               — fast scan mode (skips scan mode prompt)
      //   -4                    — IPv4 only (skips IP version prompt)
      //   --noize firewall      — obfuscation profile for MASQUE
      //   --bind 127.0.0.1:1819 — explicit SOCKS5 listen address
      final args = <String>[
        if (flag != null) flag,
        '--h2',               // MASQUE over HTTP/2 TCP (looks like HTTPS, better for DPI bypass)
        '--no-quick-reconnect', // Always scan fresh, skip reconnect prompt
        '--turbo',            // Fast scan mode (skip scan mode selection)
        '-4',                 // IPv4 only (skip IP version selection)
        '--noize', 'firewall', // Obfuscation profile
        '--bind', '127.0.0.1:1819', // SOCKS5 listen address
      ];

      final exeDir = File(Platform.resolvedExecutable).parent.path;
      final dataDir = '$exeDir\\data';

      VpnLogger.info(_tag, 'Starting oryvex: $_oryvexExe ${args.join(' ')}');
      VpnLogger.info(_tag, 'Working directory: $dataDir');

      _oryvexProcess = await Process.start(
        _oryvexExe,
        args,
        workingDirectory: dataDir,
        runInShell: false,
      );
      _isRunning = true;

      // Monitor stdout for connection status and port 1819
      bool connected = false;
      bool portDetected = false;
      int detectedPort = 0;

      final stdoutSubscription = _oryvexProcess!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        VpnLogger.info(_tag, 'ORYVEX STDOUT: $line');
        _addLog(line);

        // The oryvex binary logs "[+] socks5 server listening on <addr>"
        // when the tunnel is fully established and the proxy is ready.
        if (line.contains('socks5 server listening') ||
            line.contains('socks5 server on')) {
          connected = true;
          VpnLogger.info(_tag, 'Protocol $name: SOCKS5 server detected!');
        }

        // Also detect port 1819 in any output line
        if (line.contains(':1819') || line.contains(' 1819 ')) {
          portDetected = true;
          detectedPort = 1819;
          connected = true;
        }

        // Detect explicit connected/tunnel messages
        if (line.contains('[+]') &&
            (line.contains('tunnel') || line.contains('wireguard') || line.contains('masque'))) {
          VpnLogger.info(_tag, 'Protocol $name: tunnel activity detected');
        }

        // Check for failure indicators
        if (line.contains('failed') ||
            line.contains('error') ||
            line.contains('Error') ||
            line.contains('no clean endpoint') ||
            line.contains('no usable')) {
          VpnLogger.warn(_tag, 'Protocol $name failure indicator: $line');
        }

        // Detect process exit indicators
        if (line.contains('[-]') && line.contains('tunnel ended')) {
          VpnLogger.warn(_tag, 'Protocol $name: tunnel ended');
        }
      });

      final stderrSubscription = _oryvexProcess!.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        VpnLogger.warn(_tag, 'ORYVEX STDERR: $line');
        _addLog('WARN: $line');
      });

      // Wait for connection attempt with timeout.
      // The oryvex binary does: identity provision -> scan -> handshake -> data validation -> socks5.
      // This can take up to 30 seconds on slow networks.
      onProgress('Establishing $name tunnel...', VpnStage.installingTunnel);

      int waitMs = 0;
      const maxWaitMs = 30000; // 30 seconds — generous for scan + validation
      const checkInterval = 500;

      while (waitMs < maxWaitMs && !connected) {
        await Future.delayed(const Duration(milliseconds: checkInterval));
        waitMs += checkInterval;

        // Progress updates during the wait
        if (waitMs == 5000) {
          onProgress('Scanning for $name gateway...', VpnStage.installingTunnel);
        } else if (waitMs == 15000) {
          onProgress('Validating $name tunnel...', VpnStage.installingTunnel);
        }
      }

      // After waiting, check if port 1819 is active as secondary verification
      if (!connected && _isRunning) {
        portDetected = await isPort1819Active();
        if (portDetected) {
          connected = true;
          detectedPort = 1819;
        }
      }

      // Cleanup subscriptions
      await stdoutSubscription.cancel();
      await stderrSubscription.cancel();

      if (connected) {
        VpnLogger.info(_tag, 'Protocol $name: CONNECTED (port ${detectedPort == 0 ? 1819 : detectedPort})');
        return OryvexConnectionResult(
          success: true,
          protocolName: name,
          port: detectedPort,
        );
      } else {
        // Kill the process if it's still running but didn't connect
        await killRunning();
        VpnLogger.warn(_tag, 'Protocol $name: FAILED (no connection within timeout)');
        return OryvexConnectionResult(
          success: false,
          protocolName: name,
          errorMessage: 'Connection timed out',
        );
      }
    } catch (e) {
      VpnLogger.error(_tag, 'Protocol $name: EXCEPTION: $e');
      await killRunning();
      return OryvexConnectionResult(
        success: false,
        protocolName: name,
        errorMessage: e.toString(),
      );
    }
  }

  /// Check if port 1819 is actively being used.
  static Future<bool> isPort1819Active() async {
    try {
      final result = await Process.run(
        'netstat',
        ['-ano'],
        runInShell: true,
      );
      final output = result.stdout.toString();
      // Check if port 1819 appears in active connections
      if (output.contains(':1819') || output.contains(' 1819 ')) {
        VpnLogger.info(_tag, 'Port 1819 detected as active');
        return true;
      }
    } catch (e) {
      VpnLogger.debug(_tag, 'Port check failed: $e');
    }
    return false;
  }

  /// Connect with protocol selection.
  /// If protocol is AUTO, tries MASQUE -> WireGuard -> WARP-in-WARP.
  /// If a specific protocol is selected, only tries that one.
  /// Returns the first successful protocol, or throws if all fail.
  static Future<OryvexConnectionResult> connectWithFallback({
    required void Function(String msg, VpnStage stage) onProgress,
    OryvexProtocol protocol = OryvexProtocol.auto,
  }) async {
    VpnLogger.info(_tag, '=== Starting connection with protocol: ${_protocolName(protocol)} ===');

    // Check if oryvex binary is available
    if (!await isAvailable()) {
      throw Exception(
        'oryvex binary not found at $_oryvexExe. Please reinstall the app.',
      );
    }

    // If a specific protocol is selected, only try that one
    if (protocol != OryvexProtocol.auto) {
      final name = _protocolName(protocol);
      onProgress('Connecting via $name...', VpnStage.fetchingConfig);
      final result = await _tryProtocol(protocol, onProgress);
      if (result.success) {
        VpnLogger.info(_tag, '=== Connection SUCCESS: ${result.protocolName} ===');
        return result;
      }
      VpnLogger.error(_tag, '=== $name failed: ${result.errorMessage} ===');
      throw Exception('$name connection failed: ${result.errorMessage}');
    }

    // Auto mode: try each protocol in priority order
    for (int i = 0; i < _protocolPriority.length; i++) {
      final p = _protocolPriority[i];
      final name = _protocolName(p);

      onProgress('Trying $name (method ${i + 1}/${_protocolPriority.length})...',
          VpnStage.fetchingConfig);

      final result = await _tryProtocol(p, onProgress);

      if (result.success) {
        VpnLogger.info(_tag, '=== Fallback SUCCESS: ${result.protocolName} ===');
        return result;
      }

      VpnLogger.warn(_tag, 'Protocol ${result.protocolName} failed, trying next...');

      // Brief pause before next attempt
      await Future.delayed(const Duration(milliseconds: 500));
    }

    // All protocols failed
    VpnLogger.error(_tag, '=== All protocols failed ===');
    throw Exception(
      'All connection methods failed. Please check your internet connection and try again.',
    );
  }

  /// Disconnect - kill oryvex process and cleanup.
  static Future<void> disconnect() async {
    VpnLogger.info(_tag, 'Disconnecting oryvex...');
    await killRunning();
    VpnLogger.info(_tag, 'Disconnect complete');
  }
}
