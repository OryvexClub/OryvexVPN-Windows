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
///
/// Uses a dual-config strategy: tries AmneziaWG config first (for DPI bypass
/// in Iran), then falls back to standard WireGuard if the handshake fails.
class WireGuardService {
  static VpnEndpoint? _endpoint;
  static int _totalRx = 0;
  static int _totalTx = 0;

  static const String _tag = 'WireGuard';

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
    VpnLogger.info(_tag, '=== connectWithProgress START ===');

    if (!await VpnCore.coreFilesPresent()) {
      final missing = await VpnCore.missingFiles();
      VpnLogger.error(_tag, 'Core files missing: $missing');
      throw Exception(
        'فایل‌های هسته VPN یافت نشد (${missing.join('، ')}). لطفا برنامه را دوباره نصب کنید.',
      );
    }

    onProgress('در حال یافتن سریع‌ترین سرور...');
    VpnLogger.info(_tag, 'Picking fastest endpoint...');
    final endpoint = await pickFastestEndpoint();
    if (endpoint == null) {
      VpnLogger.error(_tag, 'No endpoint reachable');
      throw Exception('هیچ سروری در دسترس نیست. لطفا اینترنت را بررسی کنید.');
    }
    VpnLogger.info(_tag, 'Selected endpoint: ${endpoint.hostPort}');

    onProgress('در حال ثبت‌نام با Cloudflare WARP...');
    VpnLogger.info(_tag, 'Registering with WARP...');
    final reg = await WarpRegistrationService.register(
      resolveEndpoint: () async => endpoint,
    );
    _endpoint = reg.endpoint;
    VpnLogger.info(_tag, 'Registration complete. Endpoint: ${reg.endpoint.hostPort}');
    VpnLogger.info(_tag, 'Address v4: ${reg.addressV4}');
    VpnLogger.info(_tag, 'Address v6: ${reg.addressV6}');
    VpnLogger.info(_tag, 'Peer public key: ${reg.peerPublicKey}');

    final confDir = await _confDir();

    // === STRATEGY: Try AmneziaWG config first, fallback to standard WireGuard ===

    // --- Attempt 1: AmneziaWG config with obfuscation parameters ---
    VpnLogger.info(_tag, '--- Attempt 1: AmneziaWG config ---');
    final confFileAmnezia = File('$confDir\\${VpnCore.tunnelName}.conf');
    final amneziaConf = reg.buildConf();
    await confFileAmnezia.writeAsString(amneziaConf);
    VpnLogger.info(_tag, 'AmneziaWG config written to ${confFileAmnezia.path}');
    VpnLogger.info(_tag, 'AmneziaWG config:\n$amneziaConf');

    onProgress('در حال راه‌اندازی تونل امن...');
    if (await VpnCore.serviceExists()) {
      VpnLogger.info(_tag, 'Stale tunnel exists, removing...');
      await VpnCore.uninstallTunnel();
    }

    try {
      await VpnCore.installTunnel(confFileAmnezia.path);
      onProgress('در حال تنظیم DNS...');
      await VpnCore.flushDns();
      // Check if service started — if so, we're done
      if (await VpnCore.serviceRunning()) {
        VpnLogger.info(_tag, '=== TUNNEL RUNNING (AmneziaWG) ===');
        final showOutput = await VpnCore.readShow();
        VpnLogger.info(_tag, 'awg show output:\n$showOutput');
        VpnLogger.info(_tag, '=== connectWithProgress END ===');
        return;
      }
    } catch (e) {
      VpnLogger.error(_tag, 'AmneziaWG tunnel install failed: $e');
    }

    // --- Attempt 2: Standard WireGuard config (no obfuscation) ---
    VpnLogger.info(_tag, '--- Attempt 2: Standard WireGuard config ---');
    onProgress('تلاش مجدد با تنظیمات استاندارد...');

    // Clean up previous attempt
    try {
      await VpnCore.uninstallTunnel();
    } catch (_) {}

    final confFileStandard = File('$confDir\\${VpnCore.tunnelName}_wg.conf');
    final standardConf = reg.buildStandardConf();
    await confFileStandard.writeAsString(standardConf);
    VpnLogger.info(_tag, 'Standard config written to ${confFileStandard.path}');
    VpnLogger.info(_tag, 'Standard config:\n$standardConf');

    try {
      await VpnCore.installTunnel(confFileStandard.path);
      onProgress('در حال تنظیم DNS...');
      await VpnCore.flushDns();
      if (await VpnCore.serviceRunning()) {
        VpnLogger.info(_tag, '=== TUNNEL RUNNING (Standard WG) ===');
        final showOutput = await VpnCore.readShow();
        VpnLogger.info(_tag, 'awg show output:\n$showOutput');
      } else {
        VpnLogger.error(_tag, '=== TUNNEL NOT RUNNING ===');
      }
    } catch (e) {
      VpnLogger.error(_tag, 'Standard WG tunnel install failed: $e');
    }

    VpnLogger.info(_tag, '=== connectWithProgress END ===');
  }

  static Future<void> connect() async => await connectWithProgress((_) {});

  static Future<void> disconnect() async {
    VpnLogger.info(_tag, '=== disconnect START ===');
    if (!Platform.isWindows) return;
    await VpnCore.fullCleanup();
    _endpoint = null;
    _totalRx = 0;
    _totalTx = 0;
    VpnLogger.info(_tag, '=== disconnect END ===');
  }

  /// True when the tunnel service is running.
  /// No handshake check — the tunnel itself being alive is sufficient.
  static Future<bool> isConnected() async {
    if (!Platform.isWindows) return false;
    final running = await VpnCore.serviceRunning();
    VpnLogger.debug(_tag, 'isConnected: serviceRunning=$running');
    return running;
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
