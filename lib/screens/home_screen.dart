import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/vpn_service.dart';
import '../constants/strings.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final vpnService = Provider.of<VPNService>(context);
    final isConnected = vpnService.isConnected;
    final isConnecting = vpnService.isConnecting;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shield_outlined, color: Color(0xFF00E5FF)),
            const SizedBox(width: 10),
            Text(Strings.appTitle, style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 1),
            // Status Text
            Text(
              vpnService.statusMessage,
              style: TextStyle(
                fontSize: 18,
                color: isConnected ? const Color(0xFF00E5FF) : Colors.white54,
                fontWeight: isConnected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const SizedBox(height: 40),
            
            // Big Connect Button
            GestureDetector(
              onTap: () {
                if (isConnecting) return;
                isConnected ? vpnService.disconnect() : vpnService.connect();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isConnected 
                      ? Colors.redAccent.withOpacity(0.1) 
                      : const Color(0xFF00E5FF).withOpacity(0.1),
                  border: Border.all(
                    color: isConnected ? Colors.redAccent : const Color(0xFF00E5FF),
                    width: 4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (isConnected ? Colors.redAccent : const Color(0xFF00E5FF)).withOpacity(isConnecting ? 0.6 : 0.2),
                      blurRadius: isConnecting ? 50 : 30,
                      spreadRadius: isConnecting ? 10 : 5,
                    )
                  ]
                ),
                child: Center(
                  child: isConnecting
                      ? const CircularProgressIndicator(color: Color(0xFF00E5FF))
                      : Icon(
                          Icons.power_settings_new_rounded,
                          size: 80,
                          color: isConnected ? Colors.redAccent : const Color(0xFF00E5FF),
                        ),
                ),
              ),
            ),
            
            const Spacer(flex: 2),
            
            // Server Info Panel
            if (vpnService.serverInfo != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.dns_outlined, color: Color(0xFF00E5FF), size: 20),
                            SizedBox(width: 10),
                            Text("اطلاعات سرور (VPS)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                        const Divider(color: Colors.white12, height: 30),
                        _buildInfoRow('آی‌پی سرور', vpnService.serverInfo!['ip']),
                        const SizedBox(height: 12),
                        _buildInfoRow('موقعیت', vpnService.serverInfo!['city'] ?? 'نامشخص'),
                        const SizedBox(height: 12),
                        _buildInfoRow('شبکه', vpnService.serverInfo!['org'] ?? 'WARP / Cloudflare'),
                      ],
                    ),
                  ),
                ),
              ),
              
             if (vpnService.errorMessage != null)
               Padding(
                 padding: const EdgeInsets.all(20),
                 child: Text(vpnService.errorMessage!, style: const TextStyle(color: Colors.redAccent), textAlign: TextAlign.center),
               )
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 14)),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
      ],
    );
  }
}
