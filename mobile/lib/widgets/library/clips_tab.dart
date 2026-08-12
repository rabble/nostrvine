// ABOUTME: Clips tab widget for the clip library screen
// ABOUTME: Displays a masonry grid of video clip thumbnails with selection support

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsService;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:openvine/blocs/clips_library/clips_library_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/library/empty_library_state.dart';
import 'package:openvine/widgets/library/pinch_zoom_grid.dart';
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
    required this.backgroundColor,
    this.selectionEnabled = true,
    this.clips,
    this.targetAspectRatio,
    this.scrollController,
    this.gridTopPadding = 0,
    super.key,
  });

  /// Optional externally provided clip order.
  final List<DivineVideoClip>? clips;

  /// Whether tapping a clip should toggle selection.
  final bool selectionEnabled;

  /// Whether in selection mode (adding to existing project).
  final bool showRecordButton;

  /// Surface this tab sits on. The zoomable grid paints it behind each of the
  /// two layouts it crossfades between — see [PinchZoomGrid.backgroundColor].
  final Color backgroundColor;

  /// Target aspect ratio for filtering compatible clips.
  final double? targetAspectRatio;

  /// Optional scroll controller, e.g. from a parent bottom sheet.
  final ScrollController? scrollController;

  /// Padding above the first grid row.
  ///
  /// The selection sheet sets this so the first row clears the bottom
  /// sheet header's divider instead of butting straight up against it.
  final double gridTopPadding;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ClipsLibraryBloc, ClipsLibraryState>(
      builder: (context, state) {
        final visibleClips = clips ?? state.clips;

        if (state.isLoading) {
          return const Center(child: BrandedLoadingIndicator(size: 60));
        }

        if (state.status == ClipsLibraryStatus.error) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SafeArea(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      context.l10n.libraryCouldNotLoadClips,
                      textAlign: TextAlign.center,
                      style: VineTheme.titleMediumFont(
                        color: context.vineColors.primaryText,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      context.l10n.libraryOpenErrorDescription,
                      textAlign: TextAlign.center,
                      style: VineTheme.bodyLargeFont(
                        color: context.vineColors.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 24),
                    DivineButton(
                      label: context.l10n.searchTryAgain,
                      type: DivineButtonType.secondary,
                      onPressed: () {
                        final bloc = context.read<ClipsLibraryBloc>();
                        final s = bloc.state;
                        bloc.add(
                          ClipsLibraryLoadRequested(
                            preSelectedIds: s.preSelectedIds,
                            disabledClipIds: s.disabledClipIds,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (visibleClips.isEmpty) {
          return EmptyLibraryState(
            icon: DivineIconName.filmSlate,
            title: context.l10n.libraryNoClipsYetTitle,
            subtitle: context.l10n.libraryNoClipsYetSubtitle,
            showRecordButton: showRecordButton,
          );
        }

        return _MasonryLayout(
          clips: visibleClips,
          columnCount: state.gridColumnCount,
          backgroundColor: backgroundColor,
          selectedClipIds: state.selectedClipIds,
          showSelectionIndicator: selectionEnabled,
          disabledClipIds: state.disabledClipIds,
          selectedIsStopMotion: state.selectedIsStopMotion,
          scrollController: scrollController,
          targetAspectRatio: targetAspectRatio,
          topPadding: gridTopPadding,
          onTapClip: (clip) {
            if (selectionEnabled) {
              context.read<ClipsLibraryBloc>().add(
                ClipsLibraryToggleSelection(clip),
              );
              return;
            }
            _showClipPreview(context, clip);
          },
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
          onDelete: () => _softDeleteClip(context, clip),
        ),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
        reverseTransitionDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  void _softDeleteClip(BuildContext context, DivineVideoClip clip) {
    _confirmDeleteClip(context, clip);
  }

  Future<void> _confirmDeleteClip(
    BuildContext context,
    DivineVideoClip clip,
  ) async {
    final confirmed = await VineBottomSheetPrompt.show<bool>(
      context: context,
      sticker: .alert,
      title: context.l10n.libraryDeleteClipTitle,
      subtitle: context.l10n.libraryDeleteClipMessage,
      additionalText: context.l10n.libraryDeleteClipsWarning,
      primaryButtonText: context.l10n.libraryDeleteConfirm,
      secondaryButtonText: context.l10n.commonCancel,
      onPrimaryPressed: () => Navigator.of(context).pop(true),
      onSecondaryPressed: () => Navigator.of(context).pop(false),
    );

    if (confirmed != true || !context.mounted) return;

    context.read<ClipsLibraryBloc>().add(ClipsLibraryDeleteClip(clip));
    Navigator.of(context).pop();
  }
}

/// Footer action bar for clip selection mode.
///
/// Sits below the clip grid and confirms the current selection. Renders no
/// background of its own so the enclosing bottom sheet's surface shows
/// through.
class ClipSelectionFooter extends StatelessWidget {
  /// Creates a selection footer.
  const ClipSelectionFooter({required this.onCreate, super.key});

  /// Callback when the select button is tapped.
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<ClipsLibraryBloc, ClipsLibraryState, bool>(
      selector: (state) => state.selectedClipIds.isNotEmpty,
      builder: (context, hasSelection) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: DivineButton(
              expanded: true,
              label: context.l10n.librarySelect,
              onPressed: hasSelection ? onCreate : null,
            ),
          ),
        );
      },
    );
  }
}

class _MasonryLayout extends StatelessWidget {
  const _MasonryLayout({
    required this.clips,
    required this.columnCount,
    required this.backgroundColor,
    required this.selectedClipIds,
    required this.showSelectionIndicator,
    required this.onTapClip,
    required this.onLongPressClip,
    this.disabledClipIds = const {},
    this.scrollController,
    this.targetAspectRatio,
    this.selectedIsStopMotion,
    this.topPadding = 0,
  });

  final List<DivineVideoClip> clips;
  final int columnCount;
  final Color backgroundColor;
  final Set<String> selectedClipIds;
  final bool showSelectionIndicator;
  final Set<String> disabledClipIds;
  final ScrollController? scrollController;
  final ValueChanged<DivineVideoClip> onTapClip;
  final ValueChanged<DivineVideoClip> onLongPressClip;
  final double? targetAspectRatio;
  final double topPadding;

  /// Type of the current selection (`true` = stop-motion). When set, clips of
  /// the other type are disabled so a selection can't mix stop-motion stills
  /// with normal video clips.
  final bool? selectedIsStopMotion;

  @override
  Widget build(BuildContext context) {
    final selectionIndexById = <String, int>{
      for (var i = 0; i < selectedClipIds.length; i++)
        selectedClipIds.elementAt(i): i + 1,
    };
    return PinchZoomGrid(
      columnCount: columnCount,
      minColumnCount: ClipGridColumns.min,
      maxColumnCount: ClipGridColumns.max,
      backgroundColor: backgroundColor,
      scrollController: scrollController,
      onColumnCountChanged: (columns) {
        context.read<ClipsLibraryBloc>().add(
          ClipsLibraryGridColumnsChanged(columns),
        );
        SemanticsService.sendAnnouncement(
          View.of(context),
          context.l10n.libraryGridSizeColumns(columns),
          Directionality.of(context),
        );
      },
      builder: (context, columns, controller) => MasonryGridView.count(
        controller: controller,
        padding: .only(
          top: topPadding,
          bottom: MediaQuery.viewPaddingOf(context).bottom,
        ),
        crossAxisCount: columns,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        cacheExtent: MediaQuery.sizeOf(context).height * 2,
        itemCount: clips.length,
        itemBuilder: (context, index) {
          final clip = clips[index];
          final selectionIndex = selectionIndexById[clip.id] ?? -1;

          return VideoClipThumbnailCard(
            clip: clip,
            selectionIndex: selectionIndex,
            showSelectionIndicator: showSelectionIndicator,
            disabled:
                disabledClipIds.contains(clip.id) ||
                (targetAspectRatio != null &&
                    targetAspectRatio != clip.targetAspectRatio.value) ||
                (selectedIsStopMotion != null &&
                    clip.isStopMotion != selectedIsStopMotion),
            onTap: () => onTapClip(clip),
            onLongPress: () => onLongPressClip(clip),
          );
        },
      ),
    );
  }
}
