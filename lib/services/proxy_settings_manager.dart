import 'dart:io';

class ProxySettingsManager {
  static Future<void> disableProxy() async {
    if (!Platform.isWindows) return;
    try {
      await Process.run('reg', [
        'add',
        'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings',
        '/v',
        'ProxyEnable',
        '/t',
        'REG_DWORD',
        '/d',
        '0',
        '/f'
      ]);
    } catch (e) {
      print('Failed to disable proxy: $e');
    }
  }

  static Future<void> enableProxy(String server, String port) async {
    if (!Platform.isWindows) return;
    try {
      await Process.run('reg', [
        'add',
        'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings',
        '/v',
        'ProxyServer',
        '/t',
        'REG_SZ',
        '/d',
        '$server:$port',
        '/f'
      ]);
      await Process.run('reg', [
        'add',
        'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings',
        '/v',
        'ProxyEnable',
        '/t',
        'REG_DWORD',
        '/d',
        '1',
        '/f'
      ]);
    } catch (e) {
      print('Failed to enable proxy: $e');
    }
  }
}
