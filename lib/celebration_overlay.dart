import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// A single confetti particle with full physics
class _Particle {
  double x, y;
  double vx, vy; // velocity
  double gravity;
  double size;
  Color color;
  double rotation;
  double rotationSpeed;
  double opacity;
  double drag; // air resistance
  int shape; // 0=circle, 1=rect, 2=strip, 3=diamond

  _Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.gravity,
    required this.size,
    required this.color,
    required this.rotation,
    required this.rotationSpeed,
    required this.opacity,
    required this.drag,
    required this.shape,
  });
}

/// Custom painter — draws all particles every frame
class _ConfettiPainter extends CustomPainter {
  final List<_Particle> particles;
  _ConfettiPainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      if (p.opacity <= 0) continue;
      final paint = Paint()..color = p.color.withValues(alpha: p.opacity);
      canvas.save();
      canvas.translate(p.x, p.y);
      canvas.rotate(p.rotation);

      switch (p.shape) {
        case 0: // circle
          canvas.drawCircle(Offset.zero, p.size * 0.5, paint);
          break;
        case 1: // rectangle
          canvas.drawRect(
            Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.55),
            paint,
          );
          break;
        case 2: // long strip / ribbon
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset.zero, width: p.size * 1.4, height: p.size * 0.35),
              Radius.circular(p.size * 0.15),
            ),
            paint,
          );
          break;
        case 3: // diamond
          final path = Path()
            ..moveTo(0, -p.size * 0.5)
            ..lineTo(p.size * 0.35, 0)
            ..lineTo(0, p.size * 0.5)
            ..lineTo(-p.size * 0.35, 0)
            ..close();
          canvas.drawPath(path, paint);
          break;
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Full-screen celebration overlay with smooth 60fps confetti
class CelebrationOverlay extends StatefulWidget {
  final String message;
  final VoidCallback onDismiss;
  final IconData icon;
  final Color bannerColor;

  const CelebrationOverlay({
    super.key,
    required this.message,
    required this.onDismiss,
    this.icon = Icons.check_circle_rounded,
    this.bannerColor = const Color(0xFF2E7D32),
  });

  @override
  State<CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends State<CelebrationOverlay>
    with TickerProviderStateMixin {
  late final Ticker _ticker;
  late final AnimationController _bannerAnim;
  final List<_Particle> _particles = [];
  final Random _rng = Random();

  double _elapsed = 0; // total seconds elapsed
  bool _bannerDismissing = false;
  Size _screenSize = Size.zero;

  // Vibrant celebration palette
  static const _colors = [
    Color(0xFFFF6B6B), Color(0xFFFFD93D), Color(0xFF6BCB77),
    Color(0xFF4D96FF), Color(0xFFFF8E71), Color(0xFFC084FC),
    Color(0xFFF472B6), Color(0xFF22D3EE), Color(0xFFFB923C),
    Color(0xFFA78BFA), Color(0xFF34D399), Color(0xFFF87171),
    Color(0xFF60A5FA), Color(0xFFFBBF24), Color(0xFFA3E635),
  ];

  @override
  void initState() {
    super.initState();

    // Banner slide animation
    _bannerAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();

    // High-performance ticker for 60fps particle updates
    _ticker = createTicker(_onTick)..start();

    // Auto-dismiss after 2.8s
    Future.delayed(const Duration(milliseconds: 2800), _startDismiss);
  }

  void _startDismiss() {
    if (!mounted || _bannerDismissing) return;
    _bannerDismissing = true;
    _bannerAnim.reverse().then((_) {
      if (mounted) widget.onDismiss();
    });
  }

  /// Spawn particles — called every frame during the burst phase
  void _spawnParticles(double screenW, double screenH) {
    // Burst phase: first 0.8 seconds spawn heavily, then taper off
    final spawnRate = _elapsed < 0.15
        ? 25 // initial explosion
        : _elapsed < 0.5
            ? 12
            : _elapsed < 1.0
                ? 6
                : _elapsed < 1.5
                    ? 2
                    : 0;

    for (int i = 0; i < spawnRate; i++) {
      // Spawn from top edge, random X positions across entire width
      final spawnX = _rng.nextDouble() * screenW;
      final spawnY = -_rng.nextDouble() * 40;

      // Some particles also burst from the sides
      final fromSide = _rng.nextDouble() < 0.2;
      final sx = fromSide
          ? (_rng.nextBool() ? -10.0 : screenW + 10.0)
          : spawnX;
      final sy = fromSide
          ? _rng.nextDouble() * screenH * 0.4
          : spawnY;

      _particles.add(_Particle(
        x: sx,
        y: sy,
        vx: (_rng.nextDouble() - 0.5) * 200, // horizontal spread
        vy: _rng.nextDouble() * 250 + 80, // downward velocity
        gravity: _rng.nextDouble() * 120 + 80,
        size: _rng.nextDouble() * 8 + 4,
        color: _colors[_rng.nextInt(_colors.length)],
        rotation: _rng.nextDouble() * pi * 2,
        rotationSpeed: (_rng.nextDouble() - 0.5) * 6,
        opacity: 1.0,
        drag: _rng.nextDouble() * 0.3 + 0.85, // 0.85 - 1.15 drag
        shape: _rng.nextInt(4),
      ));
    }
  }

  void _onTick(Duration duration) {
    final dt = duration.inMicroseconds / 1000000.0;
    final prevElapsed = _elapsed;
    _elapsed = dt;

    if (_screenSize == Size.zero) return;

    final frameDt = (_elapsed - prevElapsed).clamp(0.0, 0.05); // cap at 50ms

    // Spawn new particles
    _spawnParticles(_screenSize.width, _screenSize.height);

    // Update existing particles
    for (final p in _particles) {
      // Apply gravity
      p.vy += p.gravity * frameDt;

      // Apply drag (air resistance for horizontal sway)
      p.vx *= (1.0 - (1.0 - p.drag) * frameDt * 3);

      // Sinusoidal wobble
      p.vx += sin(_elapsed * 3 + p.rotation) * 15 * frameDt;

      // Move
      p.x += p.vx * frameDt;
      p.y += p.vy * frameDt;

      // Rotate
      p.rotation += p.rotationSpeed * frameDt;

      // Fade out particles near bottom of screen
      if (p.y > _screenSize.height * 0.75) {
        final fadeZone = _screenSize.height * 0.25;
        final distFromFadeStart = p.y - _screenSize.height * 0.75;
        p.opacity = (1.0 - distFromFadeStart / fadeZone).clamp(0.0, 1.0);
      }

      // Also fade late particles
      if (_elapsed > 2.0) {
        p.opacity *= 0.97;
      }
    }

    // Remove dead particles
    _particles.removeWhere((p) => p.opacity <= 0.01 || p.y > _screenSize.height + 50);

    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    _bannerAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _screenSize = MediaQuery.of(context).size;
    final topPadding = MediaQuery.of(context).padding.top;

    // Banner animation values
    final bannerProgress = CurvedAnimation(
      parent: _bannerAnim,
      curve: Curves.easeOutBack,
    ).value;
    final bannerY = -80.0 + (80.0 + topPadding + 12) * bannerProgress;
    final bannerOpacity = _bannerAnim.value.clamp(0.0, 1.0);

    return Material(
      color: Colors.transparent,
      child: SizedBox.expand(
        child: Stack(
          children: [
            // Full-screen confetti canvas
            Positioned.fill(
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _ConfettiPainter(_particles),
                    size: _screenSize,
                  ),
                ),
              ),
            ),

            // Success banner at top
            Positioned(
              top: bannerY,
              left: 16,
              right: 16,
              child: Opacity(
                opacity: bannerOpacity,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        widget.bannerColor,
                        widget.bannerColor.withValues(alpha: 0.88),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: widget.bannerColor.withValues(alpha: 0.35),
                        blurRadius: 24,
                        spreadRadius: 2,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Icon with glow circle
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(widget.icon, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.message,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.15,
                            height: 1.3,
                          ),
                        ),
                      ),
                      const Text('🎉', style: TextStyle(fontSize: 22)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Call this from anywhere to show the celebration effect
void showCelebration(
  BuildContext context,
  String message, {
  IconData icon = Icons.check_circle_rounded,
  Color bannerColor = const Color(0xFF2E7D32),
}) {
  // Use the root navigator's overlay so this works regardless of which
  // page/sheet triggered it (avoids "No Overlay widget found" error).
  OverlayState? overlay;
  try {
    overlay = Navigator.of(context, rootNavigator: true).overlay;
  } catch (_) {
    overlay = Overlay.maybeOf(context);
  }
  if (overlay == null) return;

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) => CelebrationOverlay(
      message: message,
      icon: icon,
      bannerColor: bannerColor,
      onDismiss: () {
        if (entry.mounted) entry.remove();
      },
    ),
  );
  overlay!.insert(entry);
}
