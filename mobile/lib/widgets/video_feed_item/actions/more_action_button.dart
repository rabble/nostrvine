// ABOUTME: Three-dots more action button for video feed overlay.
// ABOUTME: Opens the expanded metadata bottom sheet showing video details.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:models/models.dart';
import 'package:openvine/widgets/video_feed_item/metadata/metadata_expanded_sheet.dart';
import 'package:unified_logger/unified_logger.dart';

/// Three-dots more action button for the video overlay.
///
/// Opens the expanded metadata sheet showing title, stats, creator, tags,
/// collaborators, inspired-by, reposted-by, and sounds.
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
          MetadataExpandedSheet.show(context, video);
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
