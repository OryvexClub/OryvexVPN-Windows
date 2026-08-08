import 'dart:io';
import 'package:http/http.dart' as http;

import 'vpn_core.dart';

class SystemCheckService {
  /// Image names of binaries that belong to OryvexVPN itself. These must
  /// never be flagged as "conflicting/external" processes.
  static const List<String> ownProcesses = [
    'oryvex.exe', 'xray.exe', 'amneziawg.exe', 'awg.exe', 'wireservice.exe',
  ];

  static final RegExp _netstatRow =
      RegExp(r'^\s*(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\d+)\s*$');

  /// PIDs of processes in `LISTENING` state on [port] (local address).
  /// Uses an exact port compare so 1819 never matches 18190.
  static Future<Set<int>> pidsOnPort(int port) async {
    final pids = <int>{};
    if (!Platform.isWindows) return pids;
    try {
      final r = await Process.run('netstat', ['-ano']);
      for (final line in r.stdout.toString().split('\n')) {
        final m = _netstatRow.firstMatch(line.trimRight());
        if (m == null) continue;
        if (m.group(4) != 'LISTENING') continue;
        final local = m.group(2)!; // e.g. 127.0.0.1:1819 | [::1]:1819
        final portStr = local.contains(']:')
            ? local.substring(local.lastIndexOf(']:') + 2)
            : local.split(':').last;
        if (portStr == '$port') {
          final pid = int.tryParse(m.group(5)!);
          if (pid != null) pids.add(pid);
        }
      }
    } catch (e) {
      VpnLogger.debug('SystemCheck', 'netstat failed: $e');
    }
    return pids;
  }

  /// Lowercased image name (e.g. `v2rayn.exe`) for [pid], or null.
  /// Must run with `runInShell:false` so the `PID eq <n>` arg is not split.
  static Future<String?> processNameForPid(int pid) async {
    if (!Platform.isWindows) return null;
    try {
      final r = await Process.run(
        'tasklist',
        ['/FI', 'PID eq $pid', '/FO', 'CSV', '/NH'],
      );
      if (r.exitCode == 0) {
        final m = RegExp(r'"([^"]*)"').firstMatch(r.stdout.toString().trim());
        return m?.group(1)?.toLowerCase();
      }
    } catch (_) {}
    return null;
  }

  /// True when any external VPN/proxy process is running (excludes our own
  /// oryvex/xray/amneziawg/awg/wireservice binaries).
  static Future<bool> isExternalVpnRunning() async {
    final found = await getConflictingProcesses();
    return found.isNotEmpty;
  }

  static Future<bool> isClockSynced() async {
    try {
      final response = await http.head(Uri.parse('https://google.com')).timeout(const Duration(seconds: 5));
      final dateHeader = response.headers['date'];
      if (dateHeader != null) {
        final serverTime = HttpDate.parse(dateHeader);
        final localTime = DateTime.now().toUtc();
        final diff = serverTime.difference(localTime).inMinutes.abs();
        return diff <= 5; // within 5 minutes is okay
      }
    } catch (e) {
      // If we can't reach google, we might not have internet. Assume clock is synced or ignore.
    }
    return true;
  }

  static Future<List<String>> getConflictingProcesses() async {
    final procs = [
      'v2ray.exe', 'v2rayn.exe', 'nekoray.exe', 'nekobox.exe',
      'clash.exe', 'clash-verge.exe', 'clash for windows.exe', 'clash-meta.exe',
      'hiddify.exe', 'hiddify-next.exe', 'outline.exe', 'shadowsocks.exe',
      'psiphon3.exe', 'qv2ray.exe', 'v2raya.exe', 'sing-box.exe',
      'openvpn.exe', 'openvpn-gui.exe', 'cfon.exe', 'lantern.exe',
      'geph-client.exe', 'gephgui.exe', 'freegate.exe', 'v2ray-core.exe',
      'tun2socks.exe'
    ];
    final found = <String>[];
    if (Platform.isWindows) {
      try {
        final result = await Process.run('tasklist', ['/FO', 'CSV', '/NH']);
        if (result.exitCode == 0) {
          final output = result.stdout.toString().toLowerCase();
          for (final proc in procs) {
            // Never flag our own binaries as conflicting.
            if (ownProcesses.contains(proc.toLowerCase())) continue;
            if (output.contains('"$proc"')) {
              found.add(proc);
            }
          }
        }
      } catch (_) {}
    }
    return found;
  }
}
