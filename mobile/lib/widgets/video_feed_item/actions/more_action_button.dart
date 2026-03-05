// ABOUTME: Three-dots more action button for video feed overlay.
// ABOUTME: Opens bottom sheet with Report, Mute, Block, View JSON, Copy Event ID.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:models/models.dart';

/// Three-dots more action button for the video overlay.
///
/// Opens a bottom sheet with moderation and developer actions:
/// Report, Mute, Block, View Nostr event JSON, Copy Nostr event ID.
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
    );
  }
}
