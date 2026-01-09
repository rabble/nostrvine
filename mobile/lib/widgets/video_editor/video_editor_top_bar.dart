// ABOUTME: Top bar with close, clip counter, and done buttons
// ABOUTME: Displays current clip position and total clip count

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/widgets/divine_icon_button.dart';

/// Top bar with close button, clip counter, and done button.
class VideoEditorTopBar extends ConsumerWidget {
  /// Creates a video editor top bar widget.
  const VideoEditorTopBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalClips = ref.watch(
      clipManagerProvider.select((state) => state.clips.length),
    );
    final state = ref.watch(
      videoEditorProvider.select(
        (s) => (currentClipIndex: s.currentClipIndex, isEditing: s.isEditing),
      ),
    );
    final notifier = ref.read(videoEditorProvider.notifier);

    return Container(
      height: 80,
      padding: const .symmetric(horizontal: 16, vertical: 16),
      child: Row(
        mainAxisAlignment: .spaceBetween,
        children: [
          // Close/Back button
          if (state.isEditing)
            DivineIconButton(
              iconPath: 'assets/icon/close.svg',
              onTap: notifier.stopClipEditing,
              semanticLabel: 'Close video editor',
            )
          else
            DivineIconButton(
              iconPath: 'assets/icon/video_camera.svg',
              onTap: () => context.pop(),
              semanticLabel: 'Go back to camera',
            ),

          // Clip counter
          Text(
            '${state.currentClipIndex + 1}/$totalClips',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              height: 1.33,
              letterSpacing: 0.15,
              fontWeight: .w800,
              fontFamily: 'Bricolage Grotesque',
              fontFeatures: [.tabularFigures()],
            ),
          ),

          // Done button
          if (state.isEditing)
            DivineIconButton(
              iconPath: 'assets/icon/more_horiz.svg',
              onTap: () => notifier.showMoreOptions(context),
              semanticLabel: 'More',
            )
          else
            DivineIconButton(
              iconPath: 'assets/icon/arrow_forward.svg',
              backgroundColor: VineTheme.tabIndicatorGreen,
              onTap: () => notifier.done(context),
              semanticLabel: 'Done editing',
            ),
        ],
      ),
    );
  }
}
