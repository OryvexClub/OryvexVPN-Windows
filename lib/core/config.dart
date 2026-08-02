/// Central, static app configuration.
/// Keeping these values in one place avoids "magic strings/numbers"
/// scattered across services and screens.
class AppConfig {
  AppConfig._();

  // ---- App metadata -----------------------------------------------------
  static const String appName = 'OryvexVPN';
  static const String appVersion = '1.0.0';

  // ---- Network / WARP -----------------------------------------------------
  static const String warpRegisterUrl =
      'https://api.cloudflareclient.com/v0a737/reg';
  static const String defaultDnsPrimary = '1.1.1.1';
  static const String defaultDnsSecondary = '1.0.0.1';
  static const String defaultEndpointPort = '2408';
  static const int mtu = 1280;
  static const int persistentKeepaliveSeconds = 25;

  // ---- Tunnel / process -----------------------------------------------------
  static const String tunnelInterfaceName = 'oryvexvpn';
  static const Duration processStartupGrace = Duration(milliseconds: 500);
  static const Duration processShutdownGrace = Duration(seconds: 2);
  static const Duration registerTimeout = Duration(seconds: 15);

  // ---- AmneziaWG junk packet obfuscation (Iran-optimized) -----------------------------------------------------
  static const int junkPacketCount = 4;
  static const int junkPacketMinSize = 3;
  static const int junkPacketMaxSize = 8;
  static const int initPacketJunkSize = 5;
  static const int responsePacketJunkSize = 5;
  static const int initPacketMagicHeader = 7;
  static const int responsePacketMagicHeader = 11;
  static const int underloadPacketMagicHeader = 13;
  static const int transportPacketMagicHeader = 17;

  // ---- Window -----------------------------------------------------
  static const double windowWidth = 400;
  static const double windowHeight = 700;

  // ---- Preference keys (SharedPreferences) -----------------------------------------------------
  static const String prefAutoConnect = 'auto_connect';
  static const String prefStartMinimized = 'start_minimized';
}
