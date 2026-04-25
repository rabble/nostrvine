// ABOUTME: Clips tab widget for the clip library screen
// ABOUTME: Displays a masonry grid of video clip thumbnails with selection support

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/clips_library/clips_library_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/widgets/library/empty_library_state.dart';
import 'package:openvine/widgets/video_clip/video_clip_preview.dart';
import 'package:openvine/widgets/video_clip/video_clip_thumbnail_card.dart';

/// Tab widget displaying a grid of saved clips.
///
/// Uses [ClipsLibraryBloc] for state management and handles clip preview
/// internally.
class ClipsTab extends StatelessWidget {
  /// Creates a clips tab.
  const ClipsTab({
    required this.showRecordButton,
    this.targetAspectRatio,
    this.scrollController,
    super.key,
  });

  /// Whether in selection mode (adding to existing project).
  final bool showRecordButton;

  /// Target aspect ratio for filtering compatible clips.
  final double? targetAspectRatio;

  /// Optional scroll controller, e.g. from a parent bottom sheet.
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ClipsLibraryBloc, ClipsLibraryState>(
      builder: (context, state) {
        if (state.isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: VineTheme.vineGreen),
          );
        }

        if (state.status == ClipsLibraryStatus.error) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    context.l10n.libraryCouldNotLoadClips,
                    textAlign: TextAlign.center,
                    style: VineTheme.titleMediumFont(),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.l10n.libraryOpenErrorDescription,
                    textAlign: TextAlign.center,
                    style: VineTheme.bodyLargeFont(
                      color: VineTheme.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 24),
                  DivineButton(
                    label: context.l10n.searchTryAgain,
                    type: DivineButtonType.secondary,
                    onPressed: () => context.read<ClipsLibraryBloc>().add(
                      const ClipsLibraryLoadRequested(),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (state.clips.isEmpty) {
          return EmptyLibraryState(
            icon: DivineIconName.filmSlate,
            title: context.l10n.libraryNoClipsYetTitle,
            subtitle: context.l10n.libraryNoClipsYetSubtitle,
            showRecordButton: showRecordButton,
          );
        }

        return _MasonryLayout(
          clips: state.clips,
          selectedClipIds: state.selectedClipIds,
          disabledClipIds: state.disabledClipIds,
          scrollController: scrollController,
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
        title: Text(
          context.l10n.libraryDeleteClipTitle,
          style: VineTheme.titleSmallFont(),
        ),
        content: Text(
          context.l10n.libraryDeleteClipMessage,
          style: VineTheme.bodyMediumFont(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              context.l10n.commonCancel,
              style: VineTheme.bodyMediumFont(color: VineTheme.secondaryText),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: VineTheme.error,
              foregroundColor: VineTheme.whiteText,
            ),
            child: Text(context.l10n.commonDelete),
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
  const ClipSelectionHeader({required this.onCreate, super.key});

  /// Callback when create button is tapped.
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<ClipsLibraryBloc, ClipsLibraryState, Set<String>>(
      selector: (state) => state.selectedClipIds,
      builder: (context, selectedClipIds) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 16),
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
                        context.l10n.libraryClipSelectionTitle,
                        style: VineTheme.titleMediumFont(
                          color: VineTheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  Expanded(
                    child: Align(
                      alignment: AlignmentDirectional.centerEnd,
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
    required this.onTapClip,
    required this.onLongPressClip,
    this.disabledClipIds = const {},
    this.scrollController,
    this.targetAspectRatio,
  });

  final List<DivineVideoClip> clips;
  final Set<String> selectedClipIds;
  final Set<String> disabledClipIds;
  final ScrollController? scrollController;
  final ValueChanged<DivineVideoClip> onTapClip;
  final ValueChanged<DivineVideoClip> onLongPressClip;
  final double? targetAspectRatio;

  static const _columnCount = 3;
  static const _radius = Radius.circular(32);

  @override
  Widget build(BuildContext context) {
    final selectionIndexById = <String, int>{
      for (var i = 0; i < selectedClipIds.length; i++)
        selectedClipIds.elementAt(i): i + 1,
    };
    return MasonryGridView.count(
      controller: scrollController,
      padding: .fromSTEB(8, 0, 8, MediaQuery.viewPaddingOf(context).bottom),
      crossAxisCount: _columnCount,
      mainAxisSpacing: 4,
      crossAxisSpacing: 4,
      cacheExtent: MediaQuery.sizeOf(context).height * 2,
      itemCount: clips.length,
      itemBuilder: (context, index) {
        final clip = clips[index];
        final selectionIndex = selectionIndexById[clip.id] ?? -1;
        final firstRowLastIndex = clips.length < _columnCount
            ? clips.length - 1
            : _columnCount - 1;
        final isLastInFirstRow = index == firstRowLastIndex;
        final borderRadius = BorderRadius.only(
          topLeft: index == 0 ? _radius : Radius.zero,
          topRight: isLastInFirstRow ? _radius : Radius.zero,
        );
        return ClipRRect(
          borderRadius: borderRadius,
          child: VideoClipThumbnailCard(
            clip: clip,
            selectionIndex: selectionIndex,
            disabled:
                disabledClipIds.contains(clip.id) ||
                (targetAspectRatio != null &&
                    targetAspectRatio != clip.targetAspectRatio.value),
            onTap: () => onTapClip(clip),
            onLongPress: () => onLongPressClip(clip),
          ),
        );
      },
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
      label: 'Select',
      child: GestureDetector(
        onTap: enable ? onTap : null,
        child: Opacity(
          opacity: enable ? 1 : 0.32,
          child: Container(
            margin: const EdgeInsetsDirectional.only(end: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: ShapeDecoration(
              color: VineTheme.tabIndicatorGreen,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              // TODO(l10n): Replace with context.l10n when localization
              // is added.
              'Select',
              textAlign: .center,
              style: VineTheme.titleMediumFont(color: VineTheme.onPrimary),
            ),
          ),
        ),
      ),
    );
  }
}
