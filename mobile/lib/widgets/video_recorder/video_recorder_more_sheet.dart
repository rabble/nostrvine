// ABOUTME: Bottom sheet for clip management options during video recording
// ABOUTME: Provides actions to add, save, remove, and clear recording clips

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/widgets/bottom_sheet_list_tile.dart';

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
    final hasClips = ref.watch(clipManagerProvider.select((p) => p.hasClips));
    final clipsNotifier = ref.read(clipManagerProvider.notifier);

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: .min,
          children: [
            BottomSheetListTile(
              iconPath: 'assets/icon/folder_open.svg',
              title: 'Add clip from Library',
              /* TODO(@hm21): Temporary "commented out" create PR with only new files
              onTap: () => ref
                  .read(clipManagerProvider.notifier)
                  .pickFromLibrary(context), */
            ),
            BottomSheetListTile(
              iconPath: 'assets/icon/save.svg',
              title: 'Save clip to Library',
              // TODO(@hm21): Temporary "commented out" create PR with only new files
              // onTap: hasClips ? clipsNotifier.saveClipsToLibrary : null,
            ),
            BottomSheetListTile(
              iconPath: 'assets/icon/undo.svg',
              title: 'Remove last clip',
              // TODO(@hm21): Temporary "commented out" create PR with only new files
              // onTap: hasClips ? clipsNotifier.removeLastClip : null,
              color: const Color(0xFFF44336),
            ),
            BottomSheetListTile(
              iconPath: 'assets/icon/trash.svg',
              title: 'Clear all clips',
              onTap: hasClips ? clipsNotifier.clearAll : null,
              color: const Color(0xFFF44336),
            ),
          ],
        ),
      ),
    );
  }
}
