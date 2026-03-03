// ABOUTME: Clips tab widget for the clip library screen
// ABOUTME: Displays a masonry grid of video clip thumbnails with selection support

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/clips_library/clips_library_bloc.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/utils/video_editor_utils.dart';
import 'package:openvine/widgets/library/empty_library_state.dart';
import 'package:openvine/widgets/masonary_grid.dart';
import 'package:openvine/widgets/video_clip/video_clip_preview.dart';
import 'package:openvine/widgets/video_clip/video_clip_thumbnail_card.dart';

/// Tab widget displaying a grid of saved clips.
///
/// Uses [ClipsLibraryBloc] for state management and handles clip preview
/// internally.
class ClipsTab extends StatelessWidget {
  /// Creates a clips tab.
  const ClipsTab({
    required this.remainingDuration,
    required this.isSelectionMode,
    this.targetAspectRatio,
    super.key,
  });

  /// Remaining duration available for selection.
  final Duration remainingDuration;

  /// Whether in selection mode (adding to existing project).
  final bool isSelectionMode;

  /// Target aspect ratio for filtering compatible clips.
  final double? targetAspectRatio;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ClipsLibraryBloc, ClipsLibraryState>(
      builder: (context, state) {
        if (state.isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: VineTheme.vineGreen),
          );
        }

        if (state.clips.isEmpty) {
          return EmptyLibraryState(
            icon: DivineIconName.filmSlate,
            // TODO(l10n): Replace with context.l10n when localization is added.
            title: 'No Clips Yet',
            // TODO(l10n): Replace with context.l10n when localization is added.
            subtitle: 'Your recorded video clips will appear here',
            showRecordButton: !isSelectionMode,
          );
        }

        return _MasonryLayout(
          clips: state.clips,
          selectedClipIds: state.selectedClipIds,
          remainingDuration: remainingDuration,
          targetAspectRatio: targetAspectRatio,
          onTapClip: (clip) => context.read<ClipsLibraryBloc>().add(
            ClipsLibraryToggleSelection(clip),
          ),
          onLongPressClip: (clip) => _showClipPreview(context, clip),
        );
      },
    );
  }

  Future<void> _showClipPreview(
    BuildContext context,
    DivineVideoClip clip,
  ) async {
    await Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, _, _) => VideoClipPreview(
          clip: clip,
          onDelete: () => _confirmDeleteClip(context, clip),
        ),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
        reverseTransitionDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  Future<void> _confirmDeleteClip(
    BuildContext context,
    DivineVideoClip clip,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: VineTheme.cardBackground,
        // TODO(l10n): Replace with context.l10n when localization is added.
        title: const Text(
          'Delete Clip',
          style: TextStyle(color: VineTheme.whiteText),
        ),
        // TODO(l10n): Replace with context.l10n when localization is added.
        content: const Text(
          'Are you sure you want to delete this clip?',
          style: TextStyle(color: VineTheme.whiteText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(
              // TODO(l10n): Replace with context.l10n when localization is
              // added.
              'Cancel',
              style: TextStyle(color: VineTheme.secondaryText),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: VineTheme.error,
              foregroundColor: VineTheme.whiteText,
            ),
            // TODO(l10n): Replace with context.l10n when localization is added.
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      Navigator.pop(context);
      context.read<ClipsLibraryBloc>().add(ClipsLibraryDeleteClip(clip));
    }
  }
}

/// Header widget for clip selection mode.
class ClipSelectionHeader extends StatelessWidget {
  /// Creates a selection header.
  const ClipSelectionHeader({
    required this.onCreate,
    required this.remainingDuration,
    super.key,
  });

  /// Callback when create button is tapped.
  final VoidCallback onCreate;

  /// Remaining duration available for selection.
  final Duration remainingDuration;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<ClipsLibraryBloc, ClipsLibraryState, Set<String>>(
      selector: (state) => state.selectedClipIds,
      builder: (context, selectedClipIds) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 4,
                children: [
                  const Spacer(),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        // TODO(l10n): Replace with context.l10n when
                        // localization is added.
                        'Clips',
                        style: VineTheme.titleFont(
                          color: VineTheme.onSurface,
                          fontSize: 18,
                          height: 1.33,
                          letterSpacing: 0.15,
                        ),
                      ),
                      Text(
                        '${remainingDuration.toFormattedSeconds()}s remaining',
                        style:
                            VineTheme.bodyFont(
                              color: VineTheme.onSurfaceVariant,
                              fontSize: 12,
                              height: 1.33,
                              letterSpacing: 0.40,
                            ).copyWith(
                              fontFeatures: [
                                const FontFeature.tabularFigures(),
                              ],
                            ),
                      ),
                    ],
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: _AddClipButton(
                        onTap: selectedClipIds.isNotEmpty
                            ? onCreate
                            : context.pop,
                        enable: selectedClipIds.isNotEmpty,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(
              height: 2,
              thickness: 2,
              color: VineTheme.outlinedDisabled,
            ),
          ],
        );
      },
    );
  }
}

class _MasonryLayout extends StatelessWidget {
  const _MasonryLayout({
    required this.clips,
    required this.selectedClipIds,
    required this.remainingDuration,
    required this.onTapClip,
    required this.onLongPressClip,
    this.targetAspectRatio,
  });

  final List<DivineVideoClip> clips;
  final Set<String> selectedClipIds;
  final Duration remainingDuration;
  final ValueChanged<DivineVideoClip> onTapClip;
  final ValueChanged<DivineVideoClip> onLongPressClip;
  final double? targetAspectRatio;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: MasonryGrid(
        columnCount: 2,
        rowGap: 4,
        columnGap: 4,
        itemAspectRatios: clips
            .map((clip) => clip.targetAspectRatio.value)
            .toList(),
        children: clips.map((clip) {
          final isSelected = selectedClipIds.contains(clip.id);
          return VideoClipThumbnailCard(
            clip: clip,
            isSelected: isSelected,
            disabled:
                (targetAspectRatio != null &&
                    targetAspectRatio != clip.targetAspectRatio.value) ||
                (!isSelected && clip.duration > remainingDuration),
            onTap: () => onTapClip(clip),
            onLongPress: () => onLongPressClip(clip),
          );
        }).toList(),
      ),
    );
  }
}

class _AddClipButton extends StatelessWidget {
  const _AddClipButton({required this.onTap, this.enable = true});

  final VoidCallback? onTap;
  final bool enable;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      // TODO(l10n): Replace with context.l10n when localization is added.
      label: 'Add',
      child: GestureDetector(
        onTap: enable ? onTap : null,
        child: Opacity(
          opacity: enable ? 1 : 0.32,
          child: Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: ShapeDecoration(
              color: VineTheme.tabIndicatorGreen,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              // TODO(l10n): Replace with context.l10n when localization
              // is added.
              'Add',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: VineTheme.onPrimary,
                fontSize: 18,
                fontFamily: VineTheme.fontFamilyBricolage,
                fontWeight: FontWeight.w800,
                height: 1.33,
                letterSpacing: 0.15,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
