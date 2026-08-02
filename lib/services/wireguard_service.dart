import 'dart:io';
import 'dart:async';
import 'package:path_provider/path_provider.dart';

import 'endpoints.dart';
import 'vpn_core.dart';
import 'warp_registration.dart';
import 'vpn_service.dart';

/// Drives the VPN connection lifecycle.
///
/// The heavy lifting (tunnel install, stats, handshake) lives in [VpnCore];
/// this class coordinates: register with WARP -> pick endpoint -> build conf
/// -> install tunnel -> verify connection.
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

  static Future<void> connectWithProgress({
    required void Function(String msg, VpnStage stage) onProgress,
  }) async {
    VpnLogger.info(_tag, '=== connectWithProgress START ===');

    // Step 1: Check core files
    if (!await VpnCore.coreFilesPresent()) {
      final missing = await VpnCore.missingFiles();
      VpnLogger.error(_tag, 'Core files missing: $missing');
      throw Exception(
        'VPN core files not found (${missing.join(', ')}). Please reinstall the app.',
      );
    }

    // Step 2: Find fastest endpoint
    onProgress('در حال یافتن سریع‌ترین سرور...', VpnStage.fetchingConfig);
    VpnLogger.info(_tag, 'Picking fastest endpoint...');
    final endpoint = await pickFastestEndpoint();
    if (endpoint == null) {
      VpnLogger.error(_tag, 'No endpoint reachable');
      throw Exception('هیچ سروری در دسترس نیست. لطفا اینترنت خود را بررسی کنید.');
    }
    VpnLogger.info(_tag, 'Selected endpoint: ${endpoint.hostPort}');

    // Step 3: Register with Cloudflare WARP
    onProgress('در حال ثبت‌نام با Cloudflare WARP...', VpnStage.fetchingConfig);
    VpnLogger.info(_tag, 'Registering with WARP...');
    final reg = await WarpRegistrationService.register(
      resolveEndpoint: () async => endpoint,
    );
    _endpoint = reg.endpoint;
    VpnLogger.info(_tag, 'Registration complete. Endpoint: ${reg.endpoint.hostPort}');
    VpnLogger.info(_tag, 'Address v4: ${reg.addressV4}');
    VpnLogger.info(_tag, 'Address v6: ${reg.addressV6}');
    VpnLogger.info(_tag, 'Peer public key: ${reg.peerPublicKey}');

    // Step 4: Write config
    onProgress('در حال ایجاد تنظیمات AmneziaWG...', VpnStage.installingTunnel);
    final confDir = await _confDir();
    final confFile = File('$confDir\\${VpnCore.tunnelName}.conf');
    final amneziaConf = reg.buildConf();
    await confFile.writeAsString(amneziaConf);
    VpnLogger.info(_tag, 'Config written to ${confFile.path}');

    // Step 5: Install tunnel
    onProgress('در حال نصب تونل امن...', VpnStage.installingTunnel);
    if (await VpnCore.serviceExists()) {
      VpnLogger.info(_tag, 'Stale tunnel exists, removing...');
      await VpnCore.uninstallTunnel();
    }
    await VpnCore.installTunnel(confFile.path);

    // Step 6: Flush DNS (fire-and-forget, don't block on it)
    // The tunnel is already working after installTunnel succeeded.
    VpnCore.flushDns().catchError((_) {});

    VpnLogger.info(_tag, '=== TUNNEL INSTALLED SUCCESSFULLY ===');
    VpnLogger.info(_tag, '=== connectWithProgress END ===');
  }

  static Future<void> connect() async {
    await connectWithProgress(onProgress: (_, __) {});
  }

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
