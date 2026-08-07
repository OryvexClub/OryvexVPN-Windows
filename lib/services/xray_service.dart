import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'vpn_core.dart';
import 'system_proxy.dart';

/// Service that wraps the Xray core binary for front-facing proxy.
///
/// Xray acts as a proxy layer in front of oryvex's SOCKS5 tunnel:
///   - Inbound: HTTP proxy on 127.0.0.1:10809, SOCKS on 127.0.0.1:10808
///   - Outbound: SOCKS5 to 127.0.0.1:1819 (oryvex)
///   - Routing: bypasses private IPs and localhost
class XrayService {
  static const String _tag = 'XrayService';
  static Process? _xrayProcess;
  static bool _isRunning = false;

  /// Log broadcasting — subscribers get every stdout/stderr line.
  static final StreamController<String> _logController =
      StreamController<String>.broadcast();
  static Stream<String> get logStream => _logController.stream;

  /// Recent log lines (last 500) for showing history when dialog opens.
  static final List<String> _recentLogs = [];
  static List<String> get recentLogs => List.unmodifiable(_recentLogs);
  static const int _maxRecentLogs = 500;

  /// Path to the xray binary in the data directory.
  static String get _xrayExe {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    return '$exeDir\\data\\xray.exe';
  }

  /// Path to the generated config file.
  static String get _configPath {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    return '$exeDir\\data\\xray_config.json';
  }

  /// Check if the xray binary is available.
  static Future<bool> isAvailable() async {
    final exists = await File(_xrayExe).exists();
    VpnLogger.info(_tag, 'xray binary available: $exists at $_xrayExe');
    return exists;
  }

  /// Whether xray is currently running.
  static bool get isRunning => _isRunning;

  /// Kill any running xray process.
  static Future<void> killRunning() async {
    if (_xrayProcess != null) {
      try {
        _xrayProcess!.kill(ProcessSignal.sigterm);
      } catch (_) {}
      _xrayProcess = null;
    }
    _isRunning = false;

    // Also kill by process name as fallback
    try {
      await Process.run('taskkill', ['/F', '/IM', 'xray.exe'], runInShell: true);
    } catch (_) {}
  }

  /// Generate the Xray config JSON that routes traffic through oryvex SOCKS5.
  /// Uses explicit private IP CIDR ranges instead of geoip:private to avoid
  /// needing the geoip.dat file.
  static String _generateConfig() {
    final config = {
      'log': {'loglevel': 'warning'},
      'inbounds': [
        {
          'tag': 'http',
          'port': 10809,
          'listen': '127.0.0.1',
          'protocol': 'http',
        },
        {
          'tag': 'socks',
          'port': 10808,
          'listen': '127.0.0.1',
          'protocol': 'socks',
          'settings': {'auth': 'noauth', 'udp': true},
        },
      ],
      'outbounds': [
        {
          'tag': 'proxy',
          'protocol': 'socks',
          'settings': {
            'servers': [
              {'address': '127.0.0.1', 'port': 1819},
            ],
          },
        },
        {
          'tag': 'direct',
          'protocol': 'freedom',
          'settings': {},
        },
      ],
      'routing': {
        'domainStrategy': 'AsIs',
        'rules': [
          {
            'type': 'field',
            'outboundTag': 'direct',
            'ip': [
              '127.0.0.0/8',
              '10.0.0.0/8',
              '172.16.0.0/12',
              '192.168.0.0/16',
              '169.254.0.0/16',
              '::1/128',
              'fc00::/7',
              'fe80::/10',
            ],
          },
          {
            'type': 'field',
            'outboundTag': 'direct',
            'domain': ['localhost'],
          },
        ],
      },
    };
    return jsonEncode(config);
  }

  /// Add a line to the log buffer and broadcast it.
  static void _addLog(String line) {
    final now = DateTime.now();
    final ts = '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';
    final formatted = '[$ts] XRAY: $line';

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

  /// Start the Xray core process.
  ///
  /// Waits for oryvex SOCKS5 on port 1819 to be active, writes config,
  /// then launches xray.exe.
  static Future<void> start() async {
    VpnLogger.info(_tag, '=== Starting Xray core ===');

    // Kill any existing xray process first
    await killRunning();

    // Wait for oryvex SOCKS5 to be ready on port 1819
    VpnLogger.info(_tag, 'Waiting for oryvex SOCKS5 on port 1819...');
    int waitMs = 0;
    const maxWaitMs = 15000;
    const checkInterval = 500;

    while (waitMs < maxWaitMs) {
      if (await _isPortActive(1819)) {
        VpnLogger.info(_tag, 'oryvex SOCKS5 detected on port 1819');
        break;
      }
      await Future.delayed(const Duration(milliseconds: checkInterval));
      waitMs += checkInterval;
    }

    if (!await _isPortActive(1819)) {
      VpnLogger.warn(_tag, 'oryvex SOCKS5 not ready after ${maxWaitMs}ms, starting anyway');
    }

    // Write config file
    try {
      final config = _generateConfig();
      await File(_configPath).writeAsString(config);
      VpnLogger.info(_tag, 'Config written to $_configPath');
      _addLog('Config written to $_configPath');
    } catch (e) {
      VpnLogger.error(_tag, 'Failed to write config: $e');
      _addLog('ERROR: Failed to write config: $e');
      return;
    }

    // Launch xray.exe
    final args = <String>['run', '-c', _configPath];
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final dataDir = '$exeDir\\data';

    VpnLogger.info(_tag, 'Starting xray: $_xrayExe ${args.join(' ')}');
    _addLog('Starting xray: ${args.join(' ')}');

    try {
      _xrayProcess = await Process.start(
        _xrayExe,
        args,
        workingDirectory: dataDir,
        runInShell: false,
      );
      _isRunning = true;
      _addLog('Xray process started (PID: ${_xrayProcess!.pid})');

      // Monitor stdout
      _xrayProcess!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        VpnLogger.info(_tag, 'XRAY STDOUT: $line');
        _addLog(line);
      });

      // Monitor stderr
      _xrayProcess!.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        VpnLogger.warn(_tag, 'XRAY STDERR: $line');
        _addLog('WARN: $line');
      });

      // Wait briefly to check if xray started successfully
      await Future.delayed(const Duration(seconds: 2));

      if (_isRunning && await _isPortActive(10809)) {
        VpnLogger.info(_tag, 'Xray HTTP proxy ready on 127.0.0.1:10809');
        _addLog('HTTP proxy ready on 127.0.0.1:10809');

        // Set system proxy to route traffic through Xray
        _addLog('Setting system proxy to Xray...');
        await SystemProxyService.setToXray();
        _addLog('System proxy configured for Xray');
      } else if (_isRunning) {
        VpnLogger.warn(_tag, 'Xray started but port 10809 not yet active');
        _addLog('Xray started, waiting for port 10809...');
      }
    } catch (e) {
      VpnLogger.error(_tag, 'Failed to start xray: $e');
      _addLog('ERROR: Failed to start xray: $e');
      _isRunning = false;
    }
  }

  /// Stop the Xray core process.
  static Future<void> stop() async {
    VpnLogger.info(_tag, 'Stopping Xray core...');
    _addLog('Stopping Xray core...');
    await killRunning();
    VpnLogger.info(_tag, 'Xray core stopped');
    _addLog('Xray core stopped');
  }

  /// Check if a port is actively being used.
  static Future<bool> _isPortActive(int port) async {
    try {
      final result = await Process.run(
        'netstat',
        ['-ano'],
        runInShell: true,
      );
      final output = result.stdout.toString();
      return output.contains(':$port ') || output.contains(':$port\t');
    } catch (_) {
      return false;
    }
  }
}
