import 'dart:io';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

/// Wraps `tray_manager` to give OryvexVPN a real Windows system-tray icon
/// with a right-click menu (Show, Connect/Disconnect, Quit) and a
/// double-click-to-restore behaviour.
///
/// Call [TrayService.init] once after the first frame is drawn, and call
/// [TrayService.updateConnectionState] whenever the VPN connects/disconnects
/// so the tray menu label stays in sync.
class TrayService with TrayListener {
  TrayService._internal();
  static final TrayService instance = TrayService._internal();

  bool _initialized = false;
  bool _isConnected = false;

  /// Provided by the caller so the tray menu's Connect/Disconnect item can
  /// actually drive the VPN without this service depending on VPNService
  /// directly (keeps this file dependency-light and testable).
  Future<void> Function()? onConnectRequested;
  Future<void> Function()? onDisconnectRequested;
  Future<void> Function()? onQuitRequested;

  Future<void> init() async {
    if (!Platform.isWindows || _initialized) return;
    _initialized = true;

    trayManager.addListener(this);

    try {
      // Resolve the icon relative to the running executable. The relative
      // path 'windows/runner/resources/...' only works from a source checkout,
      // never from the installed app. The icon is shipped inside the bundled
      // data/ folder by the build pipeline.
      final iconPath =
          '${File(Platform.resolvedExecutable).parent.path}\\data\\app_icon.ico';
      await trayManager.setIcon(iconPath);
    } catch (_) {
      // Icon path can vary by build layout; failing to set it should never
      // crash the app - the tray entry will just use a default icon.
    }

    await _rebuildMenu();
    await trayManager.setToolTip('OryvexVPN');
  }

  Future<void> updateConnectionState(bool isConnected) async {
    _isConnected = isConnected;
    if (!_initialized) return;
    await _rebuildMenu();
    await trayManager.setToolTip(
      isConnected ? 'OryvexVPN - Connected' : 'OryvexVPN - Disconnected',
    );
  }

  Future<void> _rebuildMenu() async {
    final menu = Menu(
      items: [
        MenuItem(
          key: 'show_window',
          label: 'Show Window',
        ),
        MenuItem.separator(),
        MenuItem(
          key: 'toggle_connection',
          label: _isConnected ? 'Disconnect' : 'Connect',
        ),
        MenuItem.separator(),
        MenuItem(
          key: 'quit',
          label: 'Quit',
        ),
      ],
    );
    await trayManager.setContextMenu(menu);
  }

  Future<void> dispose() async {
    if (!_initialized) return;
    trayManager.removeListener(this);
    _initialized = false;
  }

  // ---- TrayListener ---------------------------------------------------

  @override
  void onTrayIconMouseDown() {
    // Left click: toggle window visibility.
    _restoreWindow();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    switch (menuItem.key) {
      case 'show_window':
        await _restoreWindow();
        break;
      case 'toggle_connection':
        if (_isConnected) {
          await onDisconnectRequested?.call();
        } else {
          await onConnectRequested?.call();
        }
        break;
      case 'quit':
        await onQuitRequested?.call();
        break;
    }
  }

  Future<void> _restoreWindow() async {
    if (!Platform.isWindows) return;
    final isVisible = await windowManager.isVisible();
    if (!isVisible) {
      await windowManager.show();
    }
    await windowManager.focus();
  }
}
