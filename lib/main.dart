import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
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
      // Wire the tray menu actions so Connect/Disconnect/Quit actually work.
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

    // Step 1: Try graceful VPN disconnect through VPNService
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

    // Step 2: Force cleanup via VpnCore if VPNService disconnect didn't work
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

    // Step 3: Also try WireGuardService disconnect as fallback
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

    // Step 4: Force kill ALL remaining processes (nuclear option)
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

    // Step 5: Dispose services
    try {
      NetworkManager.instance.dispose();
      VpnLogger.info('Main', 'NetworkManager disposed');
    } catch (_) {}

    try {
      TrayService.instance.dispose();
      VpnLogger.info('Main', 'TrayService disposed');
    } catch (_) {}

    // Step 6: Destroy window and exit
    VpnLogger.info('Main', 'Destroying window and exiting...');
    windowManager.destroy();
    exit(0);
  }

  @override
  void onWindowClose() async {
    final context = navigatorKey.currentContext;
    if (context != null) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF141414),
          title: const Text('بستن برنامه', style: TextStyle(color: Colors.white)),
          content: const Text(
            'آیا می‌خواهید برنامه به طور کامل بسته شود یا در پس‌زمینه (سینی سیستم) فعال بماند؟',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                windowManager.hide();
              },
              child: const Text('پنهان در پس‌زمینه', style: TextStyle(color: Color(0xFF00E5FF))),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _performQuit();
              },
              child: const Text('خروج کامل', style: TextStyle(color: Color(0xFFFF3366))),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
              },
              child: const Text('لغو', style: TextStyle(color: Colors.white54)),
            ),
          ],
        ),
      );
    } else {
      // Fallback
      await _performQuit();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      locale: const Locale('fa', 'IR'),
      supportedLocales: const [
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
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        fontFamily: GoogleFonts.vazirmatn().fontFamily,
        textTheme: GoogleFonts.vazirmatnTextTheme(ThemeData.dark().textTheme),
        useMaterial3: true,
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF00E5FF),
          secondary: const Color(0xFF00FFCC),
          error: const Color(0xFFFF3366),
          background: const Color(0xFF0A0A0A),
          surface: const Color(0xFF141414),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
