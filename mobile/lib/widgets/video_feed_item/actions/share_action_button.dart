// ABOUTME: Share action button for video feed overlay.
// ABOUTME: Displays share icon, shows share menu bottom sheet.

import 'package:flutter/material.dart';
import 'package:models/models.dart';
import 'package:openvine/utils/pause_aware_modals.dart';
import 'package:openvine/widgets/share_video_menu.dart';
import 'package:openvine/widgets/video_feed_item/actions/video_action_button.dart';

/// Share action button for video overlay.
///
/// Shows a share icon that opens the share menu bottom sheet.
/// Video playback is automatically paused while the menu is open via
/// [showVideoPausingVineBottomSheet] and the overlay visibility provider.
class ShareActionButton extends StatelessWidget {
  const ShareActionButton({required this.video, super.key});

  final VideoEvent video;

  @override
  Widget build(BuildContext context) {
    return VideoActionButton(
      iconAsset: 'assets/icon/content-controls/share.svg',
      semanticIdentifier: 'share_button',
      semanticLabel: 'Share video',
      onPressed: () {
        context.showVideoPausingVineBottomSheet<void>(
          builder: (context) => ShareVideoMenu(video: video),
        );
      },
    );
  }
}
