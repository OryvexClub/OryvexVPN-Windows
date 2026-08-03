import 'dart:io';

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

  // ---- Window -----------------------------------------------------
  static const double windowWidth = 400;
  static const double windowHeight = 700;

  // ---- Preference keys (SharedPreferences) -----------------------------------------------------
  static const String prefAutoConnect = 'auto_connect';
  static const String prefStartMinimized = 'start_minimized';
  static const String prefAntiDpiPreset = 'anti_dpi_preset';

  // ---- Auto-detect device type for WARP registration ----------------------
  static String get deviceType {
    if (Platform.isWindows) return 'Windows';
    if (Platform.isLinux) return 'Linux';
    if (Platform.isMacOS) return 'Mac';
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    return 'Windows';
  }

  // ---- Anti-DPI presets (AmneziaWG junk packet obfuscation) ---------------
  static const Map<String, Map<String, int>> antiDpiPresets = {
    'minimal': {
      'jc': 1, 'jmin': 1, 'jmax': 1,
      's1': 0, 's2': 0,
      'h1': 1, 'h2': 2, 'h3': 3, 'h4': 4,
    },
    'standard': {
      'jc': 3, 'jmin': 1, 'jmax': 3,
      's1': 0, 's2': 0,
      'h1': 1, 'h2': 2, 'h3': 3, 'h4': 4,
    },
    'aggressive': {
      'jc': 5, 'jmin': 5, 'jmax': 20,
      's1': 10, 's2': 15,
      'h1': 5, 'h2': 10, 'h3': 15, 'h4': 20,
    },
    'iran': {
      'jc': 4, 'jmin': 3, 'jmax': 8,
      's1': 5, 's2': 5,
      'h1': 7, 'h2': 11, 'h3': 13, 'h4': 17,
    },
  };

  static const Map<String, String> antiDpiPresetNames = {
    'minimal': 'Minimal',
    'standard': 'Standard',
    'aggressive': 'Aggressive',
    'iran': 'Iran Optimized',
  };

  /// Returns junk packet values for the given [presetName].
  /// Falls back to 'standard' if the preset is unknown.
  static Map<String, int> getAntiDpiValues(String presetName) {
    return antiDpiPresets[presetName] ?? antiDpiPresets['standard']!;
  }
}
