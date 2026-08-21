import 'dart:async';
import 'dart:io';

import 'package:divine_video_player/src/divine_video_player_controller.dart';
import 'package:divine_video_player/src/divine_video_player_widget.dart';
import 'package:divine_video_player/src/video_clip.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// EXPERIMENT (nicht committen): our own player, alone on a bare screen,
/// looping the same fixture the prototype's player loops there.
///
/// The prototype's player is clean in this app, so the environment is not the
/// cause and ours is. This is the other half of that comparison: same screen,
/// same file, same single instance, our player. Whatever separates the two is
/// then inside the player itself, with the feed, the placeholders and the other
/// decoders all out of the picture.
class BareLoopPlayer extends StatefulWidget {
  /// Creates a bare screen looping [assetPath] with the app's own player.
  const BareLoopPlayer({required this.assetPath, super.key});

  /// Clip to loop, as a Flutter asset key.
  final String assetPath;

  @override
  State<BareLoopPlayer> createState() => _BareLoopPlayerState();
}

class _BareLoopPlayerState extends State<BareLoopPlayer> {
  DivineVideoPlayerController? _controller;
  Object? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    try {
      // Matches how the feed builds its controllers, so the comparison is
      // against the real thing rather than a friendlier configuration.
      final controller = DivineVideoPlayerController(
        useTexture: true,
        useLegacySurface: true,
      );
      await controller.initialize();
      final path = await _extract(widget.assetPath);
      await controller.setSource(
        VideoClip.file(path, trimToCommonTrackEnd: true),
      );
      await controller.setLooping(looping: true);
      await controller.play();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
    } on Object catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  static Future<String> _extract(String asset) async {
    final (data, dir) = await (
      rootBundle.load(asset),
      getTemporaryDirectory(),
    ).wait;
    final file = File('${dir.path}/bare_loop/${asset.split('/').last}');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
    return file.path;
  }

  @override
  void dispose() {
    unawaited(_controller?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (_error != null) {
      return Center(
        child: Text(
          '$_error',
          style: const TextStyle(color: Color(0xFFFFB0B0), fontSize: 12),
        ),
      );
    }
    if (controller == null) return const SizedBox.shrink();
    return DivineVideoPlayer(controller: controller);
  }
}
