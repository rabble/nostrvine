// ABOUTME: Full-screen Instagram-style reaction "float" over the reel.
// ABOUTME: Tapping a reaction emits a stream of emoji that drift gently up from a
// ABOUTME: lower-center anchor, wiggle side-to-side, and fade near the top,
// ABOUTME: alongside a centered "Reaction sent" pill.
//
// Motion model (matches Instagram/TikTok DM reactions): a calm upward float —
// NOT a ballistic burst. Each emoji rises with a gentle ease-out, sways
// sinusoidally (bigger emoji wiggle wider), pops in, and fades out across the
// back half of its life. No gravity arc.
//
// Rendering: every particle is drawn in ONE batched `Canvas.drawRawAtlas` call
// from a single rasterized glyph image, with the transform/color buffers
// pre-allocated once and refilled in place each frame (zero per-frame
// allocation). Driven by one `AnimationController` as the `repaint:` Listenable
// inside a `RepaintBoundary`; it is one-shot and stops on completion, so the
// overlay never burns CPU/battery while idle (#5389).

import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/l10n/l10n.dart';

/// Tunable parameters for the reaction float. Grouped here so the motion can be
/// adjusted in one place rather than scattered as magic numbers.
abstract class _FloatConfig {
  /// Number of emoji emitted per tap.
  static const int count = 18;

  /// Total animation duration. Every particle has faded out by the end, after
  /// which the host removes the overlay.
  static const Duration duration = Duration(milliseconds: 2700);

  static double get durationSeconds =>
      duration.inMicroseconds / Duration.microsecondsPerSecond;

  /// Font size the emoji is rasterized at; particles only ever downscale this.
  static const double glyphFontSize = 120;

  /// Vertical anchor for the emission origin, as a fraction of overlay height.
  static const double originYFraction = 0.72;

  /// Spawn spread around the origin, as a fraction of overlay width/height.
  /// A near-full-width horizontal band keeps emoji from bunching up — the
  /// Instagram reference spans ~80% of the screen width.
  static const double spawnSpreadXFraction = 0.40;
  static const double spawnSpreadYFraction = 0.05;

  /// How far up an emoji travels, as a fraction of overlay height (randomized).
  static const double riseFractionMin = 0.52;
  static const double riseFractionMax = 0.66;

  /// Target on-screen draw size range for an emoji (logical px).
  static const double sizeMin = 24;
  static const double sizeMax = 48;

  /// Window over which emissions are staggered (seconds), so the burst reads as
  /// a stream rather than a single instantaneous batch.
  static const double staggerWindow = 0.40;

  /// Sine-wiggle amplitude as a multiple of the emoji's size (bigger emoji
  /// wiggle wider) and the number of sway cycles over a lifetime.
  static const double wiggleAmpMultMin = 0.8;
  static const double wiggleAmpMultMax = 1.3;
  static const double wiggleFreqMin = 0.7;
  static const double wiggleFreqMax = 1.5;

  /// Subtle tilt half-extent (radians) synced to the wiggle.
  static const double tiltMax = 0.12;

  /// Normalized-life envelope breakpoints (per particle).
  static const double fadeInFraction = 0.08;
  static const double holdUntilFraction = 0.5;
  static const double scaleInFraction = 0.12;
}

/// Opacity envelope for a floating emoji over its normalized life [lp] (0 at
/// birth, 1 at death): quick fade in, hold, then a long fade out across the back
/// half so it dims as it nears the top. Always within `[0, 1]`.
@visibleForTesting
double reactionFloatOpacity(double lp) {
  if (lp <= 0 || lp >= 1) return 0;
  if (lp < _FloatConfig.fadeInFraction) {
    return lp / _FloatConfig.fadeInFraction;
  }
  if (lp < _FloatConfig.holdUntilFraction) return 1;
  final fade =
      (lp - _FloatConfig.holdUntilFraction) /
      (1 - _FloatConfig.holdUntilFraction);
  return (1 - fade).clamp(0.0, 1.0);
}

/// Scale-in (pop) multiplier over normalized life [lp]: eases 0→1 over the first
/// [_FloatConfig.scaleInFraction], then holds at 1. Emoji never shrink out —
/// opacity carries the disappearance.
@visibleForTesting
double reactionFloatScaleIn(double lp) {
  if (lp <= 0) return 0;
  if (lp >= _FloatConfig.scaleInFraction) return 1;
  return Curves.easeOut.transform(lp / _FloatConfig.scaleInFraction);
}

/// Eased vertical-rise fraction (0→1) over normalized life [lp]. A gentle
/// ease-out so the emoji drifts up at a near-constant pace and settles near the
/// top rather than launching — the opposite of a ballistic burst.
@visibleForTesting
double reactionFloatRise(double lp) =>
    Curves.easeOutSine.transform(lp.clamp(0.0, 1.0));

/// Horizontal sine-wiggle offset (logical px) at normalized life [lp].
@visibleForTesting
double reactionFloatWiggle(
  double amplitude,
  double frequency,
  double phase,
  double lp,
) => amplitude * sin(frequency * 2 * pi * lp + phase);

/// One-shot full-screen reaction float over the player. [_FloatConfig.count]
/// emoji drift up from a lower-center anchor while a centered "Reaction sent"
/// pill fades in and out.
///
/// Rebuild with a fresh `key` (e.g. `ValueKey(nonce)`) to replay on each tap.
class ReactionOverlay extends StatefulWidget {
  /// Creates a reaction overlay for [emoji]. [onComplete] fires when the
  /// animation ends so the host can remove the overlay.
  const ReactionOverlay({
    required this.emoji,
    this.onComplete,
    this.randomSeed,
    super.key,
  });

  /// The emoji to animate.
  final String emoji;

  /// Called once the animation completes.
  final VoidCallback? onComplete;

  /// Optional seed for deterministic particle generation in tests.
  @visibleForTesting
  final int? randomSeed;

  @override
  State<ReactionOverlay> createState() => _ReactionOverlayState();
}

class _ReactionOverlayState extends State<ReactionOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pillOpacity;
  late final List<_FloatParticle> _particles;

  /// Pre-allocated, reused-every-frame buffers for the batched draw call.
  /// `_rstTransforms` (scale/rotation/translate) and `_colors` (per-sprite
  /// alpha) are refilled in place each paint; `_rects` is constant (every
  /// particle samples the whole glyph) and filled once.
  late final Float32List _rstTransforms;
  late final Int32List _colors;
  Float32List? _rects;

  /// The emoji rasterized once to a GPU image; null until prepared.
  ui.Image? _emojiImage;
  double _devicePixelRatio = 1;
  bool _prepared = false;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: _FloatConfig.duration)
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) widget.onComplete?.call();
          })
          ..forward();

    // The "Reaction sent" pill: fade in, hold, fade out within the first ~1.5s
    // (it need not linger for the full float).
    _pillOpacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 7,
      ),
      TweenSequenceItem(tween: ConstantTween(1), weight: 48),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 12,
      ),
      TweenSequenceItem(tween: ConstantTween(0), weight: 33),
    ]).animate(_controller);

    final random = widget.randomSeed != null
        ? Random(widget.randomSeed)
        : Random();
    _particles = List.generate(
      _FloatConfig.count,
      (_) => _FloatParticle.random(random),
    );
    _rstTransforms = Float32List(_FloatConfig.count * 4);
    _colors = Int32List(_FloatConfig.count);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Rasterize the emoji once (needs the device pixel ratio from context).
    // Runs before the first build, so the first frame paints the image.
    if (_prepared) return;
    _prepared = true;
    _devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    _prepareEmojiImage();
  }

  void _prepareEmojiImage() {
    final textPainter = TextPainter(
      text: TextSpan(
        text: widget.emoji,
        style: const TextStyle(fontSize: _FloatConfig.glyphFontSize),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final logicalSize = textPainter.size;
    // Particles only downscale the glyph, so device-pixel resolution is enough
    // headroom — no supersampling needed.
    final pixelWidth = (logicalSize.width * _devicePixelRatio).ceil();
    final pixelHeight = (logicalSize.height * _devicePixelRatio).ceil();
    if (pixelWidth <= 0 || pixelHeight <= 0) return;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(_devicePixelRatio);
    textPainter.paint(canvas, Offset.zero);
    final picture = recorder.endRecording();
    _emojiImage = picture.toImageSync(pixelWidth, pixelHeight);
    picture.dispose();

    // Every particle samples the whole glyph, so the source rects are constant.
    final rects = Float32List(_FloatConfig.count * 4);
    for (var i = 0; i < _FloatConfig.count; i++) {
      rects[i * 4 + 2] = pixelWidth.toDouble();
      rects[i * 4 + 3] = pixelHeight.toDouble();
    }
    _rects = rects;
  }

  @override
  void dispose() {
    _emojiImage?.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _FloatPainter(
                  image: _emojiImage,
                  devicePixelRatio: _devicePixelRatio,
                  progress: _controller,
                  particles: _particles,
                  rstTransforms: _rstTransforms,
                  rects: _rects,
                  colors: _colors,
                ),
              ),
            ),
            Positioned.fill(
              child: FadeTransition(
                opacity: _pillOpacity,
                child: const Align(
                  alignment: Alignment(0, -0.1),
                  child: _ReactionSentPill(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Paints every floating emoji from a single rasterized [image] in ONE batched
/// `drawRawAtlas` call. Repaints on every [progress] tick without rebuilding any
/// widget; the transform/color buffers are refilled in place (no allocation).
class _FloatPainter extends CustomPainter {
  _FloatPainter({
    required this.image,
    required this.devicePixelRatio,
    required this.progress,
    required this.particles,
    required this.rstTransforms,
    required this.rects,
    required this.colors,
  }) : super(repaint: progress);

  final ui.Image? image;
  final double devicePixelRatio;
  final Animation<double> progress;
  final List<_FloatParticle> particles;
  final Float32List rstTransforms;
  final Float32List? rects;
  final Int32List colors;

  static final Paint _paint = Paint()
    ..filterQuality = FilterQuality.medium
    ..isAntiAlias = true;

  @override
  void paint(Canvas canvas, Size size) {
    final glyph = image;
    final rectBuffer = rects;
    if (glyph == null || rectBuffer == null) return;

    final elapsed = progress.value * _FloatConfig.durationSeconds;
    final origin = Offset(
      size.width / 2,
      size.height * _FloatConfig.originYFraction,
    );
    final halfW = glyph.width / 2;
    final halfH = glyph.height / 2;

    for (var i = 0; i < particles.length; i++) {
      final p = particles[i];
      final base = i * 4;
      final localT = elapsed - p.birthTime;
      final life = _FloatConfig.durationSeconds - p.birthTime;
      final lp = life <= 0 ? 1.0 : (localT / life).clamp(0.0, 1.0);
      final opacity = localT < 0 ? 0.0 : reactionFloatOpacity(lp);

      if (opacity <= 0) {
        // Not born yet or already gone: contribute an invisible sprite.
        colors[i] = 0;
        rstTransforms[base] = 0;
        rstTransforms[base + 1] = 0;
        rstTransforms[base + 2] = 0;
        rstTransforms[base + 3] = 0;
        continue;
      }

      final cx =
          origin.dx +
          p.spawnFracX * _FloatConfig.spawnSpreadXFraction * size.width +
          reactionFloatWiggle(
            p.wiggleAmplitude,
            p.wiggleFrequency,
            p.wigglePhase,
            lp,
          );
      final cy =
          origin.dy +
          p.spawnFracY * _FloatConfig.spawnSpreadYFraction * size.height -
          p.riseFraction * size.height * reactionFloatRise(lp);

      // Atlas scale maps glyph pixels → logical canvas; dividing by the device
      // pixel ratio undoes the raster oversampling.
      final s =
          (p.sizePx / _FloatConfig.glyphFontSize) /
          devicePixelRatio *
          reactionFloatScaleIn(lp);
      final rot =
          p.tiltAmplitude *
          sin(p.wiggleFrequency * 2 * pi * lp + p.wigglePhase);
      final scos = s * cos(rot);
      final ssin = s * sin(rot);

      rstTransforms[base] = scos;
      rstTransforms[base + 1] = ssin;
      rstTransforms[base + 2] = cx - (scos * halfW - ssin * halfH);
      rstTransforms[base + 3] = cy - (ssin * halfW + scos * halfH);

      // Pack alpha into all four channels so `modulate` scales the premultiplied
      // glyph uniformly — a clean fade with no edge halo.
      final a = (opacity * 255).round().clamp(0, 255);
      colors[i] = (a << 24) | (a << 16) | (a << 8) | a;
    }

    canvas.drawRawAtlas(
      glyph,
      rstTransforms,
      rectBuffer,
      colors,
      BlendMode.modulate,
      Offset.zero & size,
      _paint,
    );
  }

  @override
  bool shouldRepaint(_FloatPainter oldDelegate) =>
      image != oldDelegate.image ||
      rects != oldDelegate.rects ||
      devicePixelRatio != oldDelegate.devicePixelRatio;
}

/// One floating emoji: an upward drift with a sinusoidal wiggle. Immutable after
/// spawn; all motion is a pure function of elapsed time.
class _FloatParticle {
  _FloatParticle({
    required this.birthTime,
    required this.spawnFracX,
    required this.spawnFracY,
    required this.riseFraction,
    required this.sizePx,
    required this.wiggleAmplitude,
    required this.wiggleFrequency,
    required this.wigglePhase,
    required this.tiltAmplitude,
  });

  factory _FloatParticle.random(Random r) {
    final sizePx =
        _FloatConfig.sizeMin +
        r.nextDouble() * (_FloatConfig.sizeMax - _FloatConfig.sizeMin);
    return _FloatParticle(
      birthTime: r.nextDouble() * _FloatConfig.staggerWindow,
      spawnFracX: r.nextDouble() * 2 - 1,
      spawnFracY: r.nextDouble() * 2 - 1,
      riseFraction:
          _FloatConfig.riseFractionMin +
          r.nextDouble() *
              (_FloatConfig.riseFractionMax - _FloatConfig.riseFractionMin),
      sizePx: sizePx,
      // Bigger emoji wiggle wider.
      wiggleAmplitude:
          sizePx *
          (_FloatConfig.wiggleAmpMultMin +
              r.nextDouble() *
                  (_FloatConfig.wiggleAmpMultMax -
                      _FloatConfig.wiggleAmpMultMin)),
      wiggleFrequency:
          _FloatConfig.wiggleFreqMin +
          r.nextDouble() *
              (_FloatConfig.wiggleFreqMax - _FloatConfig.wiggleFreqMin),
      wigglePhase: r.nextDouble() * 2 * pi,
      tiltAmplitude: (r.nextDouble() * 2 - 1) * _FloatConfig.tiltMax,
    );
  }

  final double birthTime;
  final double spawnFracX;
  final double spawnFracY;
  final double riseFraction;
  final double sizePx;
  final double wiggleAmplitude;
  final double wiggleFrequency;
  final double wigglePhase;
  final double tiltAmplitude;
}

/// The centered, translucent "Reaction sent" confirmation pill, styled from the
/// design system (mirrors `FeedPlaybackTogglesPill`).
class _ReactionSentPill extends StatelessWidget {
  const _ReactionSentPill();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(22)),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: VineTheme.scrim70,
            borderRadius: BorderRadius.all(Radius.circular(22)),
            boxShadow: [
              BoxShadow(color: VineTheme.shadow25, blurRadius: 4),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text(
              context.l10n.dmReelReactionSentPill,
              style: VineTheme.labelLargeFont(),
            ),
          ),
        ),
      ),
    );
  }
}
