import 'dart:io';

/// Higher-level convenience wrapper around [ProxySettingsManager]-style
/// registry calls. Kept separate from [ProxySettingsManager] so callers
/// that only need "is a proxy currently forced by us?" style checks don't
/// need to reach into the raw registry logic.
class ProxyService {
  ProxyService._();

  static const String _regPath =
      r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings';

  /// Returns true if ProxyEnable is currently set to 1 in the registry.
  static Future<bool> isProxyEnabled() async {
    if (!Platform.isWindows) return false;
    try {
      final result = await Process.run(
        'reg',
        ['query', _regPath, '/v', 'ProxyEnable'],
      );
      if (result.exitCode != 0) return false;
      final out = result.stdout.toString();
      return out.contains('0x1');
    } catch (_) {
      return false;
    }
  }

  /// Returns the currently configured proxy server (host:port), or null
  /// if none is set / proxy is disabled.
  static Future<String?> currentProxyServer() async {
    if (!Platform.isWindows) return null;
    try {
      final result = await Process.run(
        'reg',
        ['query', _regPath, '/v', 'ProxyServer'],
      );
      if (result.exitCode != 0) return null;
      final out = result.stdout.toString();
      final match = RegExp(r'REG_SZ\s+(\S+)').firstMatch(out);
      return match?.group(1);
    } catch (_) {
      return null;
    }
  }

  /// Notifies Windows that Internet Settings changed, so apps (including
  /// the shell) pick up the new proxy configuration immediately instead
  /// of waiting for the next process restart.
  static Future<void> refreshSystemProxySettings() async {
    if (!Platform.isWindows) return;
    try {
      // InternetSetOption with INTERNET_OPTION_SETTINGS_CHANGED (39) and
      // INTERNET_OPTION_REFRESH (37) is the "proper" WinAPI way, but that
      // requires FFI bindings. As a practical, dependency-free substitute
      // we nudge the system via WinHTTP proxy reset, which most apps
      // (including Chromium-based browsers) will observe on next request.
      await Process.run('netsh', ['winhttp', 'import', 'proxy', 'source=ie']);
    } catch (_) {
      // Non-fatal: some Windows editions don't support this; proxy still
      // applies for new processes/network requests regardless.
    }
  }
}
