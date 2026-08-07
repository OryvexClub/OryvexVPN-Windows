import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import '../services/vpn_service.dart';
import '../services/oryvex_service.dart';
import '../widgets/logs_dialog.dart';
import '../theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _glowController;
  late final AnimationController _entryController;
  late final AnimationController _brandShimmerController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VPNService>().initStatus();
    });

    // Pulse ring animation (breathing when connected)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    // Glow intensity animation
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    // Entry animation (plays once on load)
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    // Brand shimmer animation
    _brandShimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _glowController.dispose();
    _entryController.dispose();
    _brandShimmerController.dispose();
    super.dispose();
  }

  Color getStatusColor(VPNService vpn) {
    if (vpn.isConnected) return AppTheme.accent;
    if (vpn.isConnecting) return AppTheme.warning;
    if (vpn.stage == VpnStage.error) return AppTheme.error;
    return AppTheme.textSecondary;
  }

  @override
  Widget build(BuildContext context) {
    final vpn = context.watch<VPNService>();
    final color = getStatusColor(vpn);
    final active = vpn.isConnected || vpn.isConnecting;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: Column(
          children: [
            _buildTitleBar(vpn, color),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
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
                    const SizedBox(height: 24),
                    _buildModeSelector(vpn, active),
                    const SizedBox(height: 24),
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

  // ── Header with animated brand text ───────────────────────────────
  Widget _buildHeader() {
    return AnimatedBuilder(
      animation: _entryController,
      builder: (context, child) {
        return FadeTransition(
          opacity: _entryController,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.1),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: _entryController,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          ),
        );
      },
      child: Column(
        children: [
          // Animated brand logo
          AnimatedBuilder(
            animation: _brandShimmerController,
            builder: (context, child) {
              return ShaderMask(
                shaderCallback: (Rect bounds) {
                  return LinearGradient(
                    begin: Alignment(-1.0 + 2.0 * _brandShimmerController.value, 0),
                    end: Alignment(-0.5 + 2.0 * _brandShimmerController.value, 0),
                    colors: const [
                      Colors.white,
                      AppTheme.accent,
                      Colors.white,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ).createShader(bounds);
                },
                blendMode: BlendMode.srcIn,
                child: RichText(
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
                          color: AppTheme.accent,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          const Text(
            'Enjoy a fast, secure, and private internet experience with a simple and modern interface.',
            textAlign: TextAlign.center,
            style: AppTheme.subheadingStyle,
          ),
        ],
      ),
    );
  }

  // ── Custom title bar ──────────────────────────────────────────────
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
            icon: const Icon(Icons.info_outline_rounded, color: AppTheme.textMuted, size: 16),
            onPressed: () => _showAiCompatibilityDialog(context),
            splashRadius: 18,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40),
            tooltip: 'AI Service Compatibility',
          ),
          IconButton(
            icon: const Icon(Icons.terminal, color: AppTheme.textMuted, size: 16),
            onPressed: () {
              AppTheme.showAnimatedDialog(
                context: context,
                builder: (context) => const LogsDialog(),
              );
            },
            splashRadius: 18,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40),
            tooltip: 'Core Logs',
          ),
          IconButton(
            icon: const Icon(Icons.remove, color: AppTheme.textMuted, size: 16),
            onPressed: () => windowManager.minimize(),
            splashRadius: 18,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: AppTheme.textMuted, size: 16),
            onPressed: () => windowManager.close(),
            splashRadius: 18,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40),
          ),
        ],
      ),
    );
  }

  // ── Status text pill ──────────────────────────────────────────────
  Widget _buildStatusText(VPNService vpn, Color color) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final glowOpacity = 0.3 + 0.2 * _pulseController.value;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: AppTheme.containerDecoration(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animated pulsing dot
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(glowOpacity),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                vpn.statusMessage.toUpperCase(),
                style: AppTheme.statusStyle,
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Error box ─────────────────────────────────────────────────────
  Widget _buildErrorBox(VPNService vpn) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.error.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.error.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppTheme.error, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              vpn.lastError!,
              style: const TextStyle(fontSize: 13, color: AppTheme.errorLight, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  // ── Power button with glow ring ───────────────────────────────────
  Widget _buildPowerButton(VPNService vpn, Color color, bool active) {
    return GestureDetector(
      onTap: vpn.isConnecting
          ? null
          : () => vpn.isConnected ? vpn.disconnect() : vpn.connect(),
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulseController, _glowController]),
        builder: (context, child) {
          final t = _pulseController.value;
          final glowT = _glowController.value;
          return SizedBox(
            width: 180,
            height: 180,
            child: CustomPaint(
              painter: _RingPainter(
                color: color,
                active: active,
                progress: vpn.isConnected ? 1.0 : t,
                glowIntensity: active ? 0.15 + 0.1 * glowT : 0.0,
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
            color: AppTheme.surfaceElevated,
            border: Border.all(color: AppTheme.border),
            boxShadow: [
              if (active)
                BoxShadow(
                  color: color.withOpacity(0.12 + 0.05 * _glowController.value),
                  blurRadius: 40,
                  spreadRadius: 5,
                ),
            ],
          ),
          child: vpn.isConnecting
              ? const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(AppTheme.warning),
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

  // ── AI compatibility dialog ───────────────────────────────────────
  void _showAiCompatibilityDialog(BuildContext context) {
    AppTheme.showAnimatedDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceOverlay,
        title: Row(
          children: [
            Icon(Icons.info_outline_rounded, color: AppTheme.accent),
            const SizedBox(width: 10),
            const Text(
              'AI Service Compatibility',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
        content: const Text(
          'AIs like Claude and ChatGPT, as well as certain other services, may occasionally return an Error 406 or refuse connections while using OryvexVPN.\n\nThis happens because these services detect specific network parameters that they don\'t accept and recognize the program, causing them to block the connection. Your VPN is still connected and working normally.\n\nWe will try to fix this issue in the future.',
          style: TextStyle(color: AppTheme.textDim, height: 1.5, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: AppTheme.textMuted)),
          ),
        ],
      ),
    );
  }

  // ── Mode selector ─────────────────────────────────────────────────
  Widget _buildModeSelector(VPNService vpn, bool active) {
    return AnimatedBuilder(
      animation: _entryController,
      builder: (context, child) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: _entryController,
            curve: const Interval(0.3, 0.7, curve: Curves.easeOut),
          ),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.1),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: _entryController,
              curve: const Interval(0.3, 0.7, curve: Curves.easeOutCubic),
            )),
            child: child,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: AppTheme.containerDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  active ? Icons.lock : Icons.lock_open,
                  size: 14,
                  color: active ? AppTheme.accent : AppTheme.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  'CONNECTION MODE',
                  style: AppTheme.labelStyle.copyWith(
                    color: active ? AppTheme.accent : AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildModeChip(
                  label: 'WireGuard',
                  icon: Icons.shield,
                  isSelected: vpn.isWireGuardMode,
                  active: active,
                  onTap: () => vpn.setVpnMode(VpnMode.wireGuard),
                ),
                const SizedBox(width: 8),
                _buildModeChip(
                  label: 'Oryvex Core',
                  icon: Icons.bolt,
                  isSelected: vpn.isOryvexMode,
                  active: active,
                  recommended: true,
                  onTap: () {
                    if (!active) {
                      _showProtocolSelector(context, vpn);
                    }
                  },
                ),
              ],
            ),
            if (vpn.isOryvexMode) ...[
              const SizedBox(height: 8),
              _buildProtocolInfo(vpn),
            ],
          ],
        ),
      ),
    );
  }

  // ── Protocol selector dialog ──────────────────────────────────────
  void _showProtocolSelector(BuildContext context, VPNService vpn) {
    AppTheme.showAnimatedDialog(
      context: context,
      slideUp: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppTheme.borderLight),
        ),
        title: const Text(
          'Select Protocol',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildProtocolOption(
              context: ctx,
              vpn: vpn,
              protocol: OryvexProtocol.auto,
              title: 'Auto',
              subtitle: 'Try all protocols (MASQUE → WireGuard → WARP)',
              icon: Icons.auto_awesome,
              color: AppTheme.purple,
            ),
            const SizedBox(height: 8),
            _buildProtocolOption(
              context: ctx,
              vpn: vpn,
              protocol: OryvexProtocol.masque,
              title: 'MASQUE',
              subtitle: 'Modern, QUIC/H3, best for DPI bypass',
              icon: Icons.speed,
              color: AppTheme.accent,
            ),
            const SizedBox(height: 8),
            _buildProtocolOption(
              context: ctx,
              vpn: vpn,
              protocol: OryvexProtocol.wireguard,
              title: 'WireGuard',
              subtitle: 'Classic, faster connection',
              icon: Icons.shield,
              color: AppTheme.primary,
            ),
            const SizedBox(height: 8),
            _buildProtocolOption(
              context: ctx,
              vpn: vpn,
              protocol: OryvexProtocol.warpinwarp,
              title: 'WARP-in-WARP',
              subtitle: 'Double tunnel, extra obfuscation',
              icon: Icons.hub,
              color: AppTheme.warning,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProtocolOption({
    required BuildContext context,
    required VPNService vpn,
    required OryvexProtocol protocol,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = vpn.oryvexProtocol == protocol;
    return GestureDetector(
      onTap: () {
        vpn.setOryvexProtocol(protocol);
        vpn.setVpnMode(VpnMode.oryvexCore);
        Navigator.pop(context);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : AppTheme.surfaceOverlay,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : AppTheme.borderLight,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? Colors.white : AppTheme.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppTheme.textTertiary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: color, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildProtocolInfo(VPNService vpn) {
    String protocolName;
    IconData protocolIcon;
    Color protocolColor;

    switch (vpn.oryvexProtocol) {
      case OryvexProtocol.masque:
        protocolName = 'MASQUE';
        protocolIcon = Icons.speed;
        protocolColor = AppTheme.accent;
        break;
      case OryvexProtocol.wireguard:
        protocolName = 'WireGuard';
        protocolIcon = Icons.shield;
        protocolColor = AppTheme.primary;
        break;
      case OryvexProtocol.warpinwarp:
        protocolName = 'WARP-in-WARP';
        protocolIcon = Icons.hub;
        protocolColor = AppTheme.warning;
        break;
      case OryvexProtocol.auto:
        protocolName = 'Auto';
        protocolIcon = Icons.auto_awesome;
        protocolColor = AppTheme.purple;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceOverlay,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(protocolIcon, size: 12, color: protocolColor),
          const SizedBox(width: 6),
          Text(
            protocolName,
            style: TextStyle(
              color: protocolColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required bool active,
    required VoidCallback onTap,
    bool recommended = false,
  }) {
    final color = isSelected ? AppTheme.accent : AppTheme.borderActive;
    final textColor = isSelected ? Colors.black : AppTheme.textSecondary;
    final iconColor = isSelected ? Colors.black : AppTheme.textSecondary;

    return Expanded(
      child: GestureDetector(
        onTap: active ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected ? AppTheme.accent : AppTheme.border,
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: isSelected
                ? AppTheme.glowShadow(AppTheme.accent, blurRadius: 8, opacity: 0.2)
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: active && !isSelected ? Colors.white24 : iconColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTheme.buttonLabelStyle.copyWith(
                  color: active && !isSelected ? Colors.white24 : textColor,
                ),
              ),
              if (recommended && !isSelected) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: const Text(
                    'REC',
                    style: TextStyle(
                      fontSize: 7,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.warning,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Stats grid ────────────────────────────────────────────────────
  Widget _buildStatsGrid(VPNService vpn) {
    final s = vpn.stats;
    return AnimatedBuilder(
      animation: _entryController,
      builder: (context, child) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: _entryController,
            curve: const Interval(0.5, 0.9, curve: Curves.easeOut),
          ),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.1),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: _entryController,
              curve: const Interval(0.5, 0.9, curve: Curves.easeOutCubic),
            )),
            child: child,
          ),
        );
      },
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildBentoCard(
                  icon: Icons.timer_outlined,
                  title: 'DURATION',
                  value: vpn.connectedDuration,
                  color: AppTheme.purple,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildBentoCard(
                  icon: Icons.speed_rounded,
                  title: 'LATENCY',
                  value: s.ping > 0 ? '${s.ping} ms' : '—',
                  color: AppTheme.warning,
                ),
              ),
            ],
          ),
        ],
      ),
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
      decoration: AppTheme.glassDecoration(),
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
                style: AppTheme.labelStyle,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: AppTheme.valueStyle,
          ),
        ],
      ),
    );
  }
}

// ── Custom ring painter with glow ───────────────────────────────────
class _RingPainter extends CustomPainter {
  final Color color;
  final bool active;
  final double progress;
  final double glowIntensity;

  _RingPainter({
    required this.color,
    required this.active,
    required this.progress,
    this.glowIntensity = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 2;
    const strokeWidth = 2.0;

    // Draw track ring
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = AppTheme.border;
    canvas.drawCircle(center, radius, trackPaint);

    if (!active && progress == 0) return;

    // Draw glow layer (behind the arc)
    if (glowIntensity > 0) {
      final glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth * 4
        ..strokeCap = StrokeCap.round
        ..color = color.withOpacity(glowIntensity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

      final start = -math.pi / 2;
      final sweep = 2 * math.pi * progress.clamp(0.0, 1.0);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        false,
        glowPaint,
      );
    }

    // Draw main arc
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 1.5
      ..strokeCap = StrokeCap.round
      ..color = color;

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
      oldDelegate.progress != progress ||
      oldDelegate.glowIntensity != glowIntensity;
}
