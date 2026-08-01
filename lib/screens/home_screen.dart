import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import '../services/vpn_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VPNService>().initStatus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final vpn = context.watch<VPNService>();

    // رنگ فیروزه‌ای (Neon Cyan) مشابه تصویر
    Color getStatusColor() {
      if (vpn.isConnected) return const Color(0xFF00E5FF); 
      if (vpn.isConnecting) return const Color(0xFF00E5FF).withOpacity(0.7); 
      if (vpn.stage == VpnStage.error) return const Color(0xFFFF3366); 
      return const Color(0xFF333333); // رنگ حالت خاموش
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F), 
      body: Column(
        children: [
          // Header (Title & Controls)
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onPanStart: (details) => windowManager.startDragging(),
            child: Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // سمت راست (چون RTL است، اولین آیتم‌ها سمت راست قرار می‌گیرند)
                  Row(
                    children: [
                      const Text(
                        'اورایوکس',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        vpn.isConnected ? Icons.shield_rounded : Icons.shield_outlined,
                        color: const Color(0xFF00E5FF),
                        size: 24,
                      ),
                    ],
                  ),
                  // سمت چپ (دکمه‌های کنترل)
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.minimize, color: Colors.white54, size: 20),
                        onPressed: () => windowManager.minimize(),
                        hoverColor: Colors.white10,
                        splashRadius: 20,
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                        onPressed: () => windowManager.close(), // ارسال تریگر به onWindowClose
                        hoverColor: Colors.redAccent.withOpacity(0.5),
                        splashRadius: 20,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    vpn.statusMessage,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: getStatusColor(),
                    ),
                  ),
                  const SizedBox(height: 40),
                  
                  // Main Connect Button (Neon Outline)
                  GestureDetector(
                    onTap: vpn.isConnecting
                        ? null
                        : () => vpn.isConnected ? vpn.disconnect() : vpn.connect(),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 170,
                      height: 170,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF141414),
                        boxShadow: [
                          BoxShadow(
                            color: getStatusColor().withOpacity(vpn.isConnected || vpn.isConnecting ? 0.15 : 0.0),
                            blurRadius: 50,
                            spreadRadius: 10,
                          ),
                        ],
                        border: Border.all(
                          color: getStatusColor().withOpacity(vpn.isConnected ? 1.0 : 0.4),
                          width: vpn.isConnected ? 3 : 2,
                        ),
                      ),
                      child: Center(
                        child: vpn.isConnecting
                            ? const SizedBox(
                                width: 50,
                                height: 50,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  color: Color(0xFF00E5FF),
                                ),
                              )
                            : Icon(
                                Icons.power_settings_new_rounded,
                                size: 65,
                                color: getStatusColor(),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
