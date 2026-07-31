import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/vpn_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final vpn = Provider.of<VPNService>(context);

    return Scaffold(
      body: Stack(
        children: [
          // Background UI
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF0F0F13), Color(0xFF13131A)],
                ),
              ),
            ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                // Top Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Icon(Icons.menu_rounded, color: Colors.white70, size: 28),
                      Row(
                        children: [
                          Icon(
                            vpn.isConnected ? Icons.shield_rounded : Icons.shield_outlined, 
                            color: vpn.isConnected ? const Color(0xFF00E5FF) : Colors.white54
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Oryvex',
                            style: TextStyle(
                              fontSize: 20, 
                              fontWeight: FontWeight.bold,
                              color: vpn.isConnected ? const Color(0xFF00E5FF) : Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const Icon(Icons.settings_rounded, color: Colors.white70, size: 28),
                    ],
                  ),
                ),

                const Spacer(),

                // Status Text
                Text(
                  vpn.statusMessage.toUpperCase(),
                  style: TextStyle(
                    fontSize: 18,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w600,
                    color: vpn.isConnected ? const Color(0xFF00E5FF) : Colors.white54,
                  ),
                ),
                const SizedBox(height: 40),

                // Main Connect Button
                GestureDetector(
                  onTap: () => vpn.isConnecting ? null : (vpn.isConnected ? vpn.disconnect() : vpn.connect()),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF1C1C22),
                      boxShadow: [
                        BoxShadow(
                          color: vpn.isConnected 
                              ? const Color(0xFF00E5FF).withOpacity(0.3)
                              : (vpn.isConnecting ? Colors.orange.withOpacity(0.3) : Colors.black26),
                          blurRadius: vpn.isConnected || vpn.isConnecting ? 60 : 20,
                          spreadRadius: vpn.isConnected || vpn.isConnecting ? 10 : 0,
                        ),
                      ],
                      border: Border.all(
                        color: vpn.isConnected 
                            ? const Color(0xFF00E5FF) 
                            : (vpn.isConnecting ? Colors.orange : Colors.white12),
                        width: vpn.isConnected ? 4 : 2,
                      ),
                    ),
                    child: Center(
                      child: vpn.isConnecting
                          ? const CircularProgressIndicator(color: Colors.orange)
                          : Icon(
                              Icons.power_settings_new_rounded,
                              size: 80,
                              color: vpn.isConnected ? const Color(0xFF00E5FF) : Colors.white30,
                            ),
                    ),
                  ),
                ),

                const Spacer(),

                // Server Data Card (Slides up when connected)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.fastOutSlowIn,
                  height: vpn.isConnected ? 260 : 0,
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  child: SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1C22),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.dns_rounded, color: Color(0xFF00E5FF), size: 20),
                              SizedBox(width: 10),
                              Text("اطلاعات سرور (VPS)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Divider(color: Colors.white10, height: 1),
                          ),
                          if (vpn.serverInfo != null) ...[
                            _infoRow('آی‌پی سرور', vpn.serverInfo!['ip'] ?? '162.159.192.1', isHighlight: true),
                            const SizedBox(height: 16),
                            _infoRow('موقعیت مکانی', vpn.serverInfo!['city'] ?? 'نامشخص'),
                            const SizedBox(height: 16),
                            _infoRow('شبکه / دیتاسنتر', vpn.serverInfo!['org'] ?? 'WARP Network'),
                          ]
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, {bool isHighlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w600)),
        Text(
          value, 
          style: TextStyle(
            color: isHighlight ? const Color(0xFF00E5FF) : Colors.white, 
            fontSize: 14, 
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace'
          )
        ),
      ],
    );
  }
}
