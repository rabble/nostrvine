// ABOUTME: Screen for browsing and managing saved video clips and drafts
// ABOUTME: Shows tabs for clips and drafts with preview, delete, and import options

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/clips_library/clips_library_bloc.dart';
import 'package:openvine/blocs/drafts_library/drafts_library_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_publish/video_publish_state.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_publish_provider.dart';
import 'package:openvine/screens/feed/video_feed_page.dart';
import 'package:openvine/screens/video_editor/video_clip_editor_screen.dart';
import 'package:openvine/services/gallery_save_service.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/library/library.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  /// Route name for drafts path.
  static const draftsRouteName = 'drafts';

  /// Path for drafts route.
  static const draftsPath = '/drafts';

  /// Route name for clips path.
  static const clipsRouteName = 'clips';

  /// Path for clips route.
  static const clipsPath = '/clips';

  const LibraryScreen({
    super.key,
    this.selectionMode = false,
  });

  /// When true, enables multi-select mode for adding clips to the editor.
  ///
  /// In selection mode:
  /// - Only the Clips tab is shown (no Drafts tab)
  /// - Clips can be multi-selected via [ClipsLibraryBloc]
  /// - A header shows remaining duration and "Add" button
  /// - Selected clips are added to the video editor on confirmation
  final bool selectionMode;

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    Log.info(
      '📚 ClipLibrary opened (selectionMode: ${widget.selectionMode})',
      name: 'LibraryScreen',
      category: LogCategory.video,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Duration _remainingDuration(
    ClipsLibraryState clipsState,
  ) {
    final editorRemaining = widget.selectionMode
        ? ref.watch(clipManagerProvider.select((s) => s.remainingDuration))
        : VideoEditorConstants.maxDuration;
    return editorRemaining - clipsState.selectedDuration;
  }

  void _showSnackBar(
    BuildContext context, {
    required String label,
    bool error = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        content: DivineSnackbarContainer(label: label, error: error),
      ),
    );
  }

  Future<void> _showDeleteConfirmationDialog(
    BuildContext context,
    ClipsLibraryBloc clipsBloc,
  ) async {
    final clipCount = clipsBloc.state.selectedClipIds.length;
    if (clipCount == 0) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: VineTheme.cardBackground,
        title: const Text(
          'Delete Clips',
          style: TextStyle(color: VineTheme.whiteText),
        ),
        content: Column(
          mainAxisSize: .min,
          crossAxisAlignment: .start,
          spacing: 12,
          children: [
            Text(
              'Are you sure you want to delete $clipCount '
              'selected clip${clipCount == 1 ? '' : 's'}?',
              style: const TextStyle(color: VineTheme.whiteText),
            ),
            const Text(
              'This action cannot be undone. The video files will be '
              'permanently removed from your device.',
              style: TextStyle(color: VineTheme.secondaryText, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      clipsBloc.add(const ClipsLibraryDeleteSelected());
    }
  }

  Future<void> _createVideoFromSelected(
    BuildContext context, {
    required List<DivineVideoClip> selectedClips,
    required ClipsLibraryBloc clipsBloc,
  }) async {
    if (selectedClips.isEmpty) return;

    if (!widget.selectionMode) {
      await ref.read(videoPublishProvider.notifier).clearAll();
    }

    final clipManagerNotifier = ref.read(clipManagerProvider.notifier);
    for (final clip in selectedClips) {
      clipManagerNotifier.addClip(
        video: clip.video,
        duration: clip.duration,
        thumbnailPath: clip.thumbnailPath,
        targetAspectRatio: clip.targetAspectRatio,
        originalAspectRatio: clip.targetAspectRatio.value,
        lensMetadata: clip.lensMetadata,
      );
    }

    clipsBloc.add(const ClipsLibraryClearSelection());

    if (!context.mounted) return;

    if (widget.selectionMode) {
      context.pop();
    } else {
      await context.push(
        VideoClipEditorScreen.path,
        extra: {'fromLibrary': true},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final editorClips = ref.watch(clipManagerProvider.select((s) => s.clips));
    final publishState = ref.watch(
      videoPublishProvider.select((s) => s.publishState),
    );
    final isPreparing = publishState == VideoPublishState.preparing;

    return MultiBlocProvider(
      providers: [
        BlocProvider<ClipsLibraryBloc>(
          create: (_) => ClipsLibraryBloc(
            clipLibraryService: ref.read(clipLibraryServiceProvider),
            gallerySaveService: ref.read(gallerySaveServiceProvider),
          )..add(const ClipsLibraryLoadRequested()),
        ),
        BlocProvider<DraftsLibraryBloc>(
          create: (_) => DraftsLibraryBloc(
            draftStorageService: ref.read(draftStorageServiceProvider),
          )..add(const DraftsLibraryLoadRequested()),
        ),
      ],
      child: Builder(
        builder: (context) {
          final clipsBloc = context.read<ClipsLibraryBloc>();

          return MultiBlocListener(
            listeners: [
              BlocListener<ClipsLibraryBloc, ClipsLibraryState>(
                listenWhen: (prev, curr) =>
                    curr.lastGallerySaveResult != null &&
                    prev.lastGallerySaveResult != curr.lastGallerySaveResult,
                listener: (context, state) {
                  final result = state.lastGallerySaveResult;
                  if (result == null) return;

                  switch (result) {
                    case GallerySaveResultSuccess(
                      :final successCount,
                      :final failureCount,
                    ):
                      final label = failureCount == 0
                          ? '$successCount clip${successCount == 1 ? '' : 's'} '
                                'saved to ${GallerySaveService.destinationName}'
                          : '$successCount saved, $failureCount failed';
                      _showSnackBar(
                        context,
                        label: label,
                        error: failureCount > 0,
                      );
                    case GallerySaveResultPermissionDenied():
                      _showSnackBar(
                        context,
                        label:
                            '${GallerySaveService.destinationName} '
                            'permission denied',
                        error: true,
                      );
                    case GallerySaveResultError(:final message):
                      _showSnackBar(context, label: message, error: true);
                  }
                },
              ),
              BlocListener<ClipsLibraryBloc, ClipsLibraryState>(
                listenWhen: (prev, curr) =>
                    curr.lastDeletedCount != null &&
                    prev.lastDeletedCount != curr.lastDeletedCount,
                listener: (context, state) {
                  final count = state.lastDeletedCount;
                  if (count == null) return;

                  _showSnackBar(
                    context,
                    label: '$count clip${count == 1 ? '' : 's'} deleted',
                  );
                },
              ),
            ],
            child: BlocBuilder<ClipsLibraryBloc, ClipsLibraryState>(
              builder: (context, clipsState) {
                final targetAspectRatio =
                    widget.selectionMode && editorClips.isNotEmpty
                    ? editorClips.first.targetAspectRatio.value
                    : clipsState.selectedClipIds.isNotEmpty
                    ? clipsState.clips
                          .firstWhere(
                            (el) => el.id == clipsState.selectedClipIds.first,
                            orElse: () => clipsState.clips.first,
                          )
                          .targetAspectRatio
                          .value
                    : null;

                final remaining = _remainingDuration(clipsState);

                return Stack(
                  children: [
                    Scaffold(
                      backgroundColor: widget.selectionMode
                          ? VineTheme.surfaceBackground
                          : VineTheme.onPrimary,
                      appBar: widget.selectionMode
                          ? null
                          : _LibraryAppBar(
                              tabController: _tabController,
                              onSaveToGallery: () => clipsBloc.add(
                                const ClipsLibrarySaveToGallery(),
                              ),
                              onDelete: () => _showDeleteConfirmationDialog(
                                context,
                                clipsBloc,
                              ),
                            ),
                      body: widget.selectionMode
                          ? _SelectionBody(
                              remainingDuration: remaining,
                              targetAspectRatio: targetAspectRatio,
                              onCreate: () => _createVideoFromSelected(
                                context,
                                selectedClips: clipsState.selectedClips,
                                clipsBloc: clipsBloc,
                              ),
                            )
                          : _TabBody(
                              tabController: _tabController,
                              remainingDuration: remaining,
                              targetAspectRatio: targetAspectRatio,
                            ),
                      floatingActionButton:
                          widget.selectionMode ||
                              clipsState.selectedClipIds.isEmpty
                          ? null
                          : _CreateVideoFab(
                              onPressed: () => _createVideoFromSelected(
                                context,
                                selectedClips: clipsState.selectedClips,
                                clipsBloc: clipsBloc,
                              ),
                            ),
                    ),
                    if (clipsState.isDeleting ||
                        clipsState.isSavingToGallery ||
                        isPreparing)
                      Material(
                        color: VineTheme.scrim65,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            spacing: 16,
                            children: [
                              const CircularProgressIndicator(
                                color: VineTheme.vineGreen,
                              ),
                              if (isPreparing)
                                Text(
                                  'Preparing video...',
                                  style: VineTheme.bodyMediumFont(),
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _LibraryAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _LibraryAppBar({
    required this.tabController,
    required this.onSaveToGallery,
    required this.onDelete,
  });

  final TabController tabController;
  final VoidCallback onSaveToGallery;
  final VoidCallback onDelete;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 48);

  @override
  Widget build(BuildContext context) {
    return BlocSelector<ClipsLibraryBloc, ClipsLibraryState, bool>(
      selector: (state) => state.selectedClipIds.isNotEmpty,
      builder: (context, hasSelection) {
        return AppBar(
          backgroundColor: VineTheme.onPrimary,
          foregroundColor: VineTheme.whiteText,
          surfaceTintColor: Colors.transparent,
          shape: const Border(
            bottom: BorderSide(color: VineTheme.outlineDisabled),
          ),
          centerTitle: false,
          leadingWidth: 64,
          leading: const Padding(
            padding: .only(left: 16),
            child: Align(alignment: .centerLeft, child: _BackButton()),
          ),
          title: Text('Library', style: VineTheme.titleLargeFont()),
          actions: hasSelection
              ? [
                  IconButton(
                    icon: const DivineIcon(
                      icon: .downloadSimple,
                      color: VineTheme.whiteText,
                    ),
                    onPressed: onSaveToGallery,
                    tooltip: 'Save to camera roll',
                  ),
                  IconButton(
                    icon: const DivineIcon(
                      icon: .trash,
                      color: VineTheme.error,
                    ),
                    onPressed: onDelete,
                    tooltip: 'Delete selected clips',
                  ),
                ]
              : null,
          bottom: TabBar(
            controller: tabController,
            indicator: const UnderlineTabIndicator(
              borderSide: BorderSide(color: VineTheme.vineGreen, width: 6),
              borderRadius: BorderRadius.zero,
            ),
            labelColor: VineTheme.whiteText,
            unselectedLabelColor: VineTheme.secondaryText,
            labelStyle: VineTheme.tabTextStyle(),
            padding: .zero,
            labelPadding: const .symmetric(horizontal: 16),
            isScrollable: true,
            tabAlignment: .start,
            tabs: const [
              Tab(text: 'Drafts'),
              Tab(text: 'Clips'),
            ],
          ),
        );
      },
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton();

  @override
  Widget build(BuildContext context) {
    return DivineIconButton(
      icon: .caretLeft,
      size: .small,
      type: .secondary,
      onPressed: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(VideoFeedPage.pathForIndex(0));
        }
      },
    );
  }
}

class _SelectionBody extends StatelessWidget {
  const _SelectionBody({
    required this.remainingDuration,
    required this.onCreate,
    this.targetAspectRatio,
  });

  final Duration remainingDuration;
  final VoidCallback onCreate;
  final double? targetAspectRatio;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipSelectionHeader(
          remainingDuration: remainingDuration,
          onCreate: onCreate,
        ),
        Expanded(
          child: ClipsTab(
            remainingDuration: remainingDuration,
            targetAspectRatio: targetAspectRatio,
            isSelectionMode: true,
          ),
        ),
      ],
    );
  }
}

class _TabBody extends StatelessWidget {
  const _TabBody({
    required this.tabController,
    required this.remainingDuration,
    this.targetAspectRatio,
  });

  final TabController tabController;
  final Duration remainingDuration;
  final double? targetAspectRatio;

  @override
  Widget build(BuildContext context) {
    return TabBarView(
      controller: tabController,
      children: [
        const DraftsTab(),
        ClipsTab(
          remainingDuration: remainingDuration,
          targetAspectRatio: targetAspectRatio,
          isSelectionMode: false,
        ),
      ],
    );
  }
}

class _CreateVideoFab extends StatelessWidget {
  const _CreateVideoFab({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: onPressed,
      icon: const DivineIcon(icon: .pencilSimple, color: VineTheme.whiteText),
      label: Text(
        'Create Video',
        style: VineTheme.titleSmallFont(),
      ),
      backgroundColor: VineTheme.primary,
    );
  }
}
