import 'dart:io';

/// Centralized debug logger for VPN core operations.
/// All output goes to print() so it shows in the Flutter console.
class VpnLogger {
  static bool enabled = true;

  static void _log(String level, String tag, String msg) {
    if (!enabled) return;
    final ts = DateTime.now().toIso8601String().substring(11, 23);
    print('[$ts][$level][$tag] $msg');
  }

  static void info(String tag, String msg) => _log('INFO', tag, msg);
  static void warn(String tag, String msg) => _log('WARN', tag, msg);
  static void error(String tag, String msg) => _log('ERROR', tag, msg);
  static void debug(String tag, String msg) => _log('DEBUG', tag, msg);
}

class VpnCore {
  VpnCore._();

  static String get _exeDir => File(Platform.resolvedExecutable).parent.path;
  static String get _dataDir => '$_exeDir\\data';
  static String get amneziaWgExe => '$_dataDir\\amneziawg.exe';
  static String get awgExe => '$_dataDir\\awg.exe';
  static String get wintunDll => '$_dataDir\\wintun.dll';

  static const String tunnelName = 'oryvexvpn';
  static const String serviceName = 'WireGuardTunnel\$$tunnelName';
  static const String _tag = 'VpnCore';

  /// Check if AmneziaWG core is available.
  static Future<bool> coreAvailable() async {
    final exists = await File(amneziaWgExe).exists();
    VpnLogger.info(_tag, 'coreAvailable: amneziawg.exe exists=$exists');
    return exists;
  }

  /// Path to the AmneziaWG core executable.
  static Future<String> coreExe() async => amneziaWgExe;

  /// True when the required pieces are present: AmneziaWG exe + wintun driver.
  static Future<bool> coreFilesPresent() async {
    final exeExists = await File(amneziaWgExe).exists();
    final dllExists = await File(wintunDll).exists();
    VpnLogger.info(_tag,
        'coreFilesPresent: amneziawg.exe=$exeExists, wintun.dll=$dllExists');
    return exeExists && dllExists;
  }

  /// The list of what's missing, for a clear Persian error message.
  static Future<List<String>> missingFiles() async {
    final missing = <String>[];
    if (!await File(wintunDll).exists()) missing.add('wintun.dll');
    if (!await File(amneziaWgExe).exists()) {
      missing.add('amneziawg.exe');
    }
    if (!await File(awgExe).exists()) {
      missing.add('awg.exe (stats tool)');
    }
    VpnLogger.warn(_tag, 'missingFiles: $missing');
    return missing;
  }

  // ---- Tunnel service lifecycle -----------------------------------------

  static Future<bool> serviceExists() async {
    final result = await Process.run('sc', ['query', serviceName],
        runInShell: true);
    final exists = result.exitCode == 0;
    VpnLogger.debug(_tag, 'serviceExists($serviceName): $exists');
    return exists;
  }

  static Future<bool> serviceRunning() async {
    try {
      final result = await Process.run('sc', ['query', serviceName]);
      final output = result.stdout.toString();
      final running = output.contains('RUNNING');
      VpnLogger.debug(_tag, 'serviceRunning: $running');
      if (!running && result.exitCode == 0) {
        // Service exists but not running - show state
        final stateMatch = RegExp(r'STATE\s*:\s*(\d+)\s+(\w+)').firstMatch(output);
        if (stateMatch != null) {
          VpnLogger.warn(_tag, 'Service state: ${stateMatch.group(2)}');
        }
      }

      return running;
    } catch (e) {
      VpnLogger.error(_tag, 'serviceRunning exception: $e');
      return false;
    }
  }

  /// True when the network interface (adapter) with [tunnelName] exists,
  /// e.g. a leftover interface left behind by a crash. The interface alone is
  /// NOT proof the tunnel is up — that is [serviceRunning]'s job.
  static Future<bool> interfaceExists() async {
    if (!Platform.isWindows) return false;
    try {
      final r = await Process.run(
        'netsh',
        ['interface', 'show', 'interface', 'name=$tunnelName'],
      );
      final exists = r.exitCode == 0;
      VpnLogger.debug(_tag, 'interfaceExists($tunnelName): $exists');
      return exists;
    } catch (e) {
      VpnLogger.debug(_tag, 'interfaceExists error: $e');
      return false;
    }
  }

  /// Returns detailed service status for debugging.
  static Future<String> serviceStatus() async {
    try {
      final result = await Process.run('sc', ['query', serviceName]);
      return result.stdout.toString();
    } catch (e) {
      return 'Error querying service: $e';
    }
  }

  static Future<void> installTunnel(String confPath) async {
    VpnLogger.info(_tag, '=== installTunnel START ===');
    VpnLogger.info(_tag, 'Config path: $confPath');

    // Verify config file exists and log its content
    final confFile = File(confPath);
    if (!await confFile.exists()) {
      VpnLogger.error(_tag, 'Config file does NOT exist: $confPath');
      throw Exception('Config file not found: $confPath');
    }
    final confContent = await confFile.readAsString();
    VpnLogger.info(_tag, 'Config content:\n$confContent');

    final exe = await coreExe();
    VpnLogger.info(_tag, 'Executable: $exe');

    final result = await Process.run(
        exe, ['/installtunnelservice', confPath]);
    VpnLogger.info(_tag, 'Exit code: ${result.exitCode}');
    VpnLogger.info(_tag, 'STDOUT: ${result.stdout}');
    VpnLogger.info(_tag, 'STDERR: ${result.stderr}');

    if (result.exitCode != 0) {
      final errMsg = 'installTunnel FAILED (exit=${result.exitCode}): ${result.stderr}';
      VpnLogger.error(_tag, errMsg);
      throw Exception(errMsg);
    }

    VpnLogger.info(_tag, 'Tunnel service installed, waiting for startup...');
    await Future.delayed(const Duration(milliseconds: 2000));

    // Verify service actually started
    final running = await serviceRunning();
    VpnLogger.info(_tag, 'Service running after install: $running');
    if (!running) {
      VpnLogger.warn(_tag, 'Service not running after install, checking status...');
      final status = await serviceStatus();
      VpnLogger.warn(_tag, 'Service status:\n$status');
    }

    VpnLogger.info(_tag, '=== installTunnel END ===');
  }

  static Future<void> uninstallTunnel({bool force = false}) async {
    VpnLogger.info(_tag, '=== uninstallTunnel START (force=$force) ===');
    if (!force && !await serviceExists()) {
      VpnLogger.info(_tag, 'Service does not exist, skipping uninstall');
      return;
    }

    // Step 1: Stop the service
    VpnLogger.info(_tag, 'Stopping service...');
    try {
      final stopResult = await Process.run('sc', ['stop', serviceName])
          .timeout(const Duration(seconds: 5));
      VpnLogger.info(_tag, 'Stop result: exit=${stopResult.exitCode}, stdout=${stopResult.stdout}');
    } catch (e) {
      VpnLogger.warn(_tag, 'Stop service failed: $e');
    }
    await Future.delayed(const Duration(milliseconds: 500));

    // Step 2: Force-kill any remaining processes
    VpnLogger.info(_tag, 'Killing remaining processes...');
    await _killProcesses();

    // Step 3: Uninstall the service
    VpnLogger.info(_tag, 'Uninstalling tunnel service...');
    final exe = await coreExe();
    try {
      final result = await Process.run(exe, ['/uninstalltunnelservice', tunnelName])
          .timeout(const Duration(seconds: 5));
      VpnLogger.info(_tag, 'Uninstall result: exit=${result.exitCode}, stderr=${result.stderr}');
      if (result.exitCode != 0) {
        VpnLogger.warn(_tag, 'Uninstall returned non-zero exit code (may be OK)');
      }
    } catch (e) {
      VpnLogger.warn(_tag, 'Uninstall failed: $e');
    }
    await Future.delayed(const Duration(milliseconds: 500));

    // Step 4: Verify service is gone
    final stillExists = await serviceExists();
    VpnLogger.info(_tag, 'Service still exists after uninstall: $stillExists');

    VpnLogger.info(_tag, '=== uninstallTunnel END ===');
  }

  /// Force-kill all AmneziaWG / WireGuard processes.
  static Future<void> _killProcesses() async {
    final procs = ['amneziawg.exe', 'awg.exe', 'wireservice.exe'];
    for (final proc in procs) {
      try {
        final r = await Process.run('taskkill', ['/F', '/IM', proc], runInShell: true);
        if (r.exitCode == 0) {
          VpnLogger.info(_tag, 'Killed $proc');
        }
      } catch (_) {}
    }
  }

  /// Full cleanup: stop service, kill processes, flush DNS.
  static Future<void> fullCleanup() async {
    VpnLogger.info(_tag, '=== fullCleanup START ===');
    await uninstallTunnel();
    await _killProcesses();
    await flushDns();
    VpnLogger.info(_tag, '=== fullCleanup END ===');
  }

  /// Deletes the [tunnelName] network adapter if it lingers after the tunnel
  /// service is gone (e.g. after a crash). Must run AFTER the service is
  /// removed, otherwise the auto-driven service would recreate the adapter.
  static Future<void> _removeAdapterIfPresent() async {
    if (!await interfaceExists()) {
      VpnLogger.info(_tag, 'No $tunnelName interface present; adapter delete skipped');
      return;
    }
    VpnLogger.info(_tag, 'Deleting leftover $tunnelName network adapter...');
    try {
      // If the interface is still "Connected" the delete can fail — disable first.
      await Process.run('netsh', [
        'interface', 'set', 'interface', 'name=$tunnelName', 'admin=disable',
      ]).timeout(const Duration(seconds: 3));
      final r = await Process.run('netsh', [
        'interface', 'delete', 'interface', 'name=$tunnelName',
      ]).timeout(const Duration(seconds: 5));
      VpnLogger.info(_tag, 'Adapter delete: exit=${r.exitCode} ${r.stderr}');
    } catch (e) {
      VpnLogger.warn(_tag, 'Failed to delete adapter: $e');
    }
  }

  /// Comprehensive cleanup that ALWAYS runs, even when not currently
  /// connected (catches leftovers from a crashed session):
  ///   1. stop + uninstall the tunnel service (forced)
  ///   2. delete any leftover adapter
  ///   3. kill our processes
  ///   4. flush DNS
  static Future<void> comprehensiveCleanup() async {
    VpnLogger.info(_tag, '=== comprehensiveCleanup START ===');
    await uninstallTunnel(force: true);
    await _removeAdapterIfPresent();
    await _killProcesses();
    await flushDns();
    VpnLogger.info(_tag, '=== comprehensiveCleanup END ===');
  }

  /// Best-effort DNS flush after the tunnel is up so the new resolvers take
  /// effect immediately.
  static Future<void> flushDns() async {
    try {
      VpnLogger.info(_tag, 'Flushing DNS...');
      final result = await Process.run('ipconfig', ['/flushdns']).timeout(
        const Duration(seconds: 3),
      );
      VpnLogger.info(_tag, 'DNS flush result: ${result.stdout}');
    } catch (e) {
      VpnLogger.warn(_tag, 'DNS flush failed: $e');
    }
  }

  // ---- Statistics --------------------------------------------------------

  /// Returns `{ 'rx': int, 'tx': int }` from `awg show <name> transfer`.
  /// Uses AmneziaWG's awg.exe stats tool.
  static Future<Map<String, int>> readTransfer() async {
    final reader = _statsReaderPath();
    if (reader == null) {
      VpnLogger.debug(_tag, 'readTransfer: no stats reader available');
      return {'rx': 0, 'tx': 0};
    }
    try {
      final result = await Process.run(reader, ['show', tunnelName, 'transfer']);
      if (result.exitCode == 0) {
        final parsed = _parseTransfer(result.stdout.toString());
        VpnLogger.debug(_tag, 'readTransfer: rx=${parsed['rx']}, tx=${parsed['tx']}');
        return parsed;
      } else {
        VpnLogger.debug(_tag, 'readTransfer: exit=${result.exitCode}, stderr=${result.stderr}');
      }
    } catch (e) {
      VpnLogger.debug(_tag, 'readTransfer exception: $e');
    }
    return {'rx': 0, 'tx': 0};
  }

  /// Returns the age in seconds since the latest handshake, or `null` if there
  /// has never been a handshake (tunnel not actually live).
  static Future<int?> readHandshakeAge() async {
    final reader = _statsReaderPath();
    if (reader == null) {
      VpnLogger.debug(_tag, 'readHandshakeAge: no reader available');
      return null;
    }
    try {
      final result = await Process.run(
          reader, ['show', tunnelName, 'latest-handshakes']);
      if (result.exitCode != 0) {
        VpnLogger.debug(_tag,
            'readHandshakeAge: exit=${result.exitCode}, stderr=${result.stderr}');
        return null;
      }
      final raw = result.stdout.toString().trim();
      VpnLogger.debug(_tag, 'readHandshakeAge raw: "$raw"');
      // Expected: "<peer>\t<unix-seconds>" (0 if never handshaken).
      final parts = raw.split(RegExp(r'\s+'));
      if (parts.isEmpty) return null;
      final ts = int.tryParse(parts.last);
      if (ts == null || ts <= 0) {
        VpnLogger.debug(_tag, 'readHandshakeAge: no valid timestamp (ts=$ts)');
        return null;
      }
      final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      final age = now - ts;
      VpnLogger.debug(_tag, 'readHandshakeAge: age=${age}s (ts=$ts, now=$now)');
      return age < 0 ? 0 : age;
    } catch (e) {
      VpnLogger.debug(_tag, 'readHandshakeAge exception: $e');
      return null;
    }
  }

  /// Read the "show" output for full diagnostic info.
  static Future<String> readShow() async {
    final reader = _statsReaderPath();
    if (reader == null) return 'No reader available';
    try {
      final result = await Process.run(reader, ['show', tunnelName]);
      return result.stdout.toString();
    } catch (e) {
      return 'Error: $e';
    }
  }

  /// Stats reader: awg.exe (AmneziaWG stats tool).
  static String? _statsReaderPath() {
    if (Platform.isWindows && File(awgExe).existsSync()) return awgExe;
    // Fallback to main executable if awg.exe not available
    if (Platform.isWindows && File(amneziaWgExe).existsSync()) return amneziaWgExe;
    return null;
  }

  static Map<String, int> _parseTransfer(String raw) {
    // wg show <name> transfer outputs bytes as space/newline separated numbers.
    final matches =
        RegExp(r'-?\d+').allMatches(raw).map((m) => int.tryParse(m.group(0)!)).toList();
    if (matches.length >= 2) {
      return {'rx': matches[0]!.abs(), 'tx': matches[1]!.abs()};
    }
    return {'rx': 0, 'tx': 0};
  }
}
