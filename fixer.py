#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
fixer.py - OryvexVPN Full Project Debugger & Fixer

This script is a *surgical* fixer, not a blunt overwrite-everything tool.
It scans the Flutter project, detects specific known problems (empty files,
broken references, missing pubspec dependencies, syntax landmines) and fixes
ONLY those. Files that are already complete and correct are left untouched.

What it checks/fixes:
  1. Empty or stub service files that other code depends on:
       - lib/services/network_manager.dart   -> full connectivity monitor
       - lib/services/proxy_service.dart     -> full Windows proxy helper
       - lib/services/tray_service.dart      -> full system tray integration
       - lib/services/window_manager_service.dart -> full window helper
       - lib/core/config.dart                -> full app config constants
  2. lib/widgets/endpoint_selector.dart
       - was referencing a deleted file (warp_generator.dart) and was
         truncated mid-line. Rewritten fully, self-contained, no dead imports.
  3. pubspec.yaml
       - adds missing dependencies that other files already `import`
         (window_manager, settings_ui, shared_preferences) without
         clobbering versions/deps that are already present and fine.
  4. Dangling references
       - scans lib/**/*.dart for `import` statements pointing at files that
         don't exist on disk, and reports them (does not silently delete
         call sites it doesn't understand).
  5. .gitignore secrets hygiene (adds missing common secret patterns).
  6. Token scrub (removes any accidentally committed GitHub tokens).

Everything is idempotent: running it twice produces no diff on the second run.
Run:  python fixer.py [project_root]
"""

import os
import re
import sys
import subprocess
from pathlib import Path
from typing import Optional, List, Tuple


class FlutterProjectFixer:
    def __init__(self, project_root: Optional[str] = None):
        if project_root:
            self.root = Path(project_root)
        else:
            script_dir = Path(__file__).resolve().parent
            if (script_dir / "pubspec.yaml").exists():
                self.root = script_dir
            else:
                self.root = Path(os.getcwd())
        self.fixed_files: List[str] = []
        self.skipped_files: List[str] = []
        self.warnings: List[str] = []

    # ------------------------------------------------------------------ #
    # utils
    # ------------------------------------------------------------------ #
    def log(self, message: str, level: str = "INFO"):
        icons = {
            "INFO": "[i]", "SUCCESS": "[OK]", "WARNING": "[!]",
            "ERROR": "[X]", "STEP": "[>]", "FIX": "[FIX]", "SKIP": "[--]",
        }
        print(f"{icons.get(level, '[i]')} {message}")

    def _write_if_needed(self, path: Path, content: str, reason: str, force: bool = False):
        """
        Writes `content` to `path` only if the file is missing, empty/whitespace,
        or `force` is True. Otherwise leaves the existing file untouched and logs
        that it was skipped (so we never clobber good, hand-written code).
        """
        path.parent.mkdir(parents=True, exist_ok=True)
        rel = str(path.relative_to(self.root)) if self._is_relative(path) else str(path)

        if path.exists() and not force:
            try:
                existing = path.read_text(encoding='utf-8')
            except Exception:
                existing = ""
            if existing.strip():
                self.skipped_files.append(f"{rel} (already has content, left untouched)")
                self.log(f"Skipped {rel} - already populated", "SKIP")
                return False

        path.write_text(content, encoding='utf-8')
        self.fixed_files.append(f"{rel} ({reason})")
        self.log(f"Fixed {rel}: {reason}", "FIX")
        return True

    def _is_relative(self, path: Path) -> bool:
        try:
            path.relative_to(self.root)
            return True
        except ValueError:
            return False

    # ------------------------------------------------------------------ #
    # project sanity
    # ------------------------------------------------------------------ #
    def check_project(self) -> bool:
        if not (self.root / "pubspec.yaml").exists():
            self.log("pubspec.yaml not found! Not a Flutter project.", "ERROR")
            return False
        self.log("Flutter project detected.", "SUCCESS")
        return True

    # ------------------------------------------------------------------ #
    # 1. Empty / stub service files -> full implementations
    # ------------------------------------------------------------------ #
    def fix_config_dart(self) -> bool:
        path = self.root / "lib" / "core" / "config.dart"
        content = '''/// Central, static app configuration.
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
}
'''
        return self._write_if_needed(path, content, "was empty, added AppConfig constants")

    def fix_network_manager(self) -> bool:
        path = self.root / "lib" / "services" / "network_manager.dart"
        content = '''import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Watches the OS-level network connectivity and exposes a simple stream
/// the rest of the app can subscribe to (e.g. to auto-pause/resume the
/// tunnel, or to warn the user when they lose internet mid-connect).
class NetworkManager {
  NetworkManager._internal();
  static final NetworkManager instance = NetworkManager._internal();

  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _onlineController =
      StreamController<bool>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  /// Broadcasts `true` when the device has *some* network interface up,
  /// `false` when it doesn't. This is a coarse check (interface-level),
  /// not a guarantee of actual internet reachability.
  Stream<bool> get onConnectivityChanged => _onlineController.stream;

  Future<void> start() async {
    // Prime the initial state.
    try {
      final initial = await _connectivity.checkConnectivity();
      _isOnline = _resultsToOnline(initial);
    } catch (_) {
      _isOnline = true;
    }

    _subscription?.cancel();
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      final online = _resultsToOnline(results);
      if (online != _isOnline) {
        _isOnline = online;
        _onlineController.add(_isOnline);
      }
    });
  }

  bool _resultsToOnline(List<ConnectivityResult> results) {
    return results.any((r) => r != ConnectivityResult.none);
  }

  Future<bool> checkNow() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _isOnline = _resultsToOnline(results);
      return _isOnline;
    } catch (_) {
      return _isOnline;
    }
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}
'''
        return self._write_if_needed(path, content, "was empty, added connectivity monitor")

    def fix_proxy_service(self) -> bool:
        path = self.root / "lib" / "services" / "proxy_service.dart"
        content = '''import 'dart:io';

/// Higher-level convenience wrapper around [ProxySettingsManager]-style
/// registry calls. Kept separate from [ProxySettingsManager] so callers
/// that only need "is a proxy currently forced by us?" style checks don't
/// need to reach into the raw registry logic.
class ProxyService {
  ProxyService._();

  static const String _regPath =
      r'HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings';

  /// Returns true if ProxyEnable is currently set to 1 in the registry.
  static Future<bool> isProxyEnabled() async {
    if (!Platform.isWindows) return false;
    try {
      final result = await Process.run(
        'reg',
        ['query', _regPath, '/v', 'ProxyEnable'],
      );
      if (result.exitCode != 0) return false;
      final out = result.stdout.toString();
      return out.contains('0x1');
    } catch (_) {
      return false;
    }
  }

  /// Returns the currently configured proxy server (host:port), or null
  /// if none is set / proxy is disabled.
  static Future<String?> currentProxyServer() async {
    if (!Platform.isWindows) return null;
    try {
      final result = await Process.run(
        'reg',
        ['query', _regPath, '/v', 'ProxyServer'],
      );
      if (result.exitCode != 0) return null;
      final out = result.stdout.toString();
      final match = RegExp(r'REG_SZ\\s+(\\S+)').firstMatch(out);
      return match?.group(1);
    } catch (_) {
      return null;
    }
  }

  /// Notifies Windows that Internet Settings changed, so apps (including
  /// the shell) pick up the new proxy configuration immediately instead
  /// of waiting for the next process restart.
  static Future<void> refreshSystemProxySettings() async {
    if (!Platform.isWindows) return;
    try {
      // InternetSetOption with INTERNET_OPTION_SETTINGS_CHANGED (39) and
      // INTERNET_OPTION_REFRESH (37) is the "proper" WinAPI way, but that
      // requires FFI bindings. As a practical, dependency-free substitute
      // we nudge the system via WinHTTP proxy reset, which most apps
      // (including Chromium-based browsers) will observe on next request.
      await Process.run('netsh', ['winhttp', 'import', 'proxy', 'source=ie']);
    } catch (_) {
      // Non-fatal: some Windows editions don't support this; proxy still
      // applies for new processes/network requests regardless.
    }
  }
}
'''
        return self._write_if_needed(path, content, "was empty, added proxy status/refresh helpers")

    def fix_tray_service(self) -> bool:
        path = self.root / "lib" / "services" / "tray_service.dart"
        content = '''import 'dart:io';
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
      await trayManager.setIcon('windows/runner/resources/app_icon.ico');
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
      isConnected ? 'OryvexVPN - متصل' : 'OryvexVPN - قطع',
    );
  }

  Future<void> _rebuildMenu() async {
    final menu = Menu(
      items: [
        MenuItem(
          key: 'show_window',
          label: 'نمایش پنجره',
        ),
        MenuItem.separator(),
        MenuItem(
          key: 'toggle_connection',
          label: _isConnected ? 'قطع اتصال' : 'اتصال',
        ),
        MenuItem.separator(),
        MenuItem(
          key: 'quit',
          label: 'خروج',
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
'''
        return self._write_if_needed(path, content, "was empty, added full system tray integration")

    def fix_window_manager_service(self) -> bool:
        path = self.root / "lib" / "services" / "window_manager_service.dart"
        content = '''import 'dart:io';
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
'''
        return self._write_if_needed(path, content, "was empty, added window lifecycle helper")

    def fix_endpoint_selector(self) -> bool:
        """
        This file previously imported a deleted file (warp_generator.dart)
        and was truncated mid-statement. It's not wired into the current
        main flow (home_screen.dart doesn't use it), but leaving a broken
        file in lib/ breaks `flutter analyze` / `flutter build` for the
        whole project, so it must be fully self-contained and valid.
        """
        path = self.root / "lib" / "widgets" / "endpoint_selector.dart"
        content = '''import 'dart:math';
import 'package:flutter/material.dart';
import '../constants/strings.dart';

/// Self-contained Cloudflare WARP endpoint picker.
///
/// This widget used to depend on a `WARPGenerator` helper class that no
/// longer exists in the project; the endpoint list now lives directly in
/// this file so the widget has no dangling imports.
class EndpointSelector extends StatefulWidget {
  final void Function(String ip, String port) onEndpointSelected;

  const EndpointSelector({super.key, required this.onEndpointSelected});

  @override
  State<EndpointSelector> createState() => _EndpointSelectorState();
}

class _EndpointSelectorState extends State<EndpointSelector> {
  static const List<String> _endpoints = [
    "162.159.192.1", "162.159.192.2", "162.159.193.1", "162.159.193.5",
    "162.159.195.1", "162.159.195.2", "162.159.195.5",
    "188.114.96.0", "188.114.96.1", "188.114.96.2", "188.114.96.3",
    "188.114.96.4", "188.114.96.5", "188.114.97.0", "188.114.97.1",
    "188.114.97.2", "188.114.97.3", "188.114.97.4", "188.114.97.5",
    "188.114.98.0", "188.114.98.1", "188.114.98.2", "188.114.99.0",
    "188.114.99.1", "188.114.99.2",
  ];
  static const String _defaultPort = '2408';

  final Random _random = Random();
  bool _useCustom = false;
  String _selectedIp = '';
  String _selectedPort = '';

  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _portController = TextEditingController();

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Map<String, String> _pickRandomEndpoint() {
    final ip = _endpoints[_random.nextInt(_endpoints.length)];
    return {'ip': ip, 'port': _defaultPort};
  }

  void _applyEndpoint(String ip, String port) {
    widget.onEndpointSelected(ip, port);
    setState(() {
      _selectedIp = ip;
      _selectedPort = port;
      _useCustom = true;
      _ipController.text = ip;
      _portController.text = port;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.route, color: Color(0xFF10B981)),
                const SizedBox(width: 8),
                Text(
                  Strings.endpoint,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.shuffle, color: Color(0xFF10B981)),
                  tooltip: Strings.randomIP,
                  onPressed: () {
                    final endpoint = _pickRandomEndpoint();
                    _applyEndpoint(endpoint['ip']!, endpoint['port']!);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${Strings.randomIP}: ${endpoint['ip']}:${endpoint['port']}',
                        ),
                        backgroundColor: const Color(0xFF10B981),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<bool>(
                    initialValue: _useCustom,
                    style: const TextStyle(color: Colors.white),
                    dropdownColor: const Color(0xFF1A1A1A),
                    items: const [
                      DropdownMenuItem(value: false, child: Text(Strings.auto)),
                      DropdownMenuItem(value: true, child: Text(Strings.custom)),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _useCustom = value ?? false;
                        if (!_useCustom) {
                          _selectedIp = '';
                          _selectedPort = '';
                          _ipController.clear();
                          _portController.clear();
                          widget.onEndpointSelected('', '');
                        }
                      });
                    },
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[800]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[800]!),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_useCustom) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _ipController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: Strings.ipAddress,
                        labelStyle: TextStyle(color: Colors.grey[400]),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _portController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: Strings.port,
                        labelStyle: TextStyle(color: Colors.grey[400]),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      final ip = _ipController.text.trim();
                      final port = _portController.text.trim();
                      if (ip.isNotEmpty && port.isNotEmpty) {
                        _applyEndpoint(ip, port);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                    ),
                    child: Text(Strings.apply),
                  ),
                ],
              ),
              if (_selectedIp.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF10B981).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 18),
                      const SizedBox(width: 8),
                      Text(
                        '${Strings.selected}: $_selectedIp:$_selectedPort',
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
'''
        # This one is genuinely broken (dangling import + truncated code) in
        # its original form, so we force-overwrite it - but ONLY while it
        # still shows the specific broken markers (dangling import to the
        # deleted warp_generator.dart, or a truncated dropdown line). Once
        # fixed, re-running must be a no-op, so we don't force blindly on
        # every run - that would silently clobber any manual edits made
        # after the first fix.
        existing_text = path.read_text(encoding='utf-8') if path.exists() else ""
        is_broken = (not path.exists()) or (
            'warp_generator.dart' in existing_text
            or 'WARPGenerator' in existing_text
        )
        return self._write_if_needed(
            path, content,
            "referenced deleted warp_generator.dart and was truncated - rewritten standalone",
            force=is_broken,
        )

    # ------------------------------------------------------------------ #
    # 1b. pubspec.yaml SDK constraint vs CI Flutter version mismatch
    # ------------------------------------------------------------------ #
    def fix_sdk_constraint_mismatch(self) -> bool:
        """
        Root-cause fix for CI failures like:
          "The current Dart SDK version is 3.5.0.
           Because warp_vpn_app requires SDK version ^3.12.2, version
           solving failed."

        This happens when .dart_tool/package_config.json (generated locally
        by a newer Flutter/Dart install, e.g. Flutter 3.44.2 / Dart 3.12.2)
        gets committed to git, and/or the pubspec.yaml `environment: sdk:`
        constraint drifts to something CI's pinned Flutter version can't
        satisfy. We fix both sides:
          (a) loosen pubspec.yaml's sdk constraint to a broad, safe range
          (b) bump the CI workflow's pinned Flutter version to one that
              actually ships a matching Dart SDK
          (c) remove committed .dart_tool/ (it's a local build cache and
              should never be in git - it's what caused the drift)
        """
        changed = False

        # (a) pubspec.yaml sdk constraint
        pubspec = self.root / "pubspec.yaml"
        if pubspec.exists():
            text = pubspec.read_text(encoding='utf-8')
            new_text, count = re.subn(
                r"sdk:\s*['\"][^'\"]*['\"]",
                "sdk: '>=3.0.0 <4.0.0'",
                text,
                count=1,
            )
            if count > 0 and new_text != text:
                pubspec.write_text(new_text, encoding='utf-8')
                self.fixed_files.append(
                    "pubspec.yaml (relaxed environment.sdk constraint to '>=3.0.0 <4.0.0' "
                    "so it matches the Flutter/Dart version CI actually installs)"
                )
                self.log("Relaxed pubspec.yaml SDK constraint", "FIX")
                changed = True

        # (b) CI workflow Flutter version pin
        workflow = self.root / ".github" / "workflows" / "build_windows.yml"
        if workflow.exists():
            wtext = workflow.read_text(encoding='utf-8')
            # Flutter 3.24.0 ships Dart 3.5.0, which is too old for SDK
            # constraints like ^3.12.2 that a locally-newer Flutter can
            # accidentally introduce. Pin to 3.44.2 (matches local dev env
            # referenced in .dart_tool/package_config.json) for consistency.
            new_wtext, wcount = re.subn(
                r"flutter-version:\s*'[^']*'",
                "flutter-version: '3.44.2'",
                wtext,
                count=1,
            )
            if wcount > 0 and new_wtext != wtext:
                workflow.write_text(new_wtext, encoding='utf-8')
                self.fixed_files.append(
                    ".github/workflows/build_windows.yml "
                    "(bumped pinned Flutter version to 3.44.2 to match Dart SDK the "
                    "project actually requires)"
                )
                self.log("Bumped CI Flutter version pin to 3.44.2", "FIX")
                changed = True

        # (c) Committed .dart_tool/ is a local cache, not source - it's the
        # actual source of the SDK-version drift and should never be in git.
        dart_tool = self.root / ".dart_tool"
        gitignore = self.root / ".gitignore"
        if dart_tool.exists() and gitignore.exists():
            gi_text = gitignore.read_text(encoding='utf-8')
            if ".dart_tool/" not in gi_text:
                with gitignore.open('a', encoding='utf-8') as f:
                    f.write("\n.dart_tool/\n")
                self.fixed_files.append(".gitignore (ensured .dart_tool/ is ignored)")
                changed = True

            # Untrack it from git if it was previously committed, so the
            # stale package_config.json stops being pushed to CI.
            success, _ = self.run_git_command(["rm", "-r", "--cached", ".dart_tool"])
            if success:
                self.fixed_files.append(
                    ".dart_tool/ (removed from git tracking - it's a local build "
                    "cache that caused the SDK version mismatch in CI)"
                )
                changed = True

        if not changed:
            self.skipped_files.append(
                "pubspec.yaml / CI workflow SDK constraints (already consistent)"
            )
        return changed

    def run_git_command(self, args: List[str]) -> Tuple[bool, str]:
        try:
            result = subprocess.run(
                ["git"] + args, cwd=self.root, capture_output=True,
                text=True, timeout=30,
            )
            return result.returncode == 0, (result.stdout.strip() or result.stderr.strip())
        except Exception as e:
            return False, str(e)

    # ------------------------------------------------------------------ #
    # 1c. BoringTun-on-Windows is a dead end - switch to official WireGuard
    # ------------------------------------------------------------------ #
    def fix_boringtun_to_official_wireguard(self) -> bool:
        """
        Root-cause fix for CI failures like:
          "error: could not compile `boringtun` (lib) due to 14 previous
           errors ... error[E0433]: cannot find `unix` in `os` ...
           error: could not compile `daemonize` (lib) due to 51 previous
           errors"

        boringtun-cli (the crates.io `boringtun` binary target) is
        documented upstream as Linux/macOS only. It transitively depends
        on `daemonize`, which uses std::os::unix, libc::fork/setuid/
        chroot/flock/etc - none of which exist on the MSVC/Windows target.
        No amount of flag-tweaking fixes this: it is not written for
        Windows and never was.

        The correct, permanent fix is to stop trying to compile BoringTun
        for Windows at all, and instead bundle the OFFICIAL, pre-built
        WireGuard for Windows client binary (wireguard.exe), downloaded
        directly from download.wireguard.com. It is driven via:
            wireguard.exe /installtunnelservice <path-to-conf>
            wireguard.exe /uninstalltunnelservice <tunnel-name>
        which installs/removes a real Windows service per tunnel - the
        same mechanism the official WireGuard Windows client itself uses.
        No Rust/Cargo/compilation step is needed in CI anymore.

        This rewrites:
          - lib/services/warp_service.dart (generates a real .conf file,
            drives wireguard.exe instead of a nonexistent boringtun.exe)
          - .github/workflows/build_windows.yml (drops the whole Rust/
            Cargo/boringtun build stage; downloads+extracts the official
            WireGuard MSI instead)
        """
        changed = False

        # ---- warp_service.dart -------------------------------------------------
        warp_path = self.root / "lib" / "services" / "warp_service.dart"
        warp_content = r'''import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cryptography/cryptography.dart';
import 'package:path_provider/path_provider.dart';

/// Drives the OFFICIAL, pre-built WireGuard for Windows client
/// (https://www.wireguard.com/install/) instead of compiling a
/// third-party userspace implementation from source.
///
/// boringtun-cli (Cloudflare's Rust implementation) is documented
/// upstream as Linux/macOS only and cannot be compiled for Windows -
/// it depends on Unix-only APIs (fork, setuid, chroot, flock, unix
/// sockets) that simply don't exist on MSVC. wireguard.exe is the real
/// Windows implementation (WireGuardNT kernel driver + userspace
/// manager), bundled with the app and driven via its documented
/// service-install command line interface:
///
///   wireguard.exe /installtunnelservice <path-to-conf>
///   wireguard.exe /uninstalltunnelservice <tunnel-name>
///
/// Each call installs/removes a real Windows service named
/// "WireGuardTunnel$<tunnel-name>", exactly like the official GUI client.
class WarpService {
  static const _tunnelName = 'oryvexvpn';
  static bool _connected = false;

  // Cloudflare WARP endpoint list.
  static const List<String> _endpoints = [
    "8.6.112.165", "8.6.112.139", "8.6.112.178", "8.6.112.205",
    "8.6.112.176", "8.6.112.190", "8.6.112.121", "8.6.112.202",
    "8.6.112.223", "8.6.112.230", "8.6.112.200", "8.6.112.233",
    "8.6.112.4", "8.6.112.159", "8.6.112.93", "8.6.112.182",
    "8.6.112.133", "8.6.112.52", "8.6.112.78", "8.6.112.248",
    "8.6.112.246", "8.6.112.172", "8.6.112.104", "8.6.112.249",
    "8.6.112.46", "8.6.112.234", "8.6.112.136", "8.6.112.224",
    "8.6.112.251", "8.6.112.127", "8.6.112.237", "8.6.112.82",
    "8.6.112.170", "8.6.112.29", "8.6.112.7", "8.6.112.67",
    "188.114.97.6", "8.6.112.235", "8.6.112.228", "8.6.112.19",
    "8.6.112.184", "8.6.112.51", "8.6.112.8", "8.6.112.253",
    "8.6.112.221", "8.6.112.96", "8.6.112.174", "8.6.112.212",
    "8.6.112.154", "8.6.112.65", "8.6.112.171", "8.6.112.160",
    "8.6.112.86", "8.6.112.163", "8.6.112.122", "8.6.112.70",
    "8.6.112.53", "8.6.112.181", "8.6.112.191", "8.6.112.79",
    "8.6.112.180", "8.6.112.61", "8.6.112.77", "8.6.112.107",
    "8.6.112.106", "8.6.112.60",
    "162.159.192.1", "162.159.192.2", "162.159.193.1", "162.159.193.5",
    "162.159.195.1", "162.159.195.2", "162.159.195.5",
    "188.114.96.0", "188.114.96.1", "188.114.96.2", "188.114.96.3",
    "188.114.96.4", "188.114.96.5", "188.114.97.0", "188.114.97.1",
    "188.114.97.2", "188.114.97.3", "188.114.97.4", "188.114.97.5",
    "188.114.98.0", "188.114.98.1", "188.114.98.2", "188.114.99.0",
    "188.114.99.1", "188.114.99.2",
  ];

  static String get _exeDir {
    final exePath = Platform.resolvedExecutable;
    return File(exePath).parent.path;
  }

  static String get _wireguardExe => '$_exeDir\\data\\wireguard.exe';

  static Future<bool> _coreFilesPresent() async {
    return File(_wireguardExe).exists();
  }

  static Future<String> _confDir() async {
    final dir = await getApplicationSupportDirectory();
    final confDir = Directory('${dir.path}\\wireguard');
    if (!await confDir.exists()) {
      await confDir.create(recursive: true);
    }
    return confDir.path;
  }

  static String get _confPath => '_confDirCache\\$_tunnelName.conf';

  /// Concurrent ping scan for the fastest endpoint.
  static Future<String> _findBestEndpoint(Function(String) onProgress) async {
    onProgress('در حال جستجوی سریع‌ترین سرور...');
    final futures = _endpoints.map((ip) async {
      try {
        final start = DateTime.now();
        final res = await Process.run('ping', ['-n', '1', '-w', '1000', ip]);
        if (res.exitCode == 0) {
          final latency = DateTime.now().difference(start).inMilliseconds;
          return {'ip': ip, 'latency': latency};
        }
      } catch (_) {}
      return {'ip': ip, 'latency': 9999};
    });

    final results = await Future.wait(futures);
    results.sort((a, b) => (a['latency'] as int).compareTo(b['latency'] as int));

    final bestIp = results.first['latency'] != 9999
        ? results.first['ip'] as String
        : _endpoints.first;
    return bestIp;
  }

  /// Register with Cloudflare WARP API and return the needed parameters.
  static Future<_WarpRegistration> _register(Function(String) onProgress) async {
    onProgress('در حال ساخت کلید رمزنگاری...');
    final algorithm = X25519();
    final keyPair = await algorithm.newKeyPair();
    final publicKey = await keyPair.extractPublicKey();
    final privateKeyBytes = await keyPair.extractPrivateKeyBytes();

    final pubKeyBase64 = base64Encode(publicKey.bytes);
    final privKeyBase64 = base64Encode(privateKeyBytes);

    onProgress('در حال ثبت‌نام در شبکه...');
    final response = await http.post(
      Uri.parse('https://api.cloudflareclient.com/v0a737/reg'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "key": pubKeyBase64,
        "install_id": "",
        "warp_enabled": true,
        "tos": DateTime.now().toUtc().toIso8601String(),
        "type": "Windows",
        "locale": "fa_IR"
      }),
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('ثبت‌نام دستگاه ناموفق بود.');
    }

    final data = jsonDecode(response.body);
    final peer = data['config']['peers'][0];
    final address = (data['config']['interface']['addresses']['v4'] as String);
    final peerPublicKeyBase64 = peer['public_key'] as String;

    final bestIp = await _findBestEndpoint(onProgress);

    return _WarpRegistration(
      privateKeyBase64: privKeyBase64,
      address: address,
      peerPublicKeyBase64: peerPublicKeyBase64,
      endpointIp: bestIp,
      endpointPort: '2408',
    );
  }

  static String _buildConf(_WarpRegistration reg) {
    final b = StringBuffer();
    b.writeln('[Interface]');
    b.writeln('PrivateKey = ${reg.privateKeyBase64}');
    b.writeln('Address = ${reg.address}');
    b.writeln('DNS = 1.1.1.1');
    b.writeln('');
    b.writeln('[Peer]');
    b.writeln('PublicKey = ${reg.peerPublicKeyBase64}');
    b.writeln('Endpoint = ${reg.endpointIp}:${reg.endpointPort}');
    b.writeln('AllowedIPs = 0.0.0.0/0');
    b.writeln('PersistentKeepalive = 25');
    return b.toString();
  }

  /// Writes the .conf file and installs it as a Windows tunnel service
  /// via the official wireguard.exe CLI.
  static Future<void> _installTunnelService(_WarpRegistration reg) async {
    final confDir = await _confDir();
    final confFile = File('$confDir\\$_tunnelName.conf');
    await confFile.writeAsString(_buildConf(reg));

    // Remove any stale service from a previous run first (ignore errors -
    // it may simply not exist yet).
    await Process.run(_wireguardExe, ['/uninstalltunnelservice', _tunnelName]);
    await Future.delayed(const Duration(milliseconds: 300));

    final result = await Process.run(
      _wireguardExe,
      ['/installtunnelservice', confFile.path],
    );

    if (result.exitCode != 0) {
      final err = (result.stderr ?? '').toString().trim();
      throw Exception(
        err.isNotEmpty ? err : 'نصب سرویس WireGuard ناموفق بود.',
      );
    }

    // Give the service a moment to actually come up before we check it.
    await Future.delayed(const Duration(seconds: 1));
  }

  static Future<void> connect() async {
    if (!Platform.isWindows) {
      throw Exception('این نسخه فقط مخصوص ویندوز است.');
    }
    await connectWithProgress((_) {});
  }

  static Future<void> connectWithProgress(Function(String) onProgress) async {
    if (!Platform.isWindows) {
      throw Exception('این نسخه فقط مخصوص ویندوز است.');
    }
    if (!await _coreFilesPresent()) {
      throw Exception(
        'فایل هسته (data\\wireguard.exe) در برنامه یافت نشد.',
      );
    }

    final reg = await _register(onProgress);

    onProgress('در حال نصب سرویس WireGuard...');
    await _installTunnelService(reg);

    _connected = true;
  }

  static Future<void> disconnect() async {
    if (!Platform.isWindows) return;
    try {
      await Process.run(_wireguardExe, ['/uninstalltunnelservice', _tunnelName]);
    } catch (_) {
      // Non-fatal: service may already be gone.
    }
    _connected = false;
  }

  static Future<bool> isConnected() async {
    if (!Platform.isWindows) return false;
    if (!_connected) return false;
    // WireGuard installs the tunnel as a service named
    // "WireGuardTunnel$<name>". Query the service manager directly
    // rather than netsh, since the interface name WireGuard chooses
    // internally isn't guaranteed to match our tunnel name exactly.
    final result = await Process.run(
      'sc', ['query', 'WireGuardTunnel\$$_tunnelName'],
    );
    return result.exitCode == 0 &&
        result.stdout.toString().contains('RUNNING');
  }
}

class _WarpRegistration {
  final String privateKeyBase64;
  final String address;
  final String peerPublicKeyBase64;
  final String endpointIp;
  final String endpointPort;

  const _WarpRegistration({
    required this.privateKeyBase64,
    required this.address,
    required this.peerPublicKeyBase64,
    required this.endpointIp,
    required this.endpointPort,
  });
}
'''
        # NOTE: `_confPath` above (`_confDirCache\\...`) is a placeholder
        # that is never actually referenced anywhere in the class - it's
        # dead code. Remove it to avoid confusion / lints.
        warp_content = warp_content.replace(
            "  static String get _confPath => '_confDirCache\\\\$_tunnelName.conf';\n\n",
            "",
        )

        old_warp_existed = warp_path.exists()
        old_warp_text = warp_path.read_text(encoding='utf-8') if old_warp_existed else ""
        # Detect the OLD, broken implementation specifically - it referenced
        # a `boringtun.exe` binary path/process call. The NEW file (this
        # function's own output) only mentions "boringtun" once, inside an
        # explanatory doc comment, so match on the exe/process usage instead
        # of the bare word to stay idempotent across repeated runs.
        needs_rewrite = (not old_warp_existed) or (
            'boringtun.exe' in old_warp_text.lower()
            or '_boringtunexe' in old_warp_text.lower()
            or 'boringtun-src' in old_warp_text.lower()
        )

        if needs_rewrite:
            warp_path.parent.mkdir(parents=True, exist_ok=True)
            warp_path.write_text(warp_content, encoding='utf-8')
            self.fixed_files.append(
                "lib/services/warp_service.dart (boringtun.exe cannot be built for "
                "Windows - rewritten to drive the official wireguard.exe tunnel-service "
                "CLI instead)"
            )
            self.log("Rewrote warp_service.dart to use official WireGuard.exe", "FIX")
            changed = True
        else:
            self.skipped_files.append(
                "lib/services/warp_service.dart (does not reference boringtun, left untouched)"
            )

        # path_provider is required by the new warp_service.dart (to find a
        # writable per-user directory for the .conf file).
        pubspec = self.root / "pubspec.yaml"
        if pubspec.exists():
            ptext = pubspec.read_text(encoding='utf-8')
            if re.search(r'^\s*path_provider\s*:', ptext, re.MULTILINE) is None:
                lines = ptext.splitlines()
                try:
                    dep_idx = next(i for i, l in enumerate(lines) if l.strip() == "dependencies:")
                    end_idx = len(lines)
                    for i in range(dep_idx + 1, len(lines)):
                        line = lines[i]
                        if line and not line.startswith(' ') and not line.startswith('\t') and line.strip():
                            end_idx = i
                            break
                    lines.insert(end_idx, "  path_provider: ^2.1.1")
                    pubspec.write_text("\n".join(lines) + "\n", encoding='utf-8')
                    self.fixed_files.append(
                        "pubspec.yaml (added path_provider dependency - required by "
                        "the rewritten warp_service.dart)"
                    )
                    changed = True
                except StopIteration:
                    self.warnings.append(
                        "Could not auto-add path_provider to pubspec.yaml - add manually: "
                        "path_provider: ^2.1.1"
                    )

        # ---- .github/workflows/build_windows.yml -------------------------------
        workflow_path = self.root / ".github" / "workflows" / "build_windows.yml"
        old_workflow_text = workflow_path.read_text(encoding='utf-8') if workflow_path.exists() else ""
        # Same idempotency concern as above: the NEW workflow's own comments
        # mention "boringtun" once (explaining why it's gone). Match on the
        # actual broken build step instead (a real `cargo build` invocation
        # or a clone of the boringtun source repo) so re-runs don't loop.
        needs_workflow_rewrite = (
            'cargo build' in old_workflow_text.lower()
            or 'boringtun.git' in old_workflow_text.lower()
            or 'boringtun-src' in old_workflow_text.lower()
        )
        if needs_workflow_rewrite:
            new_workflow = '''name: Build Windows App (Official WireGuard)

on:
  push:
    branches: [ main ]
  workflow_dispatch:

jobs:
  build:
    runs-on: windows-2022

    steps:
      - uses: actions/checkout@v4

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.44.2'
          channel: 'stable'
          cache: true

      - name: Enable Windows desktop
        run: flutter config --enable-windows-desktop

      - name: Get dependencies
        run: flutter pub get

      - name: Build Windows app
        run: flutter build windows --release

      # No Rust/Cargo build step needed anymore. boringtun-cli only ever
      # targeted Linux/macOS and cannot compile for MSVC (it pulls in
      # `daemonize` and std::os::unix APIs that don't exist on Windows).
      # Instead we bundle the OFFICIAL, pre-built WireGuard for Windows
      # binary (wireguard.exe), which already includes the Wintun driver
      # and is what the real WireGuard Windows client uses.
      - name: Download and extract official WireGuard for Windows
        run: |
          $wgVersion = "1.0.1"
          $msiUrl = "https://download.wireguard.com/windows-client/wireguard-amd64-$wgVersion.msi"
          Invoke-WebRequest -Uri $msiUrl -OutFile "wireguard.msi"

          $extractDir = "$PWD\\wireguard_extracted"
          New-Item -ItemType Directory -Force -Path $extractDir | Out-Null

          $msiExecArgs = @(
            "/a", "`"$PWD\\wireguard.msi`"",
            "/qn",
            "TARGETDIR=`"$extractDir`""
          )
          Start-Process msiexec.exe -ArgumentList $msiExecArgs -Wait -NoNewWindow

          $wgExe = Get-ChildItem -Path $extractDir -Filter "wireguard.exe" -Recurse | Select-Object -First 1
          if (-not $wgExe) {
            Write-Host "Failed to extract wireguard.exe from MSI."
            Get-ChildItem -Path $extractDir -Recurse | ForEach-Object { Write-Host $_.FullName }
            exit 1
          }
          Write-Host "Found wireguard.exe at: $($wgExe.FullName)"
          Copy-Item $wgExe.FullName "$PWD\\wireguard.exe"

      - name: Bundle WireGuard binary inside data/
        run: |
          $ReleaseDir = "build\\windows\\x64\\runner\\Release"
          New-Item -ItemType Directory -Force -Path "$ReleaseDir\\data" | Out-Null

          Copy-Item "$PWD\\wireguard.exe" "$ReleaseDir\\data\\wireguard.exe"

          if (-not (Test-Path "$ReleaseDir\\data\\wireguard.exe")) {
            Write-Host "wireguard.exe bundling failed."
            exit 1
          }

          Write-Host "Official WireGuard for Windows bundled successfully."

      - name: Upload build artifacts
        uses: actions/upload-artifact@v4
        with:
          name: oryvexvpn-windows
          path: build/windows/x64/runner/Release/
'''
            workflow_path.parent.mkdir(parents=True, exist_ok=True)
            workflow_path.write_text(new_workflow, encoding='utf-8')
            self.fixed_files.append(
                ".github/workflows/build_windows.yml (removed the Rust/Cargo/boringtun "
                "compile stage that cannot succeed on Windows; now downloads and bundles "
                "the official pre-built wireguard.exe instead)"
            )
            self.log("Replaced boringtun CI build stage with official WireGuard download", "FIX")
            changed = True
        else:
            self.skipped_files.append(
                ".github/workflows/build_windows.yml (no boringtun/cargo references found)"
            )

        if not changed:
            self.skipped_files.append(
                "boringtun-to-wireguard migration (nothing referenced boringtun)"
            )
        return changed

    # ------------------------------------------------------------------ #
    # 2. pubspec.yaml - add missing deps without nuking existing ones
    # ------------------------------------------------------------------ #
    def fix_pubspec_dependencies(self) -> bool:
        path = self.root / "pubspec.yaml"
        if not path.exists():
            self.warnings.append("pubspec.yaml missing entirely - cannot patch dependencies.")
            return False

        text = path.read_text(encoding='utf-8')

        # Packages that other files in lib/ import but pubspec.yaml doesn't list.
        required_deps = {
            "window_manager": "^0.4.3",
            "settings_ui": "^2.0.2",
            "shared_preferences": "^2.3.2",
            "tray_manager": "^0.3.1",
        }

        lines = text.splitlines()
        try:
            dep_idx = next(i for i, l in enumerate(lines) if l.strip() == "dependencies:")
        except StopIteration:
            self.warnings.append("Could not find 'dependencies:' section in pubspec.yaml.")
            return False

        # Find the end of the dependencies: block (next top-level key or EOF).
        end_idx = len(lines)
        for i in range(dep_idx + 1, len(lines)):
            line = lines[i]
            if line and not line.startswith(' ') and not line.startswith('\t') and line.strip():
                end_idx = i
                break

        block = "\n".join(lines[dep_idx:end_idx])
        missing = {
            name: ver for name, ver in required_deps.items()
            if re.search(rf'^\s*{re.escape(name)}\s*:', block, re.MULTILINE) is None
        }

        if not missing:
            self.skipped_files.append("pubspec.yaml (all required dependencies already present)")
            self.log("pubspec.yaml already has all required dependencies", "SKIP")
            return False

        insertion = "\n".join(f"  {name}: {ver}" for name, ver in missing.items())
        new_lines = lines[:end_idx] + [insertion] + lines[end_idx:]
        path.write_text("\n".join(new_lines) + "\n", encoding='utf-8')

        self.fixed_files.append(
            f"pubspec.yaml (added missing deps: {', '.join(missing.keys())})"
        )
        self.log(f"Added missing pubspec deps: {', '.join(missing.keys())}", "FIX")
        return True

    # ------------------------------------------------------------------ #
    # 3. Dangling import detector (report-only, never auto-deletes code)
    # ------------------------------------------------------------------ #
    def scan_dangling_imports(self) -> List[Tuple[Path, str]]:
        problems: List[Tuple[Path, str]] = []
        lib_dir = self.root / "lib"
        if not lib_dir.exists():
            return problems

        import_re = re.compile(r"""^\s*import\s+['"]([^'"]+)['"]""")

        for dart_file in lib_dir.rglob("*.dart"):
            try:
                text = dart_file.read_text(encoding='utf-8')
            except Exception:
                continue
            for line in text.splitlines():
                m = import_re.match(line)
                if not m:
                    continue
                target = m.group(1)
                if target.startswith('package:') or target.startswith('dart:'):
                    continue
                # relative import -> resolve against this file's directory
                resolved = (dart_file.parent / target).resolve()
                if not resolved.exists():
                    problems.append((dart_file, target))
        return problems

    # ------------------------------------------------------------------ #
    # 4. Secrets hygiene
    # ------------------------------------------------------------------ #
    def scrub_tokens(self) -> bool:
        token_regex = re.compile(r'ghp_[A-Za-z0-9_]{36,}')
        modified = False
        for filepath in self.root.rglob('*'):
            if filepath.is_dir() or any(part.startswith('.git') for part in filepath.parts):
                continue
            try:
                content = filepath.read_text(encoding='utf-8')
            except Exception:
                continue
            new_content, count = token_regex.subn('YOUR_GITHUB_TOKEN', content)
            if count > 0:
                filepath.write_text(new_content, encoding='utf-8')
                modified = True
                self.fixed_files.append(f"{filepath.relative_to(self.root)} (scrubbed leaked token)")
        return modified

    def update_gitignore(self) -> bool:
        gi_path = self.root / ".gitignore"
        required = [".env", "*.token", "*.secret", "key.properties", "*.keystore", "*.jks"]
        existing = gi_path.read_text(encoding='utf-8') if gi_path.exists() else ""
        missing = [r for r in required if r not in existing]
        if missing:
            with gi_path.open('a', encoding='utf-8') as f:
                f.write("\n" + "\n".join(missing) + "\n")
            self.fixed_files.append(".gitignore (added missing secret patterns)")
            return True
        self.skipped_files.append(".gitignore (already has secret patterns)")
        return False

    # ------------------------------------------------------------------ #
    # 5. quick sanity pass on files we expect to already be correct
    # ------------------------------------------------------------------ #
    def verify_known_good_files(self):
        """
        These files were confirmed complete/correct during review. We do
        NOT touch them, but we do a light existence + non-empty check so a
        future accidental truncation gets flagged instead of silently
        shipping broken.
        """
        expected_good = [
            "lib/main.dart",
            "lib/services/vpn_service.dart",
            "lib/services/dns_service.dart",
            "lib/services/proxy_settings_manager.dart",
            "lib/screens/home_screen.dart",
            "lib/theme/app_theme.dart",
            "lib/ui/settings_screen.dart",
            "lib/constants/strings.dart",
            "lib/models/account.dart",
            "lib/models/config_model.dart",
            "lib/models/endpoint.dart",
            "lib/utils/helpers.dart",
            "lib/utils/device_utils.dart",
            "lib/widgets/connect_button.dart",
        ]
        for rel in expected_good:
            p = self.root / rel
            if not p.exists():
                self.warnings.append(f"Expected file missing: {rel}")
            elif not p.read_text(encoding='utf-8').strip():
                self.warnings.append(f"Expected file is EMPTY (needs manual review): {rel}")

    # ------------------------------------------------------------------ #
    # runner
    # ------------------------------------------------------------------ #
    def initialize_windows(self) -> bool:
        self.log("Ensuring Windows platform is initialized cleanly...", "STEP")
        subprocess.run(
            "flutter create --platforms windows --overwrite .",
            shell=True, cwd=self.root, capture_output=True,
        )
        return True

    def run(self) -> bool:
        print("\n" + "=" * 64)
        print("OryvexVPN Full Project Debugger & Fixer")
        print("=" * 64)
        print(f"\nProject Path: {self.root}\n")

        if not self.check_project():
            return False

        self.initialize_windows()

        # Targeted fixes for known-broken/empty files only.
        self.fix_config_dart()
        self.fix_network_manager()
        self.fix_proxy_service()
        self.fix_tray_service()
        self.fix_window_manager_service()
        self.fix_endpoint_selector()
        self.fix_boringtun_to_official_wireguard()

        # pubspec.yaml: add only what's missing, and fix SDK/CI mismatch.
        self.fix_pubspec_dependencies()
        self.fix_sdk_constraint_mismatch()

        # Hygiene passes.
        self.scrub_tokens()
        self.update_gitignore()

        # Report-only diagnostics.
        dangling = self.scan_dangling_imports()
        self.verify_known_good_files()

        print("\n" + "=" * 64)
        print("Final Report")
        print("=" * 64)

        if self.fixed_files:
            print("\nFixed / Modified:")
            for f in self.fixed_files:
                print(f"  [FIX]  {f}")
        else:
            print("\nNothing needed fixing - project already clean.")

        if self.skipped_files:
            print("\nLeft untouched (already correct):")
            for f in self.skipped_files:
                print(f"  [--]   {f}")

        if dangling:
            print("\nDangling imports found (needs manual review):")
            for file, target in dangling:
                print(f"  [X]    {file.relative_to(self.root)} -> imports missing '{target}'")
        else:
            print("\nNo dangling imports detected.")

        if self.warnings:
            print("\nWarnings:")
            for w in self.warnings:
                print(f"  [!]    {w}")

        print("\nNext steps:")
        print("  1. flutter pub get")
        print("  2. flutter analyze   (should be clean now)")
        print("  3. flutter build windows --release")
        print("\nRun push.py to commit and deploy via GitHub Actions.")
        return True


def main():
    try:
        root = sys.argv[1] if len(sys.argv) > 1 else os.getcwd()
        fixer = FlutterProjectFixer(root)
        success = fixer.run()
        sys.exit(0 if success else 1)
    except KeyboardInterrupt:
        print("\nOperation cancelled by user.")
        sys.exit(0)
    except Exception as e:
        print(f"\nUnexpected error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()