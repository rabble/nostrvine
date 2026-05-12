import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:openvine/providers/subtitle_providers.dart';
import 'package:openvine/widgets/video_feed_item/subtitle_overlay.dart';
import 'package:video_player/video_player.dart';

/// Renders subtitles for a [VideoPlayerController]-backed video.
class VideoPlayerSubtitleLayer extends ConsumerWidget {
  const VideoPlayerSubtitleLayer({
    required this.video,
    required this.controller,
    super.key,
  });

  final VideoEvent video;
  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subtitlesVisible = ref.watch(subtitleVisibilityProvider);
    if (!subtitlesVisible) return const SizedBox.shrink();

    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        if (!value.isInitialized) {
          return const SizedBox.shrink();
        }

        return SubtitleCuePositionPill(
          video: video,
          positionMs: value.position.inMilliseconds,
        );
      },
    );
  }
}
