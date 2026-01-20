// ABOUTME: Bottom sheet for clip management options during video recording
// ABOUTME: Provides actions to add, save, remove, and clear recording clips

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/widgets/bottom_sheet_list_tile.dart';
import 'package:divine_ui/divine_ui.dart';

/// Bottom sheet for managing recording clips.
///
/// Allows users to add clips from library, save current clips, or
/// remove/clear clips.
class VideoRecorderMoreSheet extends ConsumerStatefulWidget {
  /// Creates a more options bottom sheet widget.
  const VideoRecorderMoreSheet({super.key});

  @override
  ConsumerState<VideoRecorderMoreSheet> createState() =>
      _VideoRecorderMoreSheetState();
}

class _VideoRecorderMoreSheetState
    extends ConsumerState<VideoRecorderMoreSheet> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(
      clipManagerProvider.select(
        (p) => (hasClips: p.hasClips, clipCount: p.clipCount),
      ),
    );
    final clipsNotifier = ref.read(clipManagerProvider.notifier);

    return SafeArea(
      child: Column(
        mainAxisSize: .min,
        spacing: 24,
        children: [
          const Padding(
            padding: .only(top: 8),
            child: VineBottomSheetDragHandle(),
          ),
          SingleChildScrollView(
            child: Column(
              mainAxisSize: .min,
              children: [
                BottomSheetListTile(
                  iconPath: 'assets/icon/save.svg',
                  // TODO(l10n): Replace with context.l10n when localization is added.
                  title: state.clipCount > 1
                      ? 'Save clips to Library'
                      : 'Save clip to Library',
                  onTap: state.hasClips
                      ? clipsNotifier.saveClipsToLibrary
                      : null,
                ),
                BottomSheetListTile(
                  iconPath: 'assets/icon/undo.svg',
                  // TODO(l10n): Replace with context.l10n when localization is added.
                  title: 'Remove last clip',
                  onTap: state.hasClips ? clipsNotifier.removeLastClip : null,
                  color: const Color(0xFFF44336),
                ),
                BottomSheetListTile(
                  iconPath: 'assets/icon/trash.svg',
                  // TODO(l10n): Replace with context.l10n when localization is added.
                  title: 'Clear all clips',
                  onTap: state.hasClips ? clipsNotifier.clearAll : null,
                  color: const Color(0xFFF44336),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
