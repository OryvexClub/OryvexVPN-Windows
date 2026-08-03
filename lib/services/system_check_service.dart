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
    return <String>[];
  }
}
