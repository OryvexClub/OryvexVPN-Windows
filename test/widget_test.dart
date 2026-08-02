// Basic smoke test for OryvexVPN.
//
// Note: OryvexVPNApp depends on platform channels (window_manager, tray_manager,
// and the AmneziaWG core) that are unavailable in a headless test environment,
// so we validate the app's static configuration instead of pumping the full UI.

import 'package:flutter_test/flutter_test.dart';
import 'package:warp_vpn_app/core/config.dart';

void main() {
  test('AppConfig exposes expected app metadata', () {
    expect(AppConfig.appName, 'OryvexVPN');
    expect(AppConfig.appVersion, isNotEmpty);
  });

  test('VPN tunnel defaults are sane', () {
    expect(AppConfig.defaultEndpointPort, isNotEmpty);
    expect(AppConfig.mtu, greaterThan(0));
    expect(AppConfig.persistentKeepaliveSeconds, greaterThan(0));
    expect(AppConfig.tunnelInterfaceName, isNotEmpty);
  });
}
