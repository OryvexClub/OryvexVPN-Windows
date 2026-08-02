import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import '../services/vpn_service.dart';
import '../widgets/stats_card.dart';
import '../l10n/app_localizations.dart';
import '../l10n/locale_provider.dart';

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
    if (vpn.isConnected) return const Color(0xFF00E5FF);
    if (vpn.isConnecting) return const Color(0xFFFFB800);
    if (vpn.stage == VpnStage.error) return const Color(0xFFFF3366);
    return const Color(0xFF8A8A8A);
  }

  String _fmtSpeed(double kb) {
    if (kb <= 0) return '0';
    if (kb >= 1024 * 1024) return (kb / 1024 / 1024).toStringAsFixed(1);
    if (kb >= 1024) return (kb / 1024).toStringAsFixed(1);
    return kb.toStringAsFixed(0);
  }

  String _fmtBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes >= 1073741824) return '${(bytes / 1073741824).toStringAsFixed(1)} GB';
    if (bytes >= 1048576) return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '$bytes B';
  }

  @override
  Widget build(BuildContext context) {
    final vpn = context.watch<VPNService>();
    final color = getStatusColor(vpn);
    final active = vpn.isConnected || vpn.isConnecting;

    return Scaffold(
      backgroundColor: const Color(0xFF080B12),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.2),
            radius: 1.4,
            colors: [
              Color(0xFF0F1B2E),
              Color(0xFF080B12),
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
    final localeProvider = context.watch<LocaleProvider>();
    final isRtl = localeProvider.isRtl;
    final currentLang = localeProvider.locale.languageCode;

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
          // Language toggle
          GestureDetector(
            onTap: () => localeProvider.toggleLocale(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                currentLang == 'en' ? 'EN' : 'FA',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.remove, color: Colors.white54, size: 18),
            onPressed: () => windowManager.minimize(),
            tooltip: isRtl ? 'کوچک‌سازی' : 'Minimize',
            splashRadius: 18,
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white54, size: 18),
            onPressed: () => windowManager.close(),
            tooltip: isRtl ? 'بستن' : 'Close',
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
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF1A2332),
                const Color(0xFF0C111C),
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
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
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
    final l10n = AppLocalizations.of(context);
    final s = vpn.stats;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: StatsCard(
                icon: Icons.south_rounded,
                label: l10n.download,
                value: '${_fmtSpeed(s.downloadSpeed)} KB/s',
                color: const Color(0xFF00E5FF),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatsCard(
                icon: Icons.north_rounded,
                label: l10n.upload,
                value: '${_fmtSpeed(s.uploadSpeed)} KB/s',
                color: const Color(0xFF00FF88),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: StatsCard(
                icon: Icons.speed_rounded,
                label: l10n.ping,
                value: s.ping > 0 ? '${s.ping} ms' : '—',
                color: const Color(0xFFFFB800),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatsCard(
                icon: Icons.language_rounded,
                label: l10n.ipAddress,
                value: s.ipInfo.ip,
                color: const Color(0xFF00FFCC),
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
                icon: Icons.south_rounded,
                label: l10n.totalDownload,
                value: _fmtBytes(vpn.totalDownload),
                color: const Color(0xFF7C7CFF),
                valueSize: 15,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatsCard(
                icon: Icons.north_rounded,
                label: l10n.totalUpload,
                value: _fmtBytes(vpn.totalUpload),
                color: const Color(0xFFFF6B9D),
                valueSize: 15,
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
