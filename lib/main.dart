import 'l10n/locale_provider.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'core/config.dart';
import 'screens/home_screen.dart';
import 'services/network_manager.dart';
import 'services/tray_service.dart';
import 'services/window_manager_service.dart';
import 'services/vpn_core.dart';
import 'services/vpn_service.dart';
import 'services/wireguard_service.dart';
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
    bool isDisconnecting = false;
    final context = navigatorKey.currentContext;

    try {
      if (context != null) {
        final vpnService = context.read<VPNService>();
        if (vpnService.isConnected || vpnService.isConnecting) {
          isDisconnecting = true;
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

    try {
      VpnLogger.info('Main', 'Running full VpnCore cleanup...');
      await VpnCore.fullCleanup().timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          VpnLogger.warn('Main', 'VpnCore cleanup timeout');
        },
      );
    } catch (e) {
      VpnLogger.error('Main', 'VpnCore cleanup error: $e');
    }

    try {
      if (!isDisconnecting) {
        await WireGuardService.disconnect().timeout(
          const Duration(seconds: 5),
          onTimeout: () {},
        );
      }
    } catch (e) {
      VpnLogger.error('Main', 'WireGuardService disconnect error: $e');
    }

    VpnLogger.info('Main', 'Force killing remaining processes...');
    final procs = ['amneziawg.exe', 'awg.exe', 'wireservice.exe'];
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
          backgroundColor: const Color(0xFF0A0A0A),
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
              child: Text(l10n.closeBackground, style: const TextStyle(color: Color(0xFF00E676))),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _performQuit();
              },
              child: Text(l10n.closeExit, style: const TextStyle(color: Color(0xFFFF3366))),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
              },
              child: Text(l10n.cancel, style: const TextStyle(color: Colors.white54)),
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
    final isFa = localeProvider.locale.languageCode == 'fa';
    
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      locale: localeProvider.locale,
      supportedLocales: const [
        Locale('en', 'US'),
        Locale('fa', 'IR'),
      ],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        return Directionality(
          textDirection: isFa ? TextDirection.rtl : TextDirection.ltr,
          child: child!,
        );
      },
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF000000),
        fontFamily: isFa ? 'Vazirmatn' : 'Inter',
        useMaterial3: true,
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF00E676),
          secondary: const Color(0xFF69F0AE),
          error: const Color(0xFFFF3366),
          surface: const Color(0xFF0A0A0A),
        ),
      ),
      home: const HomeScreen(),
    );
  }

}
