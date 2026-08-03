import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import '../services/vpn_service.dart';
import '../l10n/app_localizations.dart';

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

  Color getStatusColor(VPNService vpn) {
    if (vpn.isConnected) return const Color(0xFF00E5FF); // Neon Cyan
    if (vpn.isConnecting) return const Color(0xFFFFB800); // Yellow/Orange
    if (vpn.stage == VpnStage.error) return const Color(0xFFFF3366); // Neon Red
    return const Color(0xFF888891); // Muted grey
  }

  @override
  Widget build(BuildContext context) {
    final vpn = context.watch<VPNService>();
    final color = getStatusColor(vpn);
    final active = vpn.isConnected || vpn.isConnecting;

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: Column(
        children: [
          _buildTitleBar(vpn, color),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  _buildHeader(),
                  const SizedBox(height: 30),
                  _buildPowerButton(vpn, color, active),
                  const SizedBox(height: 30),
                  _buildStatusText(vpn, color),
                  if (vpn.lastError != null) ...[
                    const SizedBox(height: 16),
                    _buildErrorBox(vpn),
                  ],
                  const SizedBox(height: 32),
                  _buildStatsGrid(vpn),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        RichText(
          text: const TextSpan(
            text: 'Oryvex',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -1.0,
              fontFamily: 'Inter',
            ),
            children: [
              TextSpan(
                text: 'VPN',
                style: TextStyle(
                  color: Color(0xFF00E5FF),
                  shadows: [Shadow(color: Color(0x3300E5FF), blurRadius: 20)],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Enjoy a fast, secure, and private internet experience with a simple and modern interface.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            height: 1.4,
            fontWeight: FontWeight.w500,
            color: Color(0xFF888891),
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildTitleBar(VPNService vpn, Color color) {
    return Container(
      height: 40,
      color: Colors.transparent,
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanStart: (_) => windowManager.startDragging(),
              child: const SizedBox(height: double.infinity),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.info_outline_rounded, color: Colors.white54, size: 16),
            onPressed: () => _showAiCompatibilityDialog(context),
            splashRadius: 18,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40),
            tooltip: 'AI Service Compatibility',
          ),
          IconButton(
            icon: const Icon(Icons.remove, color: Colors.white54, size: 16),
            onPressed: () => windowManager.minimize(),
            splashRadius: 18,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white54, size: 16),
            onPressed: () => windowManager.close(),
            splashRadius: 18,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusText(VPNService vpn, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0C0C0C),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1A1A1A)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [
                BoxShadow(color: color.withOpacity(0.5), blurRadius: 10),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            vpn.statusMessage.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF888891),
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBox(VPNService vpn) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0x1AFFFF33),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFF3366).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF3366), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              vpn.lastError!,
              style: const TextStyle(fontSize: 13, color: Color(0xFFFF6B8A), fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

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
            width: 180,
            height: 180,
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
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF080808),
            border: Border.all(color: const Color(0xFF1A1A1A)),
            boxShadow: [
              if (active)
                BoxShadow(
                  color: color.withOpacity(0.15),
                  blurRadius: 40,
                  spreadRadius: 5,
                ),
            ],
          ),
          child: vpn.isConnecting
              ? const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Color(0xFFFFB800)),
                  ),
                )
              : Icon(
                  Icons.power_settings_new_rounded,
                  size: 56,
                  color: active ? color : Colors.white24,
                ),
        ),
      ),
    );
  }

  void _showAiCompatibilityDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111111),
        title: Row(
          children: [
            Icon(Icons.info_outline_rounded, color: Colors.blue[400]),
            const SizedBox(width: 10),
            const Text(
              'AI Service Compatibility',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
        content: const Text(
          'AIs like Claude and ChatGPT, as well as certain other services, may occasionally return an Error 406 or refuse connections while using OryvexVPN.\n\nThis happens because these services detect specific network parameters that they don\'t accept and recognize the program, causing them to block the connection. Your VPN is still connected and working normally.\n\nWe will try to fix this issue in the future.',
          style: TextStyle(color: Colors.white70, height: 1.5, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: Colors.white54)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(VPNService vpn) {
    final s = vpn.stats;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildBentoCard(
                icon: Icons.timer_outlined,
                title: 'DURATION',
                value: vpn.connectedDuration,
                color: const Color(0xFF8B5CF6), // Purple accent
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildBentoCard(
                icon: Icons.speed_rounded,
                title: 'LATENCY',
                value: s.ping > 0 ? '${s.ping} ms' : '—',
                color: const Color(0xFFFFB800),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBentoCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    bool fullWidth = false,
  }) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF080808),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1A1A1A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF888891),
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontFamily: 'Inter', // Fallback to Inter
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

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
    const strokeWidth = 2.0;

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = const Color(0xFF1A1A1A);
    canvas.drawCircle(center, radius, trackPaint);

    if (!active && progress == 0) return;

    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 1.5
      ..strokeCap = StrokeCap.round
      ..color = color;

    // Apply blur to maskFilter to add a glow.
    // In Flutter, MaskFilter.blur can only be used on Canvas but it makes the element slightly translucent.
    // We'll leave it as a solid stroke for crisp UI as per modern dark theme specs.

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