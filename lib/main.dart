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
import 'services/warp_service.dart';
import 'l10n/app_localizations.dart';

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
      tray.onConnectRequested = () => context.read<VPNService>().connect();
      tray.onDisconnectRequested = () => context.read<VPNService>().disconnect();
      tray.onQuitRequested = () => WindowManagerService.quit();
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

  @override
  void onWindowClose() async {
    bool isDisconnecting = false;

    try {
      // Get VPN service
      final vpnService = context.read<VPNService>();

      // Only try to disconnect if connected
      if (vpnService.isConnected || vpnService.isConnecting) {
        isDisconnecting = true;
        print('Disconnecting VPN before closing...');

        // Try to disconnect with timeout
        await vpnService.disconnect().timeout(
          const Duration(seconds: 2),
          onTimeout: () {
            print('VPN disconnect timeout, forcing close');
          },
        );
      }
    } catch (e) {
      print('Error during VPN cleanup: $e');
    }

    try {
      // Force cleanup WarpService
      if (!isDisconnecting) {
        await WarpService.disconnect().timeout(
          const Duration(seconds: 1),
          onTimeout: () {},
        );
      }
    } catch (_) {}

    try {
      // Stop network manager
      NetworkManager.instance.dispose();
    } catch (_) {}

    try {
      // Cleanup tray
      TrayService.instance.dispose();
    } catch (_) {}

    // destroy() is required because setPreventClose(true) blocks a normal
    // close. Do NOT await it - we want the window gone immediately.
    windowManager.destroy();

    // The Dart VM keeps running after the window is destroyed (the tray /
    // event loop stay alive), which leaves a frozen/zombie process behind.
    // Terminate it explicitly so closing the app actually quits.
    exit(0);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
