import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/vpn_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

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
      if (vpn.isConnecting) return const Color(0xFFFF9800);
      if (vpn.stage == VpnStage.error) return const Color(0xFFFF3B30);
      return Colors.white54;
    }

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF09090B), Color(0xFF18181B)],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  child: Row(
                    children: [
                      Icon(
                        vpn.isConnected ? Icons.shield_rounded : Icons.shield_outlined,
                        color: getStatusColor(),
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'اورایوکس',
                        style: TextStyle(
                          fontFamily: 'Vazirmatn',
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const Spacer(flex: 1),
                
                // Status Text
                Text(
                  vpn.statusMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Vazirmatn',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: getStatusColor(),
                  ),
                ),
                if (vpn.lastError != null) ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF3B30).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFF3B30).withOpacity(0.3)),
                      ),
                      child: Text(
                        vpn.lastError!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Vazirmatn',
                          fontSize: 13,
                          height: 1.5,
                          color: Color(0xFFFF3B30),
                        ),
                      ),
                    ),
                  ),
                ],
                
                const SizedBox(height: 50),

                // Main Connect Button
                GestureDetector(
                  onTap: vpn.isConnecting
                      ? null
                      : () => vpn.isConnected ? vpn.disconnect() : vpn.connect(),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF18181B),
                      boxShadow: [
                        BoxShadow(
                          color: getStatusColor().withOpacity(vpn.isConnected || vpn.isConnecting ? 0.4 : 0.0),
                          blurRadius: vpn.isConnected || vpn.isConnecting ? 60 : 20,
                          spreadRadius: vpn.isConnected || vpn.isConnecting ? 10 : 0,
                        ),
                      ],
                      border: Border.all(
                        color: getStatusColor().withOpacity(vpn.isConnected ? 1.0 : (vpn.isConnecting ? 0.8 : 0.1)),
                        width: vpn.isConnected ? 6 : 2,
                      ),
                    ),
                    child: Center(
                      child: vpn.isConnecting
                          ? const SizedBox(
                              width: 60,
                              height: 60,
                              child: CircularProgressIndicator(
                                strokeWidth: 4,
                                color: Color(0xFFFF9800),
                              ),
                            )
                          : Icon(
                              Icons.power_settings_new_rounded,
                              size: 90,
                              color: getStatusColor(),
                            ),
                    ),
                  ),
                ),

                const Spacer(flex: 2),

                // Bottom Status Card
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 400),
                  opacity: vpn.isConnected ? 1.0 : 0.0,
                  child: vpn.isConnected
                      ? Padding(
                          padding: const EdgeInsets.only(bottom: 40, left: 24, right: 24),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
                            decoration: BoxDecoration(
                              color: const Color(0xFF18181B),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.3)),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.security_rounded, color: Color(0xFF00E5FF), size: 22),
                                SizedBox(width: 12),
                                Text(
                                  'تونل وایرگارد فعال و ایمن است',
                                  style: TextStyle(
                                    fontFamily: 'Vazirmatn',
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : const SizedBox(height: 98),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
