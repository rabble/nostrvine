// ABOUTME: Custom header widget for video metadata screen with
// ABOUTME: configurable leading widget and consistent styling (no AppBar)

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/constants/video_editor_constants.dart';

/// A custom header widget for video metadata screens.
/// Unlike AppBar, this provides full control over layout and positioning.
class VideoMetadataAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  /// Creates a custom header for video metadata screens.
  const VideoMetadataAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Container(
        height: kToolbarHeight,
        padding: const .symmetric(horizontal: 16),
        child: Row(
          spacing: 16,
          children: [
            Hero(
              tag: VideoEditorConstants.heroBackButtonId,
              child: DivineIconButton(
                icon: .caretLeft,
                type: .secondary,
                size: .small,
                onPressed: () => context.pop(),
              ),
            ),
            Expanded(
              child: Text(
                'Post details',
                style: VineTheme.titleMediumFont(color: VineTheme.onSurface),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
