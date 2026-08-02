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
    bool isDisconnecting = false;
    final context = navigatorKey.currentContext;

    try {
      if (context != null) {
        final vpnService = context.read<VPNService>();
        if (vpnService.isConnected || vpnService.isConnecting) {
          isDisconnecting = true;
          print('Disconnecting VPN before closing...');
          await vpnService.disconnect().timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              print('VPN disconnect timeout, forcing close');
            },
          );
        }
      }
    } catch (e) {
      print('Error during VPN cleanup: $e');
    }

    try {
      if (!isDisconnecting) {
        await WireGuardService.disconnect().timeout(
          const Duration(seconds: 4),
          onTimeout: () {},
        );
      }
    } catch (_) {}

    try {
      NetworkManager.instance.dispose();
    } catch (_) {}

    try {
      TrayService.instance.dispose();
    } catch (_) {}

    try {
      // Force kill any lingering amneziawg processes to ensure a clean exit
      Process.runSync('taskkill', ['/F', '/IM', 'amneziawg.exe'], runInShell: true);
      Process.runSync('taskkill', ['/F', '/IM', 'awg.exe'], runInShell: true);
    } catch (_) {}

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
