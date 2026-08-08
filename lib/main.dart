import 'l10n/locale_provider.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'core/config.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'services/network_manager.dart';
import 'services/oryvex_service.dart';
import 'services/system_proxy.dart';
import 'services/tray_service.dart';
import 'services/window_manager_service.dart';
import 'services/vpn_core.dart';
import 'services/vpn_service.dart';
import 'services/xray_service.dart';
import 'l10n/app_localizations.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await WindowManagerService.init();
  await NetworkManager.instance.start();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => VPNService()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
      ],
      child: const OryvexVPNApp(),
    ),
  );
}

class OryvexVPNApp extends StatefulWidget {
  const OryvexVPNApp({super.key});

  @override
  State<OryvexVPNApp> createState() => _OryvexVPNAppState();
}

class _OryvexVPNAppState extends State<OryvexVPNApp> with WindowListener {
  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final tray = TrayService.instance;
      tray.onConnectRequested = () => navigatorKey.currentContext!.read<VPNService>().connect();
      tray.onDisconnectRequested = () => navigatorKey.currentContext!.read<VPNService>().disconnect();
      tray.onQuitRequested = () => _performQuit();
      tray.init();
    });
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    TrayService.instance.dispose();
    NetworkManager.instance.dispose();
    super.dispose();
  }

  Future<void> _performQuit() async {
    VpnLogger.info('Main', '=== QUIT START ===');

    // 1) Cleanly disconnect if we're mid-session (this also restores the
    //    proxy state captured by saveState, if any).
    try {
      final context = navigatorKey.currentContext;
      if (context != null) {
        final vpnService = context.read<VPNService>();
        if (vpnService.isConnected || vpnService.isConnecting) {
          VpnLogger.info('Main', 'Disconnecting VPN before closing...');
          await vpnService.disconnect().timeout(
            const Duration(seconds: 8),
            onTimeout: () {
              VpnLogger.warn('Main', 'VPN disconnect timeout');
            },
          );
        }
      }
    } catch (e) {
      VpnLogger.error('Main', 'Error during VPN service disconnect: $e');
    }

    // 2) Stop our core processes.
    try {
      VpnLogger.info('Main', 'Stopping Xray service...');
      await XrayService.stop().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          VpnLogger.warn('Main', 'Xray stop timeout');
        },
      );
    } catch (e) {
      VpnLogger.error('Main', 'Xray stop error: $e');
    }

    try {
      VpnLogger.info('Main', 'Stopping oryvex core...');
      await OryvexService.killRunning().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          VpnLogger.warn('Main', 'Oryvex stop timeout');
        },
      );
    } catch (e) {
      VpnLogger.error('Main', 'Oryvex stop error: $e');
    }

    // 3) Comprehensive cleanup — ALWAYS runs, even when we weren't connected,
    //    so leftovers (tunnel service, adapter, processes) from a crashed or
    //    previous session are fully removed.
    try {
      VpnLogger.info('Main', 'Running comprehensive VpnCore cleanup...');
      await VpnCore.comprehensiveCleanup().timeout(
        const Duration(seconds: 12),
        onTimeout: () {
          VpnLogger.warn('Main', 'VpnCore cleanup timeout');
        },
      );
    } catch (e) {
      VpnLogger.error('Main', 'VpnCore cleanup error: $e');
    }

    // 4) Unconditionally reset the system proxy to default. This covers the
    //    "app started with a stale Xray proxy left by a previous run" case
    //    that a plain restore() would miss.
    try {
      VpnLogger.info('Main', 'Resetting system proxy to default...');
      await SystemProxyService.resetToDefault().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          VpnLogger.warn('Main', 'Proxy reset timeout');
        },
      );
    } catch (e) {
      VpnLogger.error('Main', 'Proxy reset error: $e');
    }

    VpnLogger.info('Main', 'Force killing remaining processes...');
    final procs = ['amneziawg.exe', 'awg.exe', 'wireservice.exe', 'oryvex.exe', 'xray.exe'];
    for (final proc in procs) {
      try {
        final r = Process.runSync('taskkill', ['/F', '/IM', proc], runInShell: true);
        if (r.exitCode == 0) {
          VpnLogger.info('Main', 'Killed $proc');
        }
      } catch (_) {}
    }

    try {
      NetworkManager.instance.dispose();
      VpnLogger.info('Main', 'NetworkManager disposed');
    } catch (_) {}

    try {
      TrayService.instance.dispose();
      VpnLogger.info('Main', 'TrayService disposed');
    } catch (_) {}

    VpnLogger.info('Main', 'Destroying window and exiting...');
    windowManager.destroy();
    exit(0);
  }

  @override
  void onWindowClose() async {
    final context = navigatorKey.currentContext;
    if (context != null) {
      final l10n = AppLocalizations.of(context);
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.surfaceOverlay,
          title: Text(l10n.closeTitle, style: const TextStyle(color: Colors.white)),
          content: Text(
            l10n.closeMessage,
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                windowManager.hide();
              },
              child: Text(l10n.closeBackground, style: TextStyle(color: AppTheme.primary)),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _performQuit();
              },
              child: Text(l10n.closeExit, style: TextStyle(color: AppTheme.error)),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
              },
              child: Text(l10n.cancel, style: TextStyle(color: AppTheme.textMuted)),
            ),
          ],
        ),
      );
    } else {
      await _performQuit();
    }
  }

  @override
  Widget build(BuildContext context) {
    final localeProvider = context.watch<LocaleProvider>();

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      locale: localeProvider.locale,
      supportedLocales: const [
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.ltr,
          child: child!,
        );
      },
      theme: AppTheme.darkTheme,
      home: const HomeScreen(),
    );
  }

}
