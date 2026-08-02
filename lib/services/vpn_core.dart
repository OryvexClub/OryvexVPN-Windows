import 'dart:io';


class VpnCore {
  VpnCore._();

  static String get _exeDir => File(Platform.resolvedExecutable).parent.path;
  static String get _dataDir => '$_exeDir\\data';
  static String get amneziaWgExe => '$_dataDir\\amneziawg.exe';
  static String get awgExe => '$_dataDir\\awg.exe';
  static String get wintunDll => '$_dataDir\\wintun.dll';

  static const String tunnelName = 'oryvexvpn';
  static const String serviceName = 'WireGuardTunnel\$$tunnelName';

  /// Check if AmneziaWG core is available.
  static Future<bool> coreAvailable() async {
    return await File(amneziaWgExe).exists();
  }

  /// Path to the AmneziaWG core executable.
  static Future<String> coreExe() async => amneziaWgExe;

  /// True when the required pieces are present: AmneziaWG exe + wintun driver.
  static Future<bool> coreFilesPresent() async {
    if (!await File(amneziaWgExe).exists()) return false;
    return await File(wintunDll).exists();
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
    return missing;
  }

  // ---- Tunnel service lifecycle -----------------------------------------

  static Future<bool> serviceExists() async {
    final result = await Process.run('sc', ['query', serviceName],
        runInShell: true);
    return result.exitCode == 0;
  }

  static Future<bool> serviceRunning() async {
    try {
      final result = await Process.run('sc', ['query', serviceName]);
      return result.stdout.toString().contains('RUNNING');
    } catch (_) {
      return false;
    }
  }

  static Future<void> installTunnel(String confPath) async {
    final exe = await coreExe();
    final result = await Process.run(
        exe, ['/installtunnelservice', confPath]);
    if (result.exitCode != 0) {
      throw Exception(
        'Failed to install AmneziaWG tunnel service: ${result.stderr}',
      );
    }
    await Future.delayed(const Duration(milliseconds: 1500));
  }

  static Future<void> uninstallTunnel() async {
    if (!await serviceExists()) return;
    try {
      await Process.run('sc', ['stop', serviceName])
          .timeout(const Duration(seconds: 3));
    } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 400));

    final exe = await coreExe();
    final result = await Process.run(exe, ['/uninstalltunnelservice', tunnelName])
        .timeout(const Duration(seconds: 4));
    if (result.exitCode != 0) {
      throw Exception('Failed to uninstall AmneziaWG tunnel: ${result.stderr}');
    }
    await Future.delayed(const Duration(milliseconds: 400));
  }

  /// Best-effort DNS flush after the tunnel is up so the new resolvers take
  /// effect immediately.
  static Future<void> flushDns() async {
    try {
      await Process.run('ipconfig', ['/flushdns']).timeout(
        const Duration(seconds: 3),
      );
    } catch (_) {}
  }

  // ---- Statistics --------------------------------------------------------

  /// Returns `{ 'rx': int, 'tx': int }` from `awg show <name> transfer`.
  /// Uses AmneziaWG's awg.exe stats tool.
  static Future<Map<String, int>> readTransfer() async {
    final reader = _statsReaderPath();
    if (reader == null) return {'rx': 0, 'tx': 0};
    try {
      final result = await Process.run(reader, ['show', tunnelName, 'transfer']);
      if (result.exitCode == 0) {
        return _parseTransfer(result.stdout.toString());
      }
    } catch (_) {}
    return {'rx': 0, 'tx': 0};
  }

  /// Returns the age in seconds since the latest handshake, or `null` if there
  /// has never been a handshake (tunnel not actually live).
  static Future<int?> readHandshakeAge() async {
    final reader = _statsReaderPath();
    if (reader == null) return null;
    try {
      final result = await Process.run(
          reader, ['show', tunnelName, 'latest-handshakes']);
      if (result.exitCode != 0) return null;
      final line = result.stdout.toString().trim();
      // Expected: "<rx-tab-handle>\t<unix-seconds>" (0 if never handshaken).
      final parts = line.trim().split(RegExp(r'\s+'));
      if (parts.isEmpty) return null;
      final ts = int.tryParse(parts.last);
      if (ts == null || ts <= 0) return null;
      final age = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000 - ts;
      return age < 0 ? 0 : age;
    } catch (_) {
      return null;
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
        RegExp(r'\d+').allMatches(raw).map((m) => int.tryParse(m.group(0)!)).toList();
    if (matches.length >= 2) {
      return {'rx': matches[0]!, 'tx': matches[1]!};
    }
    return {'rx': 0, 'tx': 0};
  }
}
