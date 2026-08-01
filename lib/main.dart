import 'package:flutter/material.dart';
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
      TrayService.instance.init();
    });
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    TrayService.instance.dispose();
    NetworkManager.instance.dispose();
    super.dispose();
  }

  // جلوگیری از خطای Not Responding با متوقف کردن فوری سرویس به صورت Static
  @override
  void onWindowClose() async {
    try {
      await WarpService.disconnect();
    } catch (_) {}
    await windowManager.destroy(); // خروج قطعی
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
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
      ),
      home: const HomeScreen(),
    );
  }
}
