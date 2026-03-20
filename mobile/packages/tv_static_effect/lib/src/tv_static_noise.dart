// ABOUTME: Animated TV static noise effect using a fragment shader.
// ABOUTME: Mimics old television "no signal" snow for permission screens.

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// A function that creates a [CustomPainter] for the given [time] and
/// [opacity].
@visibleForTesting
typedef PainterFactory =
    CustomPainter Function({
      required double time,
      required double opacity,
    });

/// A function that asynchronously loads a [PainterFactory].
@visibleForTesting
typedef ShaderLoader = Future<PainterFactory> Function();

/// Renders an animated TV static / snow noise effect using a fragment shader.
///
/// The effect resembles an old CRT television with no signal.
/// Uses a GLSL fragment shader and animates at ~12 fps internally
/// for an authentic retro feel.
class TvStaticNoise extends StatefulWidget {
  /// Creates a [TvStaticNoise] widget.
  const TvStaticNoise({
    super.key,
    this.opacity = 0.07,
    @visibleForTesting this.shaderLoader,
  });

  /// Overall opacity of the noise layer.
  final double opacity;

  /// Optional shader loader override for testing.
  final ShaderLoader? shaderLoader;

  @override
  State<TvStaticNoise> createState() => _TvStaticNoiseState();
}

class _TvStaticNoiseState extends State<TvStaticNoise>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _elapsed = 0;
  PainterFactory? _createPainter;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    unawaited(_ticker.start());
    unawaited(_loadShader());
  }

  Future<void> _loadShader() async {
    final loader = widget.shaderLoader ?? _defaultShaderLoader;
    _createPainter = await loader();
    if (mounted) {
      setState(() => _loaded = true);
    }
  }

  void _onTick(Duration elapsed) {
    setState(() => _elapsed = elapsed.inMilliseconds / 1000.0);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _createPainter == null) {
      return const SizedBox.shrink();
    }

    return RepaintBoundary(
      child: CustomPaint(
        painter: _createPainter!(time: _elapsed, opacity: widget.opacity),
        child: const SizedBox.expand(),
      ),
    );
  }
}

// coverage:ignore-start

/// Default shader loader that loads the real GLSL fragment shader.
Future<PainterFactory> _defaultShaderLoader() async {
  final program = await ui.FragmentProgram.fromAsset(
    'packages/tv_static_effect/shaders/tv_static.frag',
  );
  // Explicit types required — Dart does not infer named parameter types
  // from the return type of the enclosing function.
  // ignore: avoid_types_on_closure_parameters
  return ({required double time, required double opacity}) =>
      _TvStaticPainter(program: program, time: time, opacity: opacity);
}

class _TvStaticPainter extends CustomPainter {
  _TvStaticPainter({
    required this.program,
    required this.time,
    required this.opacity,
  });

  final ui.FragmentProgram program;
  final double time;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final shader = program.fragmentShader()
      ..setFloat(0, size.width) // uSize.x
      ..setFloat(1, size.height) // uSize.y
      ..setFloat(2, time) // uTime
      ..setFloat(3, opacity); // uOpacity

    canvas.drawRect(
      Offset.zero & size,
      Paint()..shader = shader,
    );
  }

  @override
  bool shouldRepaint(_TvStaticPainter oldDelegate) =>
      oldDelegate.time != time || oldDelegate.opacity != opacity;
}

// coverage:ignore-end
