import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// EXPERIMENT (nicht committen): the `perfect_loop` prototype's player,
/// embedded verbatim, so its loop can be judged inside this app.
///
/// The prototype loops the same file flawlessly on the same phone while this
/// app does not, and every difference inside our own player has been ruled out
/// one at a time. What is left is our player as a whole against theirs, and the
/// app around both. Dropping their `LoopPlayerView` in place of ours separates
/// those two: if the seam closes here, the difference is in our player; if it
/// stays, it is the environment — the feed's other players, the surface the
/// frames travel through, the engine under load.
///
/// Android only. The prototype's Apple side renders through an `AVPlayerLayer`
/// and has no bearing on the question, which is already answered there.
class PrototypeLoopPlayer extends StatelessWidget {
  /// Creates a view that loops [assetPath] with the prototype's player.
  const PrototypeLoopPlayer({
    required this.assetPath,
    this.pcmAssetPath,
    this.muted = false,
    super.key,
  });

  /// View type registered by `PrototypeLoopPlayerViewFactory`.
  static const viewType = 'divine_video_player/prototype_loop';

  /// Clip to loop, as a Flutter asset key.
  final String assetPath;

  /// Raw PCM to loop through an `AudioTrack` instead of the player, as the
  /// prototype's winning variant does. Null leaves the audio with ExoPlayer.
  final String? pcmAssetPath;

  /// Whether the clip starts silent.
  final bool muted;

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return const ColoredBox(color: Color(0xFF000000));
    }
    return AndroidView(
      viewType: viewType,
      creationParams: <String, dynamic>{
        'source': 'asset:$assetPath',
        'muted': muted,
        'audioRamp': true,
        'playlistLoop': false,
        'nativeAudioPath': pcmAssetPath,
        'dualPlayer': false,
      },
      creationParamsCodec: const StandardMessageCodec(),
    );
  }
}
