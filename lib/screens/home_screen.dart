import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import '../services/vpn_service.dart';
import '../services/window_manager_service.dart';
import '../widgets/stats_card.dart';
import 'dart:math' as math;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VPNService>().initStatus();
    });

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotationController.dispose();
    super.dispose();
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
          // Custom Title Bar
          _buildTitleBar(vpn, getStatusColor),

          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 20),

                  // IP Info Banner
                  if (vpn.isConnected) _buildIPBanner(vpn),

                  const SizedBox(height: 40),

                  // Status Text
                  Text(
                    vpn.statusMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: getStatusColor(),
                      letterSpacing: 0.5,
                    ),
                  ),

                  if (vpn.lastError != null) ...[
                    const SizedBox(height: 16),
                    _buildErrorBox(vpn),
                  ],

                  const SizedBox(height: 40),

                  // Animated Connect Button
                  _buildConnectButton(vpn, getStatusColor),

                  const SizedBox(height: 50),

                  // Connection Stats
                  if (vpn.isConnected) ...[
                    _buildStatsGrid(vpn),
                    const SizedBox(height: 30),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleBar(VPNService vpn, Color Function() getStatusColor) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.black.withOpacity(0.5),
            Colors.transparent,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          AnimatedRotation(
            turns: vpn.isConnected ? 1 : 0,
            duration: const Duration(milliseconds: 500),
            child: Icon(
              vpn.isConnected ? Icons.shield_rounded : Icons.shield_outlined,
              color: getStatusColor(),
              size: 24,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'OryvexVPN',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1.2,
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
    );
  }

  Widget _buildIPBanner(VPNService vpn) {
    final ipInfo = vpn.stats.ipInfo;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF00E5FF).withOpacity(0.1),
            const Color(0xFF0099FF).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF00E5FF).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.location_on,
            color: Color(0xFF00E5FF),
            size: 18,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              '${ipInfo.ip} • ${ipInfo.city}, ${ipInfo.country}',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBox(VPNService vpn) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFF3366).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFF3366).withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline,
            color: Color(0xFFFF3366),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              vpn.lastError!,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFFFF3366),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectButton(VPNService vpn, Color Function() getStatusColor) {
    return GestureDetector(
      onTap: vpn.isConnecting
          ? null
          : () => vpn.isConnected ? vpn.disconnect() : vpn.connect(),
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          final pulseValue = _pulseController.value;
          final isActive = vpn.isConnected || vpn.isConnecting;

          return Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF1A1A1A),
                  const Color(0xFF0A0A0A),
                ],
              ),
              boxShadow: [
                if (isActive)
                  BoxShadow(
                    color: getStatusColor().withOpacity(0.3 * pulseValue),
                    blurRadius: 60 + (20 * pulseValue),
                    spreadRadius: 10 + (10 * pulseValue),
                  ),
              ],
            ),
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: getStatusColor().withOpacity(isActive ? 0.8 : 0.3),
                  width: isActive ? 3 : 2,
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    getStatusColor().withOpacity(isActive ? 0.2 : 0.05),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Center(
                child: vpn.isConnecting
                    ? SizedBox(
                        width: 60,
                        height: 60,
                        child: CircularProgressIndicator(
                          strokeWidth: 4,
                          valueColor: AlwaysStoppedAnimation(getStatusColor()),
                        ),
                      )
                    : AnimatedRotation(
                        turns: vpn.isConnected ? _rotationController.value : 0,
                        duration: Duration.zero,
                        child: Icon(
                          vpn.isConnected
                              ? Icons.power_settings_new_rounded
                              : Icons.power_settings_new_outlined,
                          size: 70,
                          color: getStatusColor(),
                        ),
                      ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatsGrid(VPNService vpn) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: StatsCard(
                  icon: Icons.speed_rounded,
                  label: 'Ping',
                  value: vpn.stats.ping > 0 ? '${vpn.stats.ping}ms' : '—',
                  color: const Color(0xFF00E5FF),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatsCard(
                  icon: Icons.language_rounded,
                  label: 'IP Address',
                  value: vpn.stats.ipInfo.ip,
                  color: const Color(0xFF00FF88),
                  valueSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StatsCard(
                  icon: Icons.download_rounded,
                  label: 'Download',
                  value: vpn.stats.downloadSpeed > 0
                      ? '${vpn.stats.downloadSpeed.toStringAsFixed(1)} KB/s'
                      : '0 KB/s',
                  color: const Color(0xFF00FFCC),
                  valueSize: 13,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatsCard(
                  icon: Icons.upload_rounded,
                  label: 'Upload',
                  value: vpn.stats.uploadSpeed > 0
                      ? '${vpn.stats.uploadSpeed.toStringAsFixed(1)} KB/s'
                      : '0 KB/s',
                  color: const Color(0xFFFF6B9D),
                  valueSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
