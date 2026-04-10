// ABOUTME: Screen for browsing and managing saved video clips and drafts
// ABOUTME: Shows tabs for clips and drafts with preview, delete, and import options

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/clips_library/clips_library_bloc.dart';
import 'package:openvine/blocs/drafts_library/drafts_library_bloc.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_publish/video_publish_state.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_publish_provider.dart';
import 'package:openvine/screens/feed/video_feed_page.dart';
import 'package:openvine/screens/video_editor/video_editor_screen.dart';
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
    this.initialTabIndex = 0,
    this.selectionMode = false,
    this.editorClips = const [],
  });

  /// Index of the tab to show when the screen opens.
  ///
  /// `0` = Drafts, `1` = Clips.
  final int initialTabIndex;

  /// When true, enables multi-select mode for adding clips to the editor.
  ///
  /// In selection mode:
  /// - Only the Clips tab is shown (no Drafts tab)
  /// - Clips can be multi-selected via [ClipsLibraryBloc]
  /// - A header shows remaining duration and "Add" button
  /// - Selected clips are added to the video editor on confirmation
  final bool selectionMode;

  /// Current editor clips, used to calculate remaining duration and
  /// target aspect ratio in selection mode.
  final List<DivineVideoClip> editorClips;

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      initialIndex: widget.initialTabIndex,
      vsync: this,
    );

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

  void _showSnackBar(
    BuildContext context, {
    required String label,
    bool error = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: VineTheme.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        content: DivineSnackbarContainer(label: label, error: error),
      ),
    );
  }

  Future<void> _createVideoFromSelected(
    BuildContext context, {
    required List<DivineVideoClip> selectedClips,
    required ClipsLibraryBloc clipsBloc,
  }) async {
    if (selectedClips.isEmpty) return;

    if (!widget.selectionMode) {
      await ref.read(videoPublishProvider.notifier).clearAll();

      final clipManagerNotifier = ref.read(clipManagerProvider.notifier);
      for (final clip in selectedClips) {
        clipManagerNotifier.insertClip(
          clipManagerNotifier.clips.length,
          clip,
        );
      }
    }

    if (widget.selectionMode) {
      clipsBloc.add(const ClipsLibraryClearSelection());
      if (!context.mounted) return;
      context.pop(selectedClips);
    } else {
      if (!context.mounted) return;
      await context.push(
        VideoEditorScreen.path,
        extra: {'fromLibrary': true},
      );
      // Re-sync selection with ClipManager after returning from editor.
      if (!context.mounted) return;
      final currentClipIds = ref
          .read(clipManagerProvider)
          .clips
          .map((c) => c.id)
          .toSet();
      clipsBloc.add(
        ClipsLibraryLoadRequested(preSelectedIds: currentClipIds),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final editorClips = widget.selectionMode
        ? widget.editorClips
        : ref.watch(clipManagerProvider.select((s) => s.clips));
    final publishState = ref.watch(
      videoPublishProvider.select((s) => s.publishState),
    );
    final isPreparing = publishState == VideoPublishState.preparing;

    return MultiBlocProvider(
      providers: [
        BlocProvider<ClipsLibraryBloc>(
          create: (_) {
            final editorClipIds = widget.selectionMode
                ? widget.editorClips.map((c) => c.id).toSet()
                : ref.read(clipManagerProvider).clips.map((c) => c.id).toSet();
            return ClipsLibraryBloc(
              clipLibraryService: ref.read(clipLibraryServiceProvider),
              gallerySaveService: ref.read(gallerySaveServiceProvider),
            )..add(
              ClipsLibraryLoadRequested(preSelectedIds: editorClipIds),
            );
          },
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
                              onNext: () => _createVideoFromSelected(
                                context,
                                selectedClips: clipsState.selectedClips,
                                clipsBloc: clipsBloc,
                              ),
                            ),
                      body: widget.selectionMode
                          ? _SelectionBody(
                              targetAspectRatio: targetAspectRatio,
                              onCreate: () => _createVideoFromSelected(
                                context,
                                selectedClips: clipsState.selectedClips,
                                clipsBloc: clipsBloc,
                              ),
                            )
                          : _TabBody(
                              tabController: _tabController,
                              targetAspectRatio: targetAspectRatio,
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
    required this.onNext,
  });

  final TabController tabController;
  final VoidCallback onNext;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 48);

  @override
  Widget build(BuildContext context) {
    return BlocSelector<ClipsLibraryBloc, ClipsLibraryState, bool>(
      selector: (state) => state.selectedClipIds.isNotEmpty,
      builder: (context, hasSelection) {
        return DiVineAppBar(
          title: 'My library',
          style: DiVineAppBarStyle(titleStyle: VineTheme.titleMediumFont()),
          backgroundColor: VineTheme.onPrimary,
          surfaceTintColor: VineTheme.transparent,
          shape: const Border(
            bottom: BorderSide(color: VineTheme.outlineDisabled),
          ),
          showBackButton: true,
          onBackPressed: () {
            final ctx = context;
            if (ctx.canPop()) {
              ctx.pop();
            } else {
              ctx.go(VideoFeedPage.pathForIndex(0));
            }
          },
          actions: hasSelection
              ? [
                  DiVineAppBarAction(
                    backgroundColor: VineTheme.primary,
                    iconColor: VineTheme.onPrimary,
                    icon: SvgIconSource(
                      DivineIconName.caretRight.assetPath,
                    ),
                    onPressed: onNext,
                    tooltip: 'Next',
                  ),
                ]
              : const [],
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

class _SelectionBody extends StatelessWidget {
  const _SelectionBody({
    required this.onCreate,
    this.targetAspectRatio,
  });

  final VoidCallback onCreate;
  final double? targetAspectRatio;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipSelectionHeader(onCreate: onCreate),
        Expanded(
          child: ClipsTab(
            targetAspectRatio: targetAspectRatio,
            showRecordButton: true,
          ),
        ),
      ],
    );
  }
}

class _TabBody extends StatelessWidget {
  const _TabBody({
    required this.tabController,
    this.targetAspectRatio,
  });

  final TabController tabController;
  final double? targetAspectRatio;

  @override
  Widget build(BuildContext context) {
    return TabBarView(
      controller: tabController,
      children: [
        const DraftsTab(
          showRecordButton: false,
          showAutosavedDraft: false,
        ),
        ClipsTab(
          targetAspectRatio: targetAspectRatio,
          showRecordButton: false,
        ),
      ],
    );
  }
}
