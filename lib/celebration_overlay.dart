import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

// ---------------------------------------------------------------------------
// Particle data class
// ---------------------------------------------------------------------------
class _Particle {
  double x, y;
  double vx, vy;
  double gravity;
  double size;
  Color color;
  double rotation;
  double rotationSpeed;
  double opacity;
  double drag; // 0..1 — per-frame velocity multiplier base
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

// ---------------------------------------------------------------------------
// Painter — redraws every ticker frame
// ---------------------------------------------------------------------------
class _ConfettiPainter extends CustomPainter {
  final List<_Particle> particles;
  _ConfettiPainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final p in particles) {
      if (p.opacity <= 0) continue;
      paint.color = p.color.withValues(alpha: p.opacity);
      canvas.save();
      canvas.translate(p.x, p.y);
      canvas.rotate(p.rotation);

      switch (p.shape) {
        case 0: // circle
          canvas.drawCircle(Offset.zero, p.size * 0.5, paint);
          break;
        case 1: // rectangle
          canvas.drawRect(
            Rect.fromCenter(
                center: Offset.zero, width: p.size, height: p.size * 0.55),
            paint,
          );
          break;
        case 2: // ribbon
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                  center: Offset.zero,
                  width: p.size * 1.4,
                  height: p.size * 0.35),
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
  bool shouldRepaint(covariant _ConfettiPainter old) => true;
}

// ---------------------------------------------------------------------------
// CelebrationOverlay widget
// ---------------------------------------------------------------------------
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
  // Two tickers are needed — one for AnimationController, one for particles.
  // TickerProviderStateMixin (not Single) supports both.
  late final Ticker _ticker;
  late final AnimationController _bannerAnim;

  final List<_Particle> _particles = [];
  final Random _rng = Random();

  // Proper delta-time tracking
  Duration _lastTickDuration = Duration.zero;
  double _elapsed = 0.0; // accumulated seconds

  bool _bannerDismissing = false;
  Size _screenSize = Size.zero;

  // Adaptive quality: reduce particles on lower-end devices (small screens).
  // Determined once in initState after first build.
  int _spawnMultiplier = 1; // 1 = full, lower fraction via rate caps

  static const _colors = [
    Color(0xFFFF6B6B), Color(0xFFFFD93D), Color(0xFF6BCB77),
    Color(0xFF4D96FF), Color(0xFFFF8E71), Color(0xFFC084FC),
    Color(0xFFF472B6), Color(0xFF22D3EE), Color(0xFFFB923C),
    Color(0xFFA78BFA), Color(0xFF34D399), Color(0xFFF87171),
    Color(0xFF60A5FA), Color(0xFFFBBF24), Color(0xFFA3E635),
  ];

  // Max live particles — capped to keep GPU load reasonable on all devices
  static const int _maxParticles = 180;

  @override
  void initState() {
    super.initState();

    _bannerAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    )..forward();

    _ticker = createTicker(_onTick)..start();

    // Auto-dismiss after 3 s
    Future.delayed(const Duration(milliseconds: 3000), _startDismiss);

    // Detect screen size after first frame to set adaptive quality
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final size = MediaQuery.of(context).size;
      _screenSize = size;
      // Smallest Android phones (< 360dp wide) get reduced spawn rate
      _spawnMultiplier = size.width < 360 ? 0 : 1;
    });
  }

  void _startDismiss() {
    if (!mounted || _bannerDismissing) return;
    _bannerDismissing = true;
    _bannerAnim.reverse().then((_) {
      if (mounted) widget.onDismiss();
    });
  }

  void _spawnParticles(double screenW, double screenH) {
    if (_particles.length >= _maxParticles) return;

    // Burst schedule (seconds elapsed → particles per frame)
    final int baseRate = _elapsed < 0.12
        ? 20
        : _elapsed < 0.45
            ? 10
            : _elapsed < 0.9
                ? 5
                : _elapsed < 1.4
                    ? 2
                    : 0;

    // On very small screens reduce by half
    final int rate =
        _spawnMultiplier == 0 ? (baseRate ~/ 2).clamp(0, 12) : baseRate;

    final int canSpawn = (_maxParticles - _particles.length).clamp(0, rate);

    for (int i = 0; i < canSpawn; i++) {
      final fromSide = _rng.nextDouble() < 0.18;
      final double sx = fromSide
          ? (_rng.nextBool() ? -8.0 : screenW + 8.0)
          : _rng.nextDouble() * screenW;
      final double sy = fromSide
          ? _rng.nextDouble() * screenH * 0.35
          : -_rng.nextDouble() * 35;

      _particles.add(_Particle(
        x: sx,
        y: sy,
        vx: (_rng.nextDouble() - 0.5) * 180,
        vy: _rng.nextDouble() * 230 + 70,
        gravity: _rng.nextDouble() * 110 + 75,
        size: _rng.nextDouble() * 7 + 4,
        color: _colors[_rng.nextInt(_colors.length)],
        rotation: _rng.nextDouble() * pi * 2,
        rotationSpeed: (_rng.nextDouble() - 0.5) * 5.5,
        opacity: 1.0,
        // drag strictly < 1 so velocity decelerates correctly
        drag: _rng.nextDouble() * 0.14 + 0.76,
        shape: _rng.nextInt(4),
      ));
    }
  }

  void _onTick(Duration duration) {
    // Correct frame delta — difference from last tick, not total elapsed
    final double frameDt =
        ((duration - _lastTickDuration).inMicroseconds / 1_000_000.0)
            .clamp(0.0, 0.05); // cap at 50 ms to survive GC pauses
    _lastTickDuration = duration;
    _elapsed += frameDt;

    if (_screenSize == Size.zero || frameDt == 0) return;

    _spawnParticles(_screenSize.width, _screenSize.height);

    final double w = _screenSize.width;
    final double h = _screenSize.height;

    for (final p in _particles) {
      // Gravity
      p.vy += p.gravity * frameDt;

      // Exponential drag — physically correct, drag < 1 guaranteed
      final double dragFactor = pow(p.drag, frameDt * 60).toDouble();
      p.vx *= dragFactor;

      // Gentle sinusoidal wobble
      p.vx += sin(_elapsed * 2.8 + p.rotation) * 12 * frameDt;

      p.x += p.vx * frameDt;
      p.y += p.vy * frameDt;
      p.rotation += p.rotationSpeed * frameDt;

      // Wrap horizontally so particles re-enter from the other side
      // (looks nicer on wide tablets)
      if (p.x < -20) p.x = w + 10;
      if (p.x > w + 20) p.x = -10;

      // Fade near bottom
      if (p.y > h * 0.72) {
        final double dist = p.y - h * 0.72;
        p.opacity = (1.0 - dist / (h * 0.28)).clamp(0.0, 1.0);
      }

      // General late fade
      if (_elapsed > 2.2) p.opacity *= 0.96;
    }

    // Remove dead or off-screen particles
    _particles.removeWhere((p) => p.opacity <= 0.01 || p.y > h + 40);

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
    // Keep screen size in sync (handles rotation / fold events)
    final size = MediaQuery.of(context).size;
    if (_screenSize != size) _screenSize = size;

    final topPadding = MediaQuery.of(context).padding.top;

    final double bannerProgress = CurvedAnimation(
      parent: _bannerAnim,
      curve: Curves.easeOutBack,
    ).value;
    final double bannerY =
        -90.0 + (90.0 + topPadding + 14) * bannerProgress;
    final double bannerOpacity = _bannerAnim.value.clamp(0.0, 1.0);

    return IgnorePointer(
      child: Material(
        color: Colors.transparent,
        child: SizedBox.expand(
          child: Stack(
          children: [
            // Confetti layer — isolated in its own repaint boundary
            Positioned.fill(
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _ConfettiPainter(List.unmodifiable(_particles)),
                    size: _screenSize,
                  ),
                ),
              ),
            ),

            // Banner
            Positioned(
              top: bannerY,
              left: 16,
              right: 16,
              child: Opacity(
                opacity: bannerOpacity,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        widget.bannerColor,
                        widget.bannerColor.withValues(alpha: 0.85),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: widget.bannerColor.withValues(alpha: 0.32),
                        blurRadius: 20,
                        spreadRadius: 1,
                        offset: const Offset(0, 7),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.07),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          shape: BoxShape.circle,
                        ),
                        child:
                            Icon(widget.icon, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Text(
                          widget.message,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.1,
                            height: 1.35,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text('🎉', style: TextStyle(fontSize: 20)),
                    ],
                  ),
                ),
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Public helper — call from anywhere
// ---------------------------------------------------------------------------
void showCelebration(
  BuildContext context,
  String message, {
  IconData icon = Icons.check_circle_rounded,
  Color bannerColor = const Color(0xFF2E7D32),
}) {
  OverlayState? overlay;
  try {
    overlay = Navigator.of(context, rootNavigator: true).overlay;
  } catch (_) {
    overlay = Overlay.maybeOf(context);
  }
  if (overlay == null) return;

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => CelebrationOverlay(
      message: message,
      icon: icon,
      bannerColor: bannerColor,
      onDismiss: () {
        if (entry.mounted) entry.remove();
      },
    ),
  );
  overlay.insert(entry);
}
