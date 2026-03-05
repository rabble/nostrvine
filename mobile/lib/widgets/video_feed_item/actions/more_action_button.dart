// ABOUTME: Three-dots more action button for video feed overlay.
// ABOUTME: Opens unified share sheet with more actions (report, copy, etc.).

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:models/models.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/video_feed_item/actions/share_action_button.dart';

/// Three-dots more action button for the video overlay.
///
/// Opens the unified share sheet which contains moderation and developer
/// actions: Report, Copy Link, Share via, Event JSON, Event ID.
class MoreActionButton extends StatelessWidget {
  const MoreActionButton({required this.video, super.key});

  final VideoEvent video;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'more_button',
      container: true,
      explicitChildNodes: true,
      button: true,
      label: 'More options',
      child: GestureDetector(
        onTap: () {
          Log.info(
            'More button tapped for ${video.id}',
            name: 'MoreActionButton',
            category: LogCategory.ui,
          );
          ShareActionButton.showShareSheet(context, video);
        },
        child: Container(
          width: 40,
          height: 40,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: VineTheme.scrim30,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const DivineIcon(
            icon: DivineIconName.dotsThree,
            color: VineTheme.whiteText,
          ),
        ),
      ),
    );
  }
}
