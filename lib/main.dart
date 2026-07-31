import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:warp_vpn_app/screens/home_screen.dart';
import 'package:warp_vpn_app/services/vpn_service.dart';
import 'package:warp_vpn_app/constants/strings.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (_) => VPNService(),
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      title: Strings.appTitle,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        primaryColor: const Color(0xFF10B981),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF10B981), 
          secondary: Color(0xFF10B981)
        ),
        fontFamily: 'Vazirmatn',
        cardTheme: CardTheme(
          color: const Color(0xFF1A1A1A), 
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), 
          elevation: 0
        ),
      ),
      locale: const Locale('fa', 'IR'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate, 
        GlobalWidgetsLocalizations.delegate, 
        GlobalCupertinoLocalizations.delegate
      ],
      supportedLocales: const [Locale('fa', 'IR'), Locale('en', 'US')],
      home: const HomeScreen(),
    ),
  );
}
