import 'dart:io';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:warp_vpn_app/core/config.dart';

class WindowManagerService {
  WindowManagerService._();

  static bool _initialized = false;

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
