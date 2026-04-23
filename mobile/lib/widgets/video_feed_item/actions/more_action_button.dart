// ABOUTME: Down-caret more action button for video feed overlay.
// ABOUTME: Opens the expanded metadata bottom sheet showing video details.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_feed_item/metadata/metadata_expanded_sheet.dart';
import 'package:unified_logger/unified_logger.dart';

/// Down-caret more action button for the video overlay.
///
/// Opens the expanded metadata sheet showing title, stats, creator, tags,
/// collaborators, inspired-by, reposted-by, and sounds. Uses the same
/// [DivineIconName.caretDown] glyph as the feed-mode switcher in the
/// top-left corner of the feed, so "tap the caret to expand" reads the
/// same way across the screen.
///
/// Layout matches the Figma spec: 48x48 tap target (same as the sibling
/// like/comment/repost/share buttons), with a centered 40x40 rounded scrim
/// giving the distinct "menu" affordance. 4 px padding between the tap
/// target edge and the scrim.
class MoreActionButton extends StatelessWidget {
  const MoreActionButton({
    required this.video,
    this.onInteracted,
    super.key,
  });

  final VideoEvent video;
  final VoidCallback? onInteracted;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'more_button',
      container: true,
      explicitChildNodes: true,
      button: true,
      label: context.l10n.videoActionMoreOptions,
      child: IconButton(
        padding: const EdgeInsets.all(4),
        constraints: const BoxConstraints.tightFor(width: 48, height: 48),
        style: IconButton.styleFrom(
          highlightColor: VineTheme.transparent,
          splashFactory: NoSplash.splashFactory,
        ),
        onPressed: () {
          onInteracted?.call();
          Log.info(
            'More button tapped for ${video.id}',
            name: 'MoreActionButton',
            category: LogCategory.ui,
          );
          MetadataExpandedSheet.show(context, video);
        },
        icon: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: VineTheme.scrim30,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const DivineIcon(
            icon: DivineIconName.caretDown,
            color: VineTheme.whiteText,
          ),
        ),
      ),
    );
  }
}
