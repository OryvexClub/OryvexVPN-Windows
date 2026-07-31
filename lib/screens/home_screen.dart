import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/vpn_service.dart';
import '../services/warp_generator.dart';
import '../widgets/connect_button.dart';
import '../widgets/endpoint_selector.dart';
import '../constants/strings.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _customIp = '', _customPort = '';

  @override
  Widget build(BuildContext context) {
    final vpnService = Provider.of<VPNService>(context);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, 
            end: Alignment.bottomCenter, 
            colors: [Color(0xFF0A0A0A), Color(0xFF1A1A1A)]
          )
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                floating: true,
                backgroundColor: Colors.transparent,
                elevation: 0,
                title: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8), 
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.2), 
                      shape: BoxShape.circle
                    ), 
                    child: const Icon(Icons.vpn_lock, color: Color(0xFF10B981))
                  ),
                  const SizedBox(width: 12),
                  const Text(Strings.appTitle, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white)),
                ]),
                actions: [
                  Container(
                    margin: const EdgeInsets.only(right: 16), 
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), 
                    decoration: BoxDecoration(
                      color: vpnService.isConnected ? const Color(0xFF10B981).withOpacity(0.2) : Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20)
                    ),
                    child: Text(
                      vpnService.isConnected ? Strings.statusConnected : Strings.statusDisconnected,
                      style: TextStyle(
                        color: vpnService.isConnected ? const Color(0xFF10B981) : Colors.red,
                        fontWeight: FontWeight.bold
                      )
                    )
                  )
                ],
              ),
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24), 
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start, 
                          children: [
                            Row(children: [
                              Container(
                                width: 12, height: 12, 
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle, 
                                  color: vpnService.isConnected ? const Color(0xFF10B981) : (vpnService.isConnecting ? Colors.orange : Colors.red)
                                )
                              ),
                              const SizedBox(width: 12),
                              Text(vpnService.statusMessage, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white)),
                            ]),
                            if (vpnService.errorMessage != null) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(8), 
                                decoration: BoxDecoration(color: Colors.red.withOpacity(0.2), borderRadius: BorderRadius.circular(8)), 
                                child: Text(vpnService.errorMessage!, style: const TextStyle(color: Colors.red))
                              )
                            ],
                            if (vpnService.accountInfo != null && vpnService.isConnected) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12), 
                                decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.1), borderRadius: BorderRadius.circular(8)), 
                                child: Row(children: [
                                  const Icon(Icons.person, color: Color(0xFF10B981)),
                                  const SizedBox(width: 8),
                                  Text('${Strings.accountType}: ${vpnService.accountInfo!['account_type']}', style: const TextStyle(color: Colors.white))
                                ])
                              )
                            ],
                            if (vpnService.selectedEndpoint.isNotEmpty && vpnService.isConnected) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(8), 
                                decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(8)), 
                                child: Row(children: [
                                  const Icon(Icons.route, color: Colors.white70, size: 16),
                                  const SizedBox(width: 8),
                                  Text('${Strings.endpoint}: ${vpnService.selectedEndpoint}', style: const TextStyle(color: Colors.white70))
                                ])
                              )
                            ],
                            const SizedBox(height: 16),
                            ConnectButton(
                              onPressed: vpnService.isConnected ? vpnService.disconnect : () async { 
                                await vpnService.generateAndConnect(customIp: _customIp.isNotEmpty ? _customIp : null, customPort: _customPort.isNotEmpty ? _customPort : null); 
                              },
                              isConnected: vpnService.isConnected,
                              isConnecting: vpnService.isConnecting,
                            ),
                          ]
                        )
                      )
                    ),
                    const SizedBox(height: 16),
                    EndpointSelector(
                      onEndpointSelected: (ip, port) { 
                        setState(() { _customIp = ip; _customPort = port; }); 
                      }
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16), 
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start, 
                          children: [
                            const Text('⚡ ${Strings.quickActions}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                            const SizedBox(height: 12),
                            Row(children: [
                              Expanded(
                                child: _buildQuickButton(
                                  icon: Icons.shuffle, 
                                  label: Strings.randomIP, 
                                  onTap: () { 
                                    final endpoint = WARPGenerator.getRandomEndpoint(); 
                                    setState(() { _customIp = endpoint['ip']!; _customPort = endpoint['port']!; }); 
                                  }
                                )
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildQuickButton(
                                  icon: Icons.refresh, 
                                  label: Strings.reset, 
                                  onTap: () { 
                                    setState(() { _customIp = ''; _customPort = ''; }); 
                                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(Strings.resetToDefault))); 
                                  }
                                )
                              ),
                            ]),
                          ]
                        )
                      )
                    ),
                    const SizedBox(height: 20),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return Material(
      color: Colors.grey[800], 
      borderRadius: BorderRadius.circular(8), 
      child: InkWell(
        onTap: onTap, 
        borderRadius: BorderRadius.circular(8), 
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12), 
          child: Column(
            children: [
              Icon(icon, color: const Color(0xFF10B981)), 
              const SizedBox(height: 4), 
              Text(label, style: const TextStyle(color: Colors.white, fontSize: 12))
            ]
          )
        )
      )
    );
  }
}
