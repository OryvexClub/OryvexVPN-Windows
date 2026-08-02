import 'dart:io';
import 'dart:async';
import 'package:path_provider/path_provider.dart';

import 'endpoints.dart';
import 'vpn_core.dart';
import 'warp_registration.dart';

/// Drives the VPN connection lifecycle.
///
/// The heavy lifting (tunnel install, stats, handshake) lives in [VpnCore];
/// this class coordinates: register with WARP -> pick endpoint -> build conf
/// -> install tunnel -> wait for a real handshake.
class WireGuardService {
  static VpnEndpoint? _endpoint;
  static int _totalRx = 0;
  static int _totalTx = 0;

  static VpnEndpoint? get currentEndpoint => _endpoint;

  /// Confirms the app can actually reach the tunnel core.
  static Future<bool> coreReady() => VpnCore.coreFilesPresent();

  static Future<String> _confDir() async {
    final dir = await getApplicationSupportDirectory();
    final confDir = Directory('${dir.path}\\${VpnCore.tunnelName}');
    if (!await confDir.exists()) await confDir.create(recursive: true);
    return confDir.path;
  }

  static Future<void> connectWithProgress(Function(String) onProgress) async {
    if (!await VpnCore.coreFilesPresent()) {
      final missing = await VpnCore.missingFiles();
      throw Exception(
        'فایل‌های هسته VPN یافت نشد (${missing.join('، ')}). لطفا برنامه را دوباره نصب کنید.',
      );
    }

    onProgress('در حال یافتن سریع‌ترین سرور...');
    final endpoint = await pickFastestEndpoint();
    if (endpoint == null) {
      throw Exception('هیچ سروری در دسترس نیست. لطفا اینترنت را بررسی کنید.');
    }

    onProgress('در حال ثبت‌نام با Cloudflare WARP...');
    final reg = await WarpRegistrationService.register(
      resolveEndpoint: () async => endpoint,
    );
    _endpoint = reg.endpoint;

    final confDir = await _confDir();
    final confFile = File('$confDir\\${VpnCore.tunnelName}.conf');
    await confFile.writeAsString(reg.buildConf());

    onProgress('در حال راه‌اندازی تونل امن...');
    // Clear any stale tunnel from a previous run.
    if (await VpnCore.serviceExists()) {
      await VpnCore.uninstallTunnel();
    }
    await VpnCore.installTunnel(confFile.path);

    onProgress('در حال تنظیم DNS...');
    await VpnCore.flushDns();

    onProgress('در حال تایید اتصال...');
    final handshakeOk = await _waitForHandshake(
      timeout: const Duration(seconds: 10),
    );
    if (!handshakeOk) {
      // Tunnel service may be up but no handshake yet - still report connected
      // and let the monitor re-verify. Log it loudly so it's debuggable.
      print('WARNING: no WireGuard handshake detected within 10s');
    }
  }

  static Future<void> connect() async => await connectWithProgress((_) {});

  /// Polls until a real handshake is seen or [timeout] elapses.
  static Future<bool> _waitForHandshake({required Duration timeout}) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final age = await VpnCore.readHandshakeAge();
      if (age != null && age < 60) return true;
      await Future.delayed(const Duration(milliseconds: 800));
    }
    return false;
  }

  static Future<void> disconnect() async {
    if (!Platform.isWindows) return;
    await VpnCore.uninstallTunnel();
    _endpoint = null;
    _totalRx = 0;
    _totalTx = 0;
  }

  /// True only when the tunnel service is up AND has a recent handshake
  /// (i.e. traffic is actually flowing). This prevents the fake "connected
  /// but 0 data" state.
  static Future<bool> isConnected() async {
    if (!Platform.isWindows) return false;
    if (!await VpnCore.serviceRunning()) return false;

    final age = await VpnCore.readHandshakeAge();
    if (age == null) return false;
    // A handshake that happened within the last 3 minutes means the tunnel is
    // genuinely alive.
    return age < 180;
  }

  /// Real tunnel statistics: bytes transferred and handshake age.
  static Future<Map<String, dynamic>> getTunnelStats() async {
    final transfer = await VpnCore.readTransfer();
    _totalRx = transfer['rx'] ?? 0;
    _totalTx = transfer['tx'] ?? 0;
    final handshakeAge = await VpnCore.readHandshakeAge();
    return {
      'rx_bytes': _totalRx,
      'tx_bytes': _totalTx,
      'handshake_age': handshakeAge,
      'endpoint': _endpoint?.hostPort ?? '',
    };
  }
}
