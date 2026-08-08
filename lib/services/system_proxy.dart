import 'dart:io';

import 'vpn_core.dart';

/// Manages the Windows system proxy (HKCU Internet Settings).
///
/// When the VPN connects in full-tunnel mode, a leftover/stale system proxy
/// (e.g. from v2ray/clash) would otherwise make browsers fail with
/// `ERR_PROXY_CONNECTION_FAILED` because the tunnel does not forward to the
/// configured proxy address. To avoid that we save the current proxy state,
/// disable it while the tunnel is up, and restore it on disconnect.
class SystemProxyService {
  static const String _tag = 'SystemProxy';

  static const String _key =
      r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings';

  static bool? _savedEnabled;
  static String? _savedServer;
  static String? _savedOverride;

  static String _regQuery(String key, String name) {
    if (!Platform.isWindows) return '';
    try {
      final r = Process.runSync('reg', ['query', key, '/v', name]);
      return r.stdout.toString();
    } catch (_) {
      return '';
    }
  }

  /// True when the system proxy is currently enabled (`ProxyEnable=0x1`).
  static bool _isEnabled() {
    final out = _regQuery(_key, 'ProxyEnable');
    return out.toLowerCase().contains('0x1');
  }

  /// Saves the current ProxyEnable / ProxyServer values so they can be
  /// restored after the tunnel goes down.
  static Future<void> saveState() async {
    if (!Platform.isWindows) return;
    _savedEnabled = _isEnabled();
    final serverOut = _regQuery(_key, 'ProxyServer');
    final serverMatch =
        RegExp(r'ProxyServer\s+REG_SZ\s+(.*)').firstMatch(serverOut);
    _savedServer = serverMatch?.group(1)?.trim();
    final overrideOut = _regQuery(_key, 'ProxyOverride');
    final overrideMatch =
        RegExp(r'ProxyOverride\s+REG_SZ\s+(.*)').firstMatch(overrideOut);
    _savedOverride = overrideMatch?.group(1)?.trim();
    VpnLogger.info(_tag,
        'Saved proxy state: enabled=$_savedEnabled server=$_savedServer');
  }

  /// Turns the system proxy off so tunneled traffic flows directly.
  static Future<void> disable() async {
    if (!Platform.isWindows) return;
    VpnLogger.info(_tag, 'Disabling system proxy...');
    try {
      await Process.run('reg', [
        'add', _key, '/v', 'ProxyEnable', '/t', 'REG_DWORD', '/d', '0', '/f',
      ]);
    } catch (e) {
      VpnLogger.warn(_tag, 'Failed to disable system proxy: $e');
    }
  }

  /// Sets the system proxy to point to Xray's HTTP proxy (127.0.0.1:10809).
  /// This routes browser/system traffic through Xray -> oryvex tunnel.
  static Future<void> setToXray() async {
    if (!Platform.isWindows) return;
    VpnLogger.info(_tag, 'Setting system proxy to Xray (127.0.0.1:10809)...');
    try {
      // Enable proxy
      await Process.run('reg', [
        'add', _key, '/v', 'ProxyEnable', '/t', 'REG_DWORD', '/d', '1', '/f',
      ]);
      // Set HTTP proxy
      await Process.run('reg', [
        'add', _key, '/v', 'ProxyServer', '/t', 'REG_SZ',
        '/d', 'http=127.0.0.1:10809;https=127.0.0.1:10809;socks=127.0.0.1:10808', '/f',
      ]);
      // Bypass local addresses
      await Process.run('reg', [
        'add', _key, '/v', 'ProxyOverride', '/t', 'REG_SZ',
        '/d', 'localhost;127.*;10.*;172.16.*;172.17.*;172.18.*;172.19.*;172.20.*;172.21.*;172.22.*;172.23.*;172.24.*;172.25.*;172.26.*;172.27.*;172.28.*;172.29.*;172.30.*;172.31.*;192.168.*;<local>', '/f',
      ]);
      VpnLogger.info(_tag, 'System proxy set to Xray (127.0.0.1:10809)');
    } catch (e) {
      VpnLogger.warn(_tag, 'Failed to set system proxy to Xray: $e');
    }
  }

  /// Unconditionally resets the system proxy back to default: disabled, with
/// blank server and bypass-list values. Unlike [restore] it works even when
/// [saveState] never ran this session (e.g. a stale proxy left over from a
/// crashed run), which is exactly what we want on a full app close.
  static Future<void> resetToDefault() async {
    if (!Platform.isWindows) return;
    VpnLogger.info(_tag, 'Hard-resetting system proxy to default (disabled)...');
    try {
      await Process.run('reg', [
        'add', _key, '/v', 'ProxyEnable', '/t', 'REG_DWORD', '/d', '0', '/f',
      ]);
      await Process.run('reg', [
        'add', _key, '/v', 'ProxyServer', '/t', 'REG_SZ', '/d', '', '/f',
      ]);
      await Process.run('reg', [
        'add', _key, '/v', 'ProxyOverride', '/t', 'REG_SZ', '/d', '', '/f',
      ]);
      VpnLogger.info(_tag, 'System proxy reset to default');
    } catch (e) {
      VpnLogger.warn(_tag, 'Failed to reset system proxy: $e');
    }
    // Clear the saved state so a later [restore] is a no-op.
    _savedEnabled = null;
    _savedServer = null;
    _savedOverride = null;
  }

  /// Restores the proxy state captured by [saveState] (a no-op if the proxy
  /// was never enabled).
  static Future<void> restore() async {
    if (!Platform.isWindows) return;
    if (_savedEnabled == null) {
      // Nothing was saved; just leave the proxy off.
      return;
    }
    VpnLogger.info(_tag, 'Restoring system proxy: enabled=$_savedEnabled');
    try {
      await Process.run('reg', [
        'add', _key, '/v', 'ProxyEnable', '/t', 'REG_DWORD',
        '/d', _savedEnabled! ? '1' : '0', '/f',
      ]);
      if (_savedServer != null) {
        await Process.run('reg', [
          'add', _key, '/v', 'ProxyServer', '/t', 'REG_SZ', '/d', _savedServer!, '/f',
        ]);
      }
      if (_savedOverride != null) {
        await Process.run('reg', [
          'add', _key, '/v', 'ProxyOverride', '/t', 'REG_SZ', '/d', _savedOverride!, '/f',
        ]);
      }
    } catch (e) {
      VpnLogger.warn(_tag, 'Failed to restore system proxy: $e');
    }
    _savedEnabled = null;
    _savedServer = null;
    _savedOverride = null;
  }
}
