// ABOUTME: The paused-state composition rendered above a paused video:
// ABOUTME: the playback toggles pill above the large play icon. Shared
// ABOUTME: between the native (media_kit) and web (video_player) overlays.

import 'package:flutter/material.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_feed_item/center_playback_control.dart';
import 'package:openvine/widgets/video_feed_item/feed_playback_toggles_pill.dart';

/// The paused-state stack: the playback-toggles pill
/// ([FeedPlaybackTogglesPill]) above the large play icon. The pill
/// reads its own state from app-wide cubits/providers, so this widget
/// takes no callbacks.
class PausedAffordance extends StatelessWidget {
  const PausedAffordance({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 16,
        children: [
          const FeedPlaybackTogglesPill(),
          IgnorePointer(
            child: CenterPlaybackControl(
              state: CenterPlaybackControlState.play,
              semanticsLabel: context.l10n.videoPlayerPlayVideo,
            ),
          ),
        ],
      ),
    );
  }
}
