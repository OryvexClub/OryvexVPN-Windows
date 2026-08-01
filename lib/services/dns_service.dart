import 'dart:io';

class DnsService {
  static Future<void> clearDns() async {
    if (!Platform.isWindows) return;
    try {
      final interfaces = await _getInterfaces();
      for (var interface in interfaces) {
        await Process.run('netsh', [
          'interface',
          'ipv4',
          'set',
          'dns',
          'name="$interface"',
          'source=dhcp'
        ]);
      }
      await Process.run('ipconfig', ['/flushdns']);
    } catch (e) {
      print('Failed to clear DNS: $e');
    }
  }

  static Future<void> setDns(String primary, [String? secondary]) async {
    if (!Platform.isWindows) return;
    try {
      final interfaces = await _getInterfaces();
      for (var interface in interfaces) {
        // Set primary
        await Process.run('netsh', [
          'interface',
          'ipv4',
          'set',
          'dns',
          'name="$interface"',
          'static',
          primary,
          'primary'
        ]);
        
        // Set secondary if provided
        if (secondary != null) {
          await Process.run('netsh', [
            'interface',
            'ipv4',
            'add',
            'dns',
            'name="$interface"',
            secondary,
            'index=2'
          ]);
        }
      }
      await Process.run('ipconfig', ['/flushdns']);
    } catch (e) {
      print('Failed to set DNS: $e');
    }
  }

  static Future<List<String>> _getInterfaces() async {
    try {
      final result = await Process.run('netsh', ['interface', 'show', 'interface']);
      final lines = result.stdout.toString().split('\n');
      final interfaces = <String>[];
      
      bool skipHeaders = true;
      for (var line in lines) {
        if (line.contains('---')) {
          skipHeaders = false;
          continue;
        }
        if (skipHeaders || line.trim().isEmpty) continue;
        
        // netsh output format: Admin State | State | Type | Interface Name
        // We want the connected interfaces
        if (line.contains('Connected')) {
          // The last column is the name
          final parts = line.trim().split(RegExp(r'\s{2,}'));
          if (parts.length >= 4) {
            interfaces.add(parts.last);
          }
        }
      }
      
      // Fallbacks if detection fails
      if (interfaces.isEmpty) {
        interfaces.addAll(['Wi-Fi', 'Ethernet']);
      }
      
      return interfaces;
    } catch (e) {
      return ['Wi-Fi', 'Ethernet']; // Default fallbacks
    }
  }
}
