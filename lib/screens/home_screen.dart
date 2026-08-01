import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/vpn_service.dart';
import 'settings_dialog.dart';

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
      context.read<VPNService>().loadSettings();
    });
  }

  @override
  Widget build(BuildContext context) {
    final vpn = context.watch<VPNService>();

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0D0D12), Color(0xFF15151C)],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            vpn.isConnected ? Icons.shield_rounded : Icons.shield_outlined,
                            color: vpn.isConnected ? const Color(0xFF00E5FF) : Colors.white54,
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'OryvexVPN',
                            style: TextStyle(
                              fontFamily: 'Vazirmatn',
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.settings_rounded, color: Colors.white70),
                        onPressed: () => showDialog(
                          context: context,
                          builder: (_) => const SettingsDialog(),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                Text(
                  vpn.statusMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Vazirmatn',
                    fontSize: 16,
                    color: vpn.isConnected
                        ? const Color(0xFF00E5FF)
                        : (vpn.stage == VpnStage.error ? Colors.redAccent : Colors.white54),
                  ),
                ),
                if (vpn.lastError != null) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      vpn.lastError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Vazirmatn',
                        fontSize: 12,
                        color: Colors.redAccent,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 40),

                // دکمه اتصال / لودر واقعی مرحله‌به‌مرحله
                GestureDetector(
                  onTap: vpn.isConnecting
                      ? null
                      : () => vpn.isConnected ? vpn.disconnect() : vpn.connect(),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF1A1A22),
                      boxShadow: [
                        BoxShadow(
                          color: vpn.isConnected
                              ? const Color(0xFF00E5FF).withOpacity(0.35)
                              : (vpn.isConnecting
                                  ? Colors.orangeAccent.withOpacity(0.3)
                                  : Colors.black26),
                          blurRadius: vpn.isConnected || vpn.isConnecting ? 50 : 15,
                          spreadRadius: vpn.isConnected || vpn.isConnecting ? 5 : 0,
                        ),
                      ],
                      border: Border.all(
                        color: vpn.isConnected
                            ? const Color(0xFF00E5FF)
                            : (vpn.isConnecting ? Colors.orangeAccent : Colors.white12),
                        width: vpn.isConnected ? 4 : 2,
                      ),
                    ),
                    child: Center(
                      child: vpn.isConnecting
                          ? const SizedBox(
                              width: 46,
                              height: 46,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                color: Colors.orangeAccent,
                              ),
                            )
                          : Icon(
                              Icons.power_settings_new_rounded,
                              size: 70,
                              color: vpn.isConnected ? const Color(0xFF00E5FF) : Colors.white30,
                            ),
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                Expanded(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 400),
                    opacity: vpn.isConnected ? 1.0 : 0.0,
                    child: vpn.isConnected
                        ? Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A1A22),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.dns_rounded, color: Color(0xFF00E5FF), size: 18),
                                      SizedBox(width: 8),
                                      Text(
                                        'تانل WireGuard فعال است',
                                        style: TextStyle(
                                          fontFamily: 'Vazirmatn',
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          )
                        : const SizedBox(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
