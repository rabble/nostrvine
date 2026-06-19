// ABOUTME: Full-screen TikTok/Instagram-style reaction animation over the reel.
// ABOUTME: A big emoji springs in at screen center (overshoot), holds, floats
// ABOUTME: up and fades, garnished by a few floating-particle copies.

import 'dart:math';

import 'package:flutter/material.dart';

/// One-shot reaction animation centered over the player. The hero emoji springs
/// in with an overshoot (`easeOutBack`), holds, then floats up ~70px while
/// fading; a light layer of floating copies sways upward alongside it.
///
/// Rebuild with a fresh `key` (e.g. `ValueKey(nonce)`) to replay on each tap.
class ReactionOverlay extends StatefulWidget {
  /// Creates a reaction overlay for [emoji]. [onComplete] fires when the
  /// animation ends so the host can remove the overlay.
  const ReactionOverlay({required this.emoji, this.onComplete, super.key});

  /// The emoji to animate.
  final String emoji;

  /// Called once the animation completes.
  final VoidCallback? onComplete;

  @override
  State<ReactionOverlay> createState() => _ReactionOverlayState();
}

class _ReactionOverlayState extends State<ReactionOverlay>
    with SingleTickerProviderStateMixin {
  static const Duration _duration = Duration(milliseconds: 1100);
  static const int _particleCount = 5;

  late final AnimationController _controller;
  late final Animation<double> _heroScale;
  late final Animation<double> _heroGrow;
  late final Animation<double> _heroOpacity;
  late final Animation<double> _heroY;
  late final List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _duration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) widget.onComplete?.call();
      })
      ..forward();

    // Spring in with a single ~27.5% overshoot, settle to 1.0.
    _heroScale = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.35, curve: Curves.easeOutBack),
      ),
    );
    // Gentle extra grow as it floats away.
    _heroGrow = Tween<double>(begin: 1, end: 1.08).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.65, 1)),
    );
    _heroOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 1), weight: 15),
      TweenSequenceItem(tween: ConstantTween(1), weight: 50),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 35,
      ),
    ]).animate(_controller);
    _heroY = Tween<double>(begin: 0, end: -70).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.65, 1, curve: Curves.easeOut),
      ),
    );

    final random = Random();
    _particles = List.generate(
      _particleCount,
      (_) => _Particle.random(random),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final cx = size.width / 2;
    final cy = size.height / 2;

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          return Stack(
            children: [
              // Secondary floating-particle layer (garnish).
              for (final p in _particles)
                Positioned(
                  left:
                      cx +
                      p.startX +
                      p.amplitude * sin(p.frequency * t * 2 * pi + p.phase) -
                      p.size / 2,
                  top: cy - p.riseHeight * t - p.size / 2,
                  child: Opacity(
                    opacity: sin(t * pi).clamp(0.0, 1.0),
                    child: Transform.rotate(
                      angle: 0.035 * sin(p.frequency * t * 2 * pi),
                      child: Transform.scale(
                        scale: p.scaleAt(t),
                        child: Text(
                          widget.emoji,
                          style: TextStyle(fontSize: p.size * 0.85),
                        ),
                      ),
                    ),
                  ),
                ),

              // Primary hero pop at screen center.
              Positioned(
                left: cx - 70,
                top: cy - 70 + _heroY.value,
                child: Opacity(
                  opacity: _heroOpacity.value.clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: _heroScale.value * _heroGrow.value,
                    child: SizedBox(
                      width: 140,
                      height: 140,
                      child: Center(
                        child: Text(
                          widget.emoji,
                          style: const TextStyle(fontSize: 120),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Particle {
  _Particle({
    required this.startX,
    required this.size,
    required this.scale,
    required this.riseHeight,
    required this.amplitude,
    required this.frequency,
    required this.phase,
  });

  factory _Particle.random(Random r) => _Particle(
    startX: (r.nextDouble() - 0.5) * 60, // ±30px
    size: 44,
    scale: 0.6 + r.nextDouble() * 0.4, // 0.6–1.0
    riseHeight: 180 + r.nextDouble() * 140, // 180–320
    amplitude: 12 + r.nextDouble() * 22, // 12–34
    frequency: 1.0 + r.nextDouble() * 1.5, // 1.0–2.5
    phase: r.nextDouble() * 2 * pi,
  );

  final double startX;
  final double size;
  final double scale;
  final double riseHeight;
  final double amplitude;
  final double frequency;
  final double phase;

  /// Pop in (easeOutBack, first 20%), hold, then shrink out (last 25%).
  double scaleAt(double t) {
    if (t < 0.20) return scale * Curves.easeOutBack.transform(t / 0.20);
    if (t > 0.75) return scale * (1 - (t - 0.75) / 0.25);
    return scale;
  }
}
