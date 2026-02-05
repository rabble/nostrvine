// ABOUTME: Share action button for video feed overlay.
// ABOUTME: Displays share icon with label, shows share menu bottom sheet.

import 'package:flutter/material.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/utils/pause_aware_modals.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/circular_icon_button.dart';
import 'package:openvine/widgets/share_video_menu.dart';

/// Share action button with label for video overlay.
///
/// Shows a share icon that opens the share menu bottom sheet.
/// Video playback is automatically paused while the menu is open via
/// [showVideoPausingVineBottomSheet] and the overlay visibility provider.
class ShareActionButton extends StatelessWidget {
  const ShareActionButton({required this.video, super.key});

  final VideoEvent video;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          identifier: 'share_button',
          container: true,
          explicitChildNodes: true,
          button: true,
          label: 'Share video',
          child: CircularIconButton(
            onPressed: () {
              Log.info(
                '📤 Share button tapped for ${video.id}',
                name: 'ShareActionButton',
                category: LogCategory.ui,
              );
              _showShareMenu(context);
            },
            icon: const Icon(
              Icons.share_outlined,
              color: Colors.white,
              size: 32,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showShareMenu(BuildContext context) async {
    // Video pause/resume handled by overlay visibility provider
    await context.showVideoPausingVineBottomSheet<void>(
      builder: (context) => ShareVideoMenu(video: video),
    );
  }
}
