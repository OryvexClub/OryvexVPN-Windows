import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF111111), Color(0xFF0A0A0A)],
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
                      const Icon(Icons.dashboard_rounded, color: Colors.white70),
                      Row(
                        children: [
                          Icon(
                            vpn.isConnected ? Icons.shield_rounded : Icons.shield_outlined, 
                            color: vpn.isConnected ? const Color(0xFF00E5FF) : Colors.white54
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Oryvex VPS',
                            style: TextStyle(
                              fontFamily: 'Vazirmatn',
                              fontSize: 20, 
                              fontWeight: FontWeight.bold,
                              color: vpn.isConnected ? const Color(0xFF00E5FF) : Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const Icon(Icons.settings_rounded, color: Colors.white70),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                Text(
                  vpn.statusMessage,
                  style: TextStyle(
                    fontFamily: 'Vazirmatn',
                    fontSize: 16,
                    color: vpn.isConnected ? const Color(0xFF00E5FF) : Colors.white54,
                  ),
                ),
                const SizedBox(height: 30),

                // Connect Button
                GestureDetector(
                  onTap: () => vpn.isConnecting ? null : (vpn.isConnected ? vpn.disconnect() : vpn.connect()),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF1A1A1A),
                      boxShadow: [
                        BoxShadow(
                          color: vpn.isConnected 
                              ? const Color(0xFF00E5FF).withOpacity(0.3)
                              : (vpn.isConnecting ? Colors.orange.withOpacity(0.3) : Colors.black26),
                          blurRadius: vpn.isConnected || vpn.isConnecting ? 50 : 15,
                          spreadRadius: vpn.isConnected || vpn.isConnecting ? 5 : 0,
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
                              size: 70,
                              color: vpn.isConnected ? const Color(0xFF00E5FF) : Colors.white30,
                            ),
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // Info Panel
                Expanded(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 400),
                    opacity: vpn.isConnected ? 1.0 : 0.0,
                    child: vpn.isConnected ? SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          if (vpn.serverInfo != null)
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A1A1A),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.dns_rounded, color: Color(0xFF00E5FF), size: 18),
                                      SizedBox(width: 8),
                                      Text("اطلاعات سرور", style: TextStyle(fontFamily: 'Vazirmatn', fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  const Divider(color: Colors.white10, height: 24),
                                  _infoRow('آی‌پی', vpn.serverInfo!['ip'] ?? '-'),
                                  const SizedBox(height: 12),
                                  _infoRow('موقعیت', '${vpn.serverInfo!['city'] ?? ''} - ${vpn.serverInfo!['country_name'] ?? ''}'),
                                  const SizedBox(height: 12),
                                  _infoRow('شبکه', vpn.serverInfo!['org'] ?? '-'),
                                ],
                              ),
                            ),
                          const SizedBox(height: 20),
                          if (vpn.generatedConfig != null)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A1A1A),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Row(
                                        children: [
                                          Icon(Icons.code_rounded, color: Color(0xFF00E5FF), size: 18),
                                          SizedBox(width: 8),
                                          Text("کانفیگ وایرگارد", style: TextStyle(fontFamily: 'Vazirmatn', fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.copy_rounded, size: 20, color: Colors.white54),
                                        onPressed: () {
                                          Clipboard.setData(ClipboardData(text: vpn.generatedConfig!));
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('کانفیگ کپی شد', style: TextStyle(fontFamily: 'Vazirmatn'))),
                                          );
                                        },
                                      )
                                    ],
                                  ),
                                  const Divider(color: Colors.white10, height: 16),
                                  Text(
                                    vpn.generatedConfig!,
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 12,
                                      color: Color(0xFF00E5FF),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                        ],
                      ),
                    ) : const SizedBox(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontFamily: 'Vazirmatn', color: Colors.white54, fontSize: 14)),
        Text(
          value, 
          style: const TextStyle(
            fontFamily: 'Vazirmatn',
            color: Colors.white, 
            fontSize: 14, 
            fontWeight: FontWeight.bold,
          )
        ),
      ],
    );
  }
}
