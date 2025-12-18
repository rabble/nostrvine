// ABOUTME: Share action button for video feed overlay.
// ABOUTME: Displays share icon with label, shows share menu bottom sheet.

import 'package:flutter/material.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/circular_icon_button.dart';
import 'package:openvine/widgets/share_video_menu.dart';

/// Share action button with label for video overlay.
///
/// Shows a share icon that opens the share menu bottom sheet.
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
        const SizedBox(height: 0),
        const Text(
          'Share',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(offset: Offset(0, 0), blurRadius: 6, color: Colors.black),
              Shadow(offset: Offset(1, 1), blurRadius: 3, color: Colors.black),
            ],
          ),
        ),
      ],
    );
  }

  void _showShareMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ShareVideoMenu(video: video),
    );
  }
}
