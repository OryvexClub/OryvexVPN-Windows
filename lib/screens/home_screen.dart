import 'dart:io';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import '../services/vpn_service.dart';
import '../widgets/stats_card.dart';
import '../l10n/app_localizations.dart';
import '../services/system_check_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VPNService>().initStatus();
      _checkSystem();
    });
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _checkSystem() async {
    bool clockSynced = await SystemCheckService.isClockSynced();
    List<String> procs = await SystemCheckService.getConflictingProcesses();
    
    if (!clockSynced || procs.isNotEmpty) {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            backgroundColor: const Color(0xFF0A0A0A),
            title: const Text('هشدار سیستم', style: TextStyle(color: Colors.white)),
            content: Text(
              (clockSynced ? '' : 'ساعت سیستم شما تنظیم نیست.\n') +
              (procs.isNotEmpty ? 'برنامه‌های متداخل یافت شد: ${procs.join(', ')}' : ''),
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  exit(0);
                },
                child: const Text('Exit app', style: TextStyle(color: Colors.white54)),
              ),
              if (procs.isNotEmpty)
                TextButton(
                  onPressed: () {
                    for (var p in procs) {
                      Process.run('taskkill', ['/F', '/IM', p]);
                    }
                    Navigator.of(context).pop();
                  },
                  child: const Text('Kill All', style: TextStyle(color: Color(0xFFFF3366))),
                ),
            ],
          );
        }
      );
    }
  }

  Color getStatusColor(VPNService vpn) {
    if (vpn.isConnected) return const Color(0xFF00E676);
    if (vpn.isConnecting) return const Color(0xFFFFB800);
    if (vpn.stage == VpnStage.error) return const Color(0xFFFF3366);
    return const Color(0xFF4A4A4A);
  }

  

  

  @override
  Widget build(BuildContext context) {
    final vpn = context.watch<VPNService>();
    final color = getStatusColor(vpn);
    final active = vpn.isConnected || vpn.isConnecting;

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.2),
            radius: 1.4,
            colors: [
              Color(0xFF050F05),
              Color(0xFF000000),
            ],
          ),
        ),
        child: Column(
          children: [
            _buildTitleBar(vpn, color),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    _buildStatusText(vpn, color),
                    if (vpn.lastError != null) ...[
                      const SizedBox(height: 12),
                      _buildErrorBox(vpn),
                    ],
                    const SizedBox(height: 28),
                    _buildPowerButton(vpn, color, active),
                    const SizedBox(height: 22),
                    _buildConnectionInfo(vpn, color),
                    const SizedBox(height: 28),
                    _buildStatsGrid(vpn),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- Title bar ---------------------------------------------------------

  Widget _buildTitleBar(VPNService vpn, Color color) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: Colors.black.withOpacity(0.25),
      child: Row(
        children: [
          const SizedBox(width: 8),
          Icon(Icons.shield_rounded, color: color, size: 22),
          const SizedBox(width: 8),
          const Text(
            'OryvexVPN',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1,
            ),
          ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanStart: (_) => windowManager.startDragging(),
              child: const SizedBox(height: double.infinity),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove, color: Colors.white54, size: 18),
            onPressed: () => windowManager.minimize(),
            tooltip: 'کوچک‌سازی',
            splashRadius: 18,
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white54, size: 18),
            onPressed: () => windowManager.close(),
            tooltip: 'بستن',
            splashRadius: 18,
          ),
        ],
      ),
    );
  }

  // ---- Status text -------------------------------------------------------

  Widget _buildStatusText(VPNService vpn, Color color) {
    return Column(
      children: [
        Text(
          vpn.statusMessage,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: color,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          vpn.currentEndpoint,
          style: const TextStyle(color: Colors.white38, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildErrorBox(VPNService vpn) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFF3366).withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFF3366).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFFF3366), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              vpn.lastError!,
              style: const TextStyle(fontSize: 12.5, color: Color(0xFFFF6B8A)),
            ),
          ),
        ],
      ),
    );
  }

  // ---- Power button ------------------------------------------------------

  Widget _buildPowerButton(VPNService vpn, Color color, bool active) {
    return GestureDetector(
      onTap: vpn.isConnecting
          ? null
          : () => vpn.isConnected ? vpn.disconnect() : vpn.connect(),
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          final t = _pulseController.value;
          return SizedBox(
            width: 210,
            height: 210,
            child: CustomPaint(
              painter: _RingPainter(
                color: color,
                active: active,
                progress: vpn.isConnected ? 1.0 : t,
              ),
              child: Center(child: child),
            ),
          );
        },
        child: Container(
          width: 160,
          height: 160,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF051005),
                Color(0xFF000000),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(active ? 0.35 : 0.08),
                blurRadius: 50,
                spreadRadius: active ? 8 : 0,
              ),
            ],
          ),
          child: vpn.isConnecting
              ? const CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation(Color(0xFFFFB800)),
                )
              : Icon(
                  vpn.isConnected
                      ? Icons.power_settings_new_rounded
                      : Icons.power_settings_new_outlined,
                  size: 62,
                  color: color,
                ),
        ),
      ),
    );
  }

  // ---- Connection info ---------------------------------------------------

  Widget _buildConnectionInfo(VPNService vpn, Color color) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.timer_outlined, color: color, size: 20),
          const SizedBox(width: 8),
          Text('${l10n.duration}: ',
              style: const TextStyle(color: Colors.white60, fontSize: 13)),
          Text(
            vpn.connectedDuration,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ---- Stats grid --------------------------------------------------------

  Widget _buildStatsGrid(VPNService vpn) {
    final s = vpn.stats;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: StatsCard(
                icon: Icons.speed_rounded,
                label: 'پینگ',
                value: s.ping > 0 ? '${s.ping} ms' : '—',
                color: const Color(0xFFFFB800),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatsCard(
                icon: Icons.language_rounded,
                label: 'آی‌پی',
                value: s.ipInfo.ip,
                color: const Color(0xFF00E676),
                valueSize: 13,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Animated ring around the power button.
class _RingPainter extends CustomPainter {
  final Color color;
  final bool active;
  final double progress;

  _RingPainter({
    required this.color,
    required this.active,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 2;
    const strokeWidth = 5.0;

    // Track.
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = Colors.white.withOpacity(0.06);
    canvas.drawCircle(center, radius, trackPaint);

    // Progress arc.
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [
          color.withOpacity(0.3),
          color,
          color.withOpacity(0.3),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    final start = -math.pi / 2;
    final sweep = 2 * math.pi * progress.clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start,
      sweep,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.active != active ||
      oldDelegate.progress != progress;
}
