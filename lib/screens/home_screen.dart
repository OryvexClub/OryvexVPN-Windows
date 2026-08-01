import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import '../services/vpn_service.dart';
import '../services/window_manager_service.dart';

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

    Color getStatusColor() {
      if (vpn.isConnected) return const Color(0xFF00E5FF); 
      if (vpn.isConnecting) return const Color(0xFF00FFCC); 
      if (vpn.stage == VpnStage.error) return const Color(0xFFFF3366); 
      return const Color(0xFF555555);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A), 
      body: Column(
        children: [
          // Header Draggable + Window Controls
          Container(
            height: 50,
            color: Colors.transparent,
            child: Row(
              children: [
                const SizedBox(width: 16),
                Icon(
                  vpn.isConnected ? Icons.shield_rounded : Icons.shield_outlined,
                  color: getStatusColor(),
                  size: 22,
                ),
                const SizedBox(width: 8),
                const Text(
                  'اورایوکس',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onPanStart: (details) => windowManager.startDragging(),
                    child: const SizedBox(height: double.infinity),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.minimize, color: Colors.white54, size: 20),
                  onPressed: () => windowManager.minimize(),
                  hoverColor: Colors.white10,
                  splashRadius: 20,
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                  onPressed: () => WindowManagerService.quit(),
                  hoverColor: Colors.redAccent.withOpacity(0.5),
                  splashRadius: 20,
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
          
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    vpn.statusMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: getStatusColor(),
                    ),
                  ),
                  if (vpn.lastError != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 32),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF3366).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFF3366).withOpacity(0.3)),
                      ),
                      child: Text(
                        vpn.lastError!,
                        textAlign: TextAlign.left,
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFFF3366),
                          fontFamily: 'Consolas',
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 50),
                  
                  // Neon Cyan Connect Button
                  GestureDetector(
                    onTap: vpn.isConnecting
                        ? null
                        : () => vpn.isConnected ? vpn.disconnect() : vpn.connect(),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF141414),
                        boxShadow: [
                          BoxShadow(
                            color: getStatusColor().withOpacity(vpn.isConnected || vpn.isConnecting ? 0.2 : 0.0),
                            blurRadius: 40,
                            spreadRadius: vpn.isConnected || vpn.isConnecting ? 5 : 0,
                          ),
                        ],
                        border: Border.all(
                          color: getStatusColor().withOpacity(vpn.isConnected ? 0.8 : 0.3),
                          width: vpn.isConnected ? 3 : 1.5,
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
                                size: 60,
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
