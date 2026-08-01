import 'dart:io';
import 'package:window_manager/window_manager.dart';
import 'package:warp_vpn_app/core/config.dart';

/// Thin wrapper around `window_manager` so the rest of the app never has
/// to think about platform checks or repeat the same window options.
class WindowManagerService {
  WindowManagerService._();

  static bool _initialized = false;

  /// Sets up the native window: fixed compact size, centered, hidden
  /// title bar (the app draws its own header). Safe to call multiple
  /// times; it is a no-op after the first successful call.
  static Future<void> init() async {
    if (!Platform.isWindows || _initialized) return;
    _initialized = true;

    await windowManager.ensureInitialized();

    const windowOptions = WindowOptions(
      size: Size(AppConfig.windowWidth, AppConfig.windowHeight),
      minimumSize: Size(AppConfig.windowWidth, AppConfig.windowHeight),
      maximumSize: Size(AppConfig.windowWidth, AppConfig.windowHeight),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  /// Hides the window to the tray instead of closing the process. Wire
  /// this up to the window close event if you want "minimize to tray"
  /// behaviour instead of quitting on the X button.
  static Future<void> hideToTray() async {
    if (!Platform.isWindows) return;
    await windowManager.hide();
  }

  static Future<void> restore() async {
    if (!Platform.isWindows) return;
    await windowManager.show();
    await windowManager.focus();
  }

  static Future<void> quit() async {
    if (!Platform.isWindows) {
      exit(0);
    }
    await windowManager.destroy();
  }
}
