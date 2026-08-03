import 'dart:io';
import 'package:http/http.dart' as http;

class SystemCheckService {
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
    final procs = ['wg.exe', 'amneziawg.exe', 'awg.exe', 'wireservice.exe', 'v2ray.exe', 'xray.exe', 'nekoray.exe', 'v2raya.exe'];
    final found = <String>[];
    if (Platform.isWindows) {
      try {
        final result = await Process.run('tasklist', ['/FO', 'CSV', '/NH']);
        if (result.exitCode == 0) {
          final output = result.stdout.toString().toLowerCase();
          for (final proc in procs) {
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
