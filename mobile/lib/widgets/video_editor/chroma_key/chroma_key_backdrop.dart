// ABOUTME: Renders what a chroma key puts behind the subject in the preview:
// ABOUTME: a checkerboard, a colour, an image, or a looping library video.

import 'dart:async';
import 'dart:io';

import 'package:divine_ui/divine_ui.dart';
import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter/material.dart';
import 'package:openvine/models/video_editor/clip_chroma_key.dart';
import 'package:unified_logger/unified_logger.dart';

/// The backdrop for a keyed clip, matching [chromaKey]'s background type.
///
/// Composited *behind* the keyed video rather than sampled inside the shader,
/// which keeps one shader for all four background types.
class ChromaKeyBackdrop extends StatelessWidget {
  const ChromaKeyBackdrop({
    required this.chromaKey,
    this.restarts,
    super.key,
  });

  final ClipChromaKey chromaKey;

  /// Fires whenever the clip in front loops back to its start.
  ///
  /// A video backdrop seeks to zero on each event, which is what keeps the two
  /// independent players from drifting apart over a long session — and matches
  /// the export, where the backdrop starts at the clip's first frame.
  final Stream<void>? restarts;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = chromaKey.key.backgroundColor;
    // `EditorLayerImage.file` is the plugin's conditionally-imported `File`,
    // not `dart:io`'s, so go through the path rather than the object.
    final imagePath = chromaKey.key.backgroundImage?.file?.path;
    final videoPath = chromaKey.backgroundVideoPath;

    return switch (chromaKey.backgroundType) {
      ClipChromaKeyBackgroundType.color when backgroundColor != null =>
        ColoredBox(color: backgroundColor),
      ClipChromaKeyBackgroundType.image when imagePath != null =>
        _ImageBackdrop(path: imagePath),
      ClipChromaKeyBackgroundType.video when videoPath != null =>
        _VideoBackdrop(path: videoPath, restarts: restarts),
      // Transparent — and the degenerate cases where a background type's own
      // source went missing (a deleted library clip, a pruned cache file),
      // which read as "no backdrop" rather than as a crash.
      _ => const ChromaKeyTransparencyCheckerboard(),
    };
  }
}

/// A still image backdrop, stretched to the frame the way the renderer
/// stretches the key's background image.
class _ImageBackdrop extends StatelessWidget {
  const _ImageBackdrop({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return Image.file(
      File(path),
      fit: BoxFit.fill,
      // A missing file degrades to the checkerboard: the user still sees the
      // matte, which is the point of the preview.
      errorBuilder: (_, _, _) => const ChromaKeyTransparencyCheckerboard(),
    );
  }
}

/// A looping, muted library video playing behind the subject.
///
/// It runs on its own native clock — two players cannot share one — but seeks
/// back to zero whenever the clip in front loops, so the pair re-aligns every
/// cycle instead of drifting apart. That mirrors the export, where the backdrop
/// starts at the clip's first frame and tiles from there.
class _VideoBackdrop extends StatefulWidget {
  const _VideoBackdrop({required this.path, this.restarts});

  final String path;
  final Stream<void>? restarts;

  @override
  State<_VideoBackdrop> createState() => _VideoBackdropState();
}

class _VideoBackdropState extends State<_VideoBackdrop> {
  DivineVideoPlayerController? _controller;
  StreamSubscription<void>? _restartSubscription;

  @override
  void initState() {
    super.initState();
    _listenForRestarts();
    unawaited(_initialize());
  }

  void _listenForRestarts() {
    unawaited(_restartSubscription?.cancel());
    _restartSubscription = widget.restarts?.listen((_) {
      unawaited(_controller?.seekTo(Duration.zero));
    });
  }

  @override
  void didUpdateWidget(_VideoBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.restarts != widget.restarts) _listenForRestarts();
    if (oldWidget.path != widget.path) {
      final previous = _controller;
      setState(() => _controller = null);
      unawaited(previous?.dispose());
      unawaited(_initialize());
    }
  }

  Future<void> _initialize() async {
    // Hold the controller locally and re-check `mounted` after every await: a
    // path change or a dispose can supersede this load mid-flight, and the
    // half-built controller has to be torn down rather than leaked.
    // Opt out of the one-video-at-a-time rule: this is a layer of the clip in
    // front, not a video of its own, so the two must run together instead of
    // stopping each other.
    final controller = DivineVideoPlayerController(
      useTexture: true,
      exclusivePlayback: false,
    );
    try {
      await controller.initialize();
      if (!mounted) return await controller.dispose();
      await controller.setSource(VideoClip.file(widget.path, volume: 0));
      if (!mounted) return await controller.dispose();
      await controller.setLooping(looping: true);
      if (!mounted) return await controller.dispose();
      await controller.play();
      if (!mounted) return await controller.dispose();
      setState(() => _controller = controller);
    } catch (error, stackTrace) {
      Log.error(
        'Chroma-key backdrop video failed to load; showing no backdrop',
        name: 'ChromaKeyBackdrop',
        error: error,
        stackTrace: stackTrace,
        category: LogCategory.video,
      );
      await controller.dispose();
    }
  }

  @override
  void dispose() {
    unawaited(_restartSubscription?.cancel());
    unawaited(_controller?.dispose());
    _controller = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) return const ChromaKeyTransparencyCheckerboard();
    // The player expands to its box, which is the same "stretched to fill the
    // frame" placement the renderer gives a full-canvas background layer.
    return DivineVideoPlayer(controller: controller);
  }
}

/// The standard "nothing behind the subject" checkerboard.
class ChromaKeyTransparencyCheckerboard extends StatelessWidget {
  const ChromaKeyTransparencyCheckerboard({super.key});

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(painter: _CheckerboardPainter(), size: .infinite);
  }
}

class _CheckerboardPainter extends CustomPainter {
  const _CheckerboardPainter();

  static const _cell = 12.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = VineTheme.surfaceContainer,
    );
    final darkPaint = Paint()..color = VineTheme.surfaceContainerHigh;
    final columns = (size.width / _cell).ceil();
    final rows = (size.height / _cell).ceil();
    for (var row = 0; row < rows; row++) {
      for (var column = row.isEven ? 0 : 1; column < columns; column += 2) {
        canvas.drawRect(
          Rect.fromLTWH(column * _cell, row * _cell, _cell, _cell),
          darkPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_CheckerboardPainter oldDelegate) => false;
}
