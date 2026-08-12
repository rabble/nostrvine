// ABOUTME: Screen for browsing and managing saved video clips and drafts
// ABOUTME: Shows tabs for clips and drafts with preview, delete, and import options

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/clips_library/clips_library_bloc.dart';
import 'package:openvine/blocs/drafts_library/drafts_library_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/mixins/reduced_motion_tab_controller_mixin.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/stop_motion/stop_motion_frame_ops.dart';
import 'package:openvine/models/video_publish/video_publish_state.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/video_publish_provider.dart';
import 'package:openvine/screens/feed/video_feed_page.dart';
import 'package:openvine/screens/library_trash_screen.dart';
import 'package:openvine/screens/video_editor/video_editor_screen.dart';
import 'package:openvine/services/gallery_save_service.dart';
import 'package:openvine/widgets/library/library.dart';
import 'package:unified_logger/unified_logger.dart';

/// Which tabs the library shows.
enum LibraryTabsMode {
  /// Drafts, Clips and Sounds — the standalone library.
  allTabs,

  /// Drafts and Clips. Opened from the recorder, where a saved sound is not
  /// something the current session can pick up.
  withoutSounds,
}

/// A tab the library can show, in bar order.
enum _LibraryTab { drafts, clips, sounds }

class LibraryScreen extends ConsumerWidget {
  /// Route name for drafts path.
  static const draftsRouteName = 'drafts';

  /// Path for drafts route.
  static const draftsPath = '/drafts';

  /// Route name for clips path.
  static const clipsRouteName = 'clips';

  /// Path for clips route.
  static const clipsPath = '/clips';

  /// Route name for the recorder's library (drafts + clips, no sounds).
  static const clipsOnlyRouteName = 'clipsOnly';

  /// Path for the recorder's library (drafts + clips, no sounds).
  static const clipsOnlyPath = '/clips-only';

  /// Route name for sounds path.
  static const soundsRouteName = 'sounds';

  /// Path for sounds route.
  static const soundsPath = '/sounds';

  const LibraryScreen({
    super.key,
    this.initialTabIndex = 0,
    this.selectionMode = false,
    this.tabsMode = LibraryTabsMode.allTabs,
    this.clipTypeFilter = LibraryClipTypeFilter.all,
    this.includeAutosaveDraft = true,
    this.editorClips = const [],
    this.scrollController,
  });

  /// Index of the tab to show when the screen opens.
  ///
  /// `0` = Drafts, `1` = Clips, `2` = Sounds.
  final int initialTabIndex;

  /// When true, enables multi-select mode for adding clips to the editor.
  ///
  /// In selection mode:
  /// - Only the Clips tab is shown (no Drafts tab)
  /// - Clips can be multi-selected via [ClipsLibraryBloc]
  /// - A header shows remaining duration and "Add" button
  /// - Selected clips are added to the video editor on confirmation
  final bool selectionMode;

  /// Controls whether all tabs are shown or only the clips content.
  final LibraryTabsMode tabsMode;

  /// Restricts which clip types the clips tab shows. Set by the recorder
  /// entry-point to the current mode's type (stop-motion vs normal video);
  /// [LibraryClipTypeFilter.all] for the standalone library.
  final LibraryClipTypeFilter clipTypeFilter;

  /// Whether the drafts tab lists the in-progress autosave draft. Off for the
  /// recorder entry-point, which opens on top of the session writing it.
  final bool includeAutosaveDraft;

  /// Current editor clips, used to calculate remaining duration and
  /// target aspect ratio in selection mode.
  final List<DivineVideoClip> editorClips;

  /// Optional scroll controller, e.g. from a parent [DraggableScrollableSheet].
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (kIsWeb) {
      return const _LibraryWebUnavailableScreen();
    }

    final clipLibraryService = ref.watch(clipLibraryServiceProvider);
    final gallerySaveService = ref.watch(gallerySaveServiceProvider);
    final draftStorageService = ref.watch(draftStorageServiceProvider);

    return MultiBlocProvider(
      providers: [
        BlocProvider<ClipsLibraryBloc>(
          key: ValueKey((
            clipLibraryService,
            gallerySaveService,
            clipTypeFilter,
          )),
          create: (_) {
            final editorClipIds = selectionMode
                ? editorClips.map((c) => c.id).toSet()
                : ref.read(clipManagerProvider).clips.map((c) => c.id).toSet();
            return ClipsLibraryBloc(
              clipLibraryService: clipLibraryService,
              gallerySaveService: gallerySaveService,
              sharedPreferences: ref.read(sharedPreferencesProvider),
              clipTypeFilter: clipTypeFilter,
            )..add(
              ClipsLibraryLoadRequested(
                preSelectedIds: editorClipIds,
                disabledClipIds: selectionMode ? editorClipIds : const {},
              ),
            );
          },
        ),
        BlocProvider<DraftsLibraryBloc>(
          key: ValueKey((draftStorageService, includeAutosaveDraft)),
          create: (_) => DraftsLibraryBloc(
            draftStorageService: draftStorageService,
            includeAutosaveDraft: includeAutosaveDraft,
          )..add(const DraftsLibraryLoadRequested()),
        ),
      ],
      child: _LibraryView(
        initialTabIndex: initialTabIndex,
        selectionMode: selectionMode,
        tabsMode: tabsMode,
        editorClips: editorClips,
        scrollController: scrollController,
      ),
    );
  }
}

class _LibraryView extends ConsumerStatefulWidget {
  const _LibraryView({
    required this.initialTabIndex,
    required this.selectionMode,
    required this.tabsMode,
    required this.editorClips,
    required this.scrollController,
  });

  final int initialTabIndex;
  final bool selectionMode;
  final LibraryTabsMode tabsMode;
  final List<DivineVideoClip> editorClips;
  final ScrollController? scrollController;

  @override
  ConsumerState<_LibraryView> createState() => _LibraryViewState();
}

class _LibraryViewState extends ConsumerState<_LibraryView>
    with TickerProviderStateMixin, ReducedMotionTabControllerMixin {
  late int _activeTabIndex;

  /// Tabs of the current mode, in bar order.
  ///
  /// Selection mode renders inside a sheet that only adds clips, so it drops
  /// the bar entirely; the other modes differ only in the Sounds tab.
  List<_LibraryTab> get _tabs {
    if (widget.selectionMode) return const [_LibraryTab.clips];
    return switch (widget.tabsMode) {
      LibraryTabsMode.allTabs => const [
        _LibraryTab.drafts,
        _LibraryTab.clips,
        _LibraryTab.sounds,
      ],
      LibraryTabsMode.withoutSounds => const [
        _LibraryTab.drafts,
        _LibraryTab.clips,
      ],
    };
  }

  @override
  int get tabCount => _tabs.length;

  @override
  int get initialTabIndex => widget.initialTabIndex.clamp(0, tabCount - 1);

  bool get _isClipsTabActive =>
      _tabs[_activeTabIndex.clamp(0, _tabs.length - 1)] == _LibraryTab.clips;

  bool get _shouldAutoOpenSelectionMode =>
      !widget.selectionMode && widget.tabsMode == LibraryTabsMode.withoutSounds;

  bool _isSelectionEnabled(ClipsLibraryState state) =>
      widget.selectionMode || state.isLibrarySelectionMode;

  bool _isSelectionModeLockedToCloseOnly(ClipsLibraryState state) =>
      _shouldAutoOpenSelectionMode &&
      state.didAutoOpenSelectionMode &&
      state.isLibrarySelectionMode;

  @override
  void initState() {
    super.initState();
    _activeTabIndex = initialTabIndex;

    Log.info(
      '📚 ClipLibrary opened (selectionMode: ${widget.selectionMode})',
      name: 'LibraryScreen',
      category: LogCategory.video,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    syncTabController();
  }

  @override
  void didUpdateWidget(_LibraryView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // selectionMode and tabsMode decide the tab count, so a flip needs a
    // matching controller before build renders the TabBar against it.
    if (syncTabController()) _activeTabIndex = tabController.index;
  }

  @override
  void onTabChanged() {
    if (!mounted) return;
    if (_activeTabIndex == tabController.index) return;
    setState(() {
      _activeTabIndex = tabController.index;
    });

    final clipsBloc = context.read<ClipsLibraryBloc>();
    final clipsState = clipsBloc.state;
    // Leaving the Clips tab drops a selection the user opened themselves. An
    // auto-opened one mirrors the recorder session that sent us here, so
    // clearing it on a peek at Drafts would lose that session's clips.
    if (!widget.selectionMode &&
        clipsState.isLibrarySelectionMode &&
        !_isSelectionModeLockedToCloseOnly(clipsState) &&
        !_isClipsTabActive) {
      clipsBloc.add(const ClipsLibraryExitSelectionMode());
    }
  }

  void _showSnackBar(
    BuildContext context, {
    required String label,
    bool error = false,
    String? actionLabel,
    VoidCallback? onActionPressed,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      DivineSnackbarContainer.snackBar(
        label,
        error: error,
        actionLabel: actionLabel,
        onActionPressed: onActionPressed,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  /// Deliberately imperative: [ClipsLibraryBloc] is created inside
  /// [LibraryScreen.build] under a ValueKey over Riverpod deps and seeded with
  /// the current `preSelectedIds` / `disabledClipIds`. A sibling GoRoute sits
  /// outside that provider scope, and a child GoRoute stacks as a separate
  /// page rather than nesting inside the parent's subtree, so neither can see
  /// the bloc. Routing this needs a ShellRoute or a bloc hoist — tracked
  /// separately, see #6481.
  Future<void> _openTrash(
    BuildContext context,
    ClipsLibraryBloc clipsBloc,
  ) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => BlocProvider<ClipsLibraryBloc>.value(
          value: clipsBloc,
          child: const LibraryTrashScreen(),
        ),
      ),
    );
    // Refresh active clips when returning so any restores show up.
    if (!context.mounted) return;
    clipsBloc.add(
      ClipsLibraryLoadRequested(
        preSelectedIds: clipsBloc.state.preSelectedIds,
        disabledClipIds: clipsBloc.state.disabledClipIds,
      ),
    );
  }

  /// Value of the sort-menu row that leads to the grid size options.
  ///
  /// Not a [ClipSort], so it can never collide with a sort key.
  static const _gridSizeMenuValue = 'grid-size';

  Future<void> _openSortMenu(
    BuildContext context,
    ClipsLibraryBloc clipsBloc,
    ClipSort currentSort,
    int currentColumns,
  ) async {
    final selected = await VineBottomSheetSelectionMenu.show(
      context: context,
      selectedValue: currentSort.persistenceKey,
      options: [
        VineBottomSheetSelectionOptionData(
          label: context.l10n.librarySortNewestCreation,
          value: ClipSort.newestCreation.persistenceKey,
          leadingIcon: .arrowFatLineDown,
        ),
        VineBottomSheetSelectionOptionData(
          label: context.l10n.librarySortOldestCreation,
          value: ClipSort.oldestCreation.persistenceKey,
          leadingIcon: .arrowFatLineUp,
        ),
        VineBottomSheetSelectionOptionData(
          label: context.l10n.librarySortLongestClip,
          value: ClipSort.longestClip.persistenceKey,
          leadingIcon: .arrowUp,
        ),
        VineBottomSheetSelectionOptionData(
          label: context.l10n.librarySortShortestClip,
          value: ClipSort.shortestClip.persistenceKey,
          leadingIcon: .arrowDown,
        ),
        VineBottomSheetSelectionOptionData(
          label: context.l10n.librarySortSquareFirst,
          value: ClipSort.squareFirst.persistenceKey,
          leadingIcon: .cropSquare,
        ),
        VineBottomSheetSelectionOptionData(
          label: context.l10n.librarySortVerticalFirst,
          value: ClipSort.verticalFirst.persistenceKey,
          leadingIcon: .cropPortrait,
        ),
        // Sort order and grid density are both "how this grid is shown", so
        // they share the one toolbar affordance. A button of its own would
        // have to fit a row that already collapses its title to nothing.
        VineBottomSheetSelectionOptionData(
          label: context.l10n.libraryGridSizeLabel,
          value: _gridSizeMenuValue,
          leadingIcon: .gridNine,
        ),
      ],
    );

    if (selected == null) return;
    if (selected == _gridSizeMenuValue) {
      if (!context.mounted) return;
      await _openGridSizeMenu(context, clipsBloc, currentColumns);
      return;
    }
    clipsBloc.add(
      ClipsLibrarySortChanged(ClipSort.fromPersistenceKey(selected)),
    );
  }

  /// The way to the column count that does not need a pinch.
  ///
  /// Pinching the grid is the primary gesture, but assistive technology
  /// cannot perform it, and the count is a persisted preference rather than a
  /// transient view state — without this it would be one a screen-reader user
  /// could never set.
  Future<void> _openGridSizeMenu(
    BuildContext context,
    ClipsLibraryBloc clipsBloc,
    int currentColumns,
  ) async {
    final selected = await VineBottomSheetSelectionMenu.show(
      context: context,
      selectedValue: '$currentColumns',
      options: [
        for (
          var columns = ClipGridColumns.min;
          columns <= ClipGridColumns.max;
          columns++
        )
          VineBottomSheetSelectionOptionData(
            label: context.l10n.libraryGridSizeColumns(columns),
            value: '$columns',
            leadingIcon: .gridNine,
          ),
      ],
    );

    final columns = int.tryParse(selected ?? '');
    if (columns == null) return;
    clipsBloc.add(ClipsLibraryGridColumnsChanged(columns));
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
      // Drop unreadable stills (deleted / zero-byte captures), then collapse
      // multiple stop-motion sets into one frames clip: the frame-first
      // editor edits a single frames list (the shape a recorder session
      // produces), so each set's stills line up on one timeline.
      final usableClips = [
        for (final clip in selectedClips)
          ?StopMotionFrameOps.sanitizedClip(clip),
      ];
      final merged = StopMotionFrameOps.mergeClips(usableClips);
      for (final clip in merged != null ? [merged] : usableClips) {
        clipManagerNotifier.insertClip(clipManagerNotifier.clips.length, clip);
      }
    }

    if (widget.selectionMode) {
      final disabledIds = widget.editorClips.map((c) => c.id).toSet();
      final newClips = selectedClips
          .where((c) => !disabledIds.contains(c.id))
          .toList();
      clipsBloc.add(const ClipsLibraryClearSelection());
      if (!context.mounted) return;
      context.pop(newClips);
    } else {
      if (!context.mounted) return;
      await context.push(VideoEditorScreen.path, extra: {'fromLibrary': true});
      // Re-sync selection with ClipManager after returning from editor.
      if (!context.mounted) return;
      final currentClipIds = ref
          .read(clipManagerProvider)
          .clips
          .map((c) => c.id)
          .toSet();
      clipsBloc.add(ClipsLibraryLoadRequested(preSelectedIds: currentClipIds));
    }
  }

  void _exitLibrarySelectionMode(ClipsLibraryBloc clipsBloc) {
    clipsBloc.add(const ClipsLibraryExitSelectionMode());
  }

  void _softDeleteSelectedClips(ClipsLibraryBloc clipsBloc) {
    // No confirm dialog: the bloc soft-deletes to the trash bin and the
    // snackbar listener below surfaces an Undo affordance.
    clipsBloc.add(const ClipsLibraryDeleteSelected());
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

    final clipsBloc = context.read<ClipsLibraryBloc>();

    return MultiBlocListener(
      listeners: [
        BlocListener<ClipsLibraryBloc, ClipsLibraryState>(
          listenWhen: (prev, curr) =>
              _shouldAutoOpenSelectionMode &&
              !curr.didAutoOpenSelectionMode &&
              prev.selectedClipIds.isEmpty &&
              curr.selectedClipIds.isNotEmpty,
          listener: (context, state) {
            if (!mounted || state.isLibrarySelectionMode) return;
            context.read<ClipsLibraryBloc>().add(
              const ClipsLibraryAutoOpenSelectionMode(),
            );
          },
        ),
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
                    ? context.l10n.libraryClipsSavedToDestination(
                        successCount,
                        GallerySaveService.destinationName,
                      )
                    : context.l10n.libraryClipsSavePartialResult(
                        successCount,
                        failureCount,
                      );
                _showSnackBar(context, label: label, error: failureCount > 0);
              case GallerySaveResultPermissionDenied():
                _showSnackBar(
                  context,
                  label: context.l10n.libraryGalleryPermissionDenied(
                    GallerySaveService.destinationName,
                  ),
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
            final deletedIds = state.lastDeletedClipIds;
            final messenger = ScaffoldMessenger.of(context);

            _showSnackBar(
              context,
              label: context.l10n.libraryClipsDeletedCount(count),
              actionLabel: deletedIds.isEmpty
                  ? null
                  : context.l10n.libraryClipsDeletedUndoLabel,
              onActionPressed: deletedIds.isEmpty
                  ? null
                  : () {
                      messenger.hideCurrentSnackBar();
                      // The delete snackbar is shown on the app-level
                      // ScaffoldMessenger, so it can outlive this screen. If
                      // the user navigated away the bloc is already closed —
                      // adding to it would throw. Undo is a no-op then.
                      if (clipsBloc.isClosed) return;
                      clipsBloc.add(ClipsLibraryRestoreClips(deletedIds));
                    },
            );
          },
        ),
      ],
      child: BlocBuilder<ClipsLibraryBloc, ClipsLibraryState>(
        builder: (context, clipsState) {
          final isClipsTabActive = _isClipsTabActive;
          final isLibrarySelectionMode = clipsState.isLibrarySelectionMode;
          final selectionLockedToCloseOnly = _isSelectionModeLockedToCloseOnly(
            clipsState,
          );
          final selectionEnabled = _isSelectionEnabled(clipsState);

          final sortedClips = clipsState.sortedClips;
          final targetAspectRatio =
              widget.selectionMode && editorClips.isNotEmpty
              ? editorClips.first.targetAspectRatio.value
              : clipsState.selectedClipIds.isNotEmpty
              ? sortedClips
                    .firstWhere(
                      (el) => el.id == clipsState.selectedClipIds.first,
                      orElse: () => sortedClips.first,
                    )
                    .targetAspectRatio
                    .value
              : null;

          return Scaffold(
            backgroundColor: context.vineColors.surface,
            body: Stack(
              children: [
                Material(
                  color: context.vineColors.surface,
                  child: SafeArea(
                    bottom: false,
                    child: Column(
                      children: [
                        if (!widget.selectionMode)
                          LibraryToolbar(
                            isLibrarySelectionMode: isLibrarySelectionMode,
                            canExitSelectionMode: !selectionLockedToCloseOnly,
                            isClipsTabActive: isClipsTabActive,
                            onLeadingPressed: () {
                              if (isLibrarySelectionMode &&
                                  !selectionLockedToCloseOnly) {
                                _exitLibrarySelectionMode(clipsBloc);
                                return;
                              }
                              if (context.canPop()) {
                                context.pop();
                              } else {
                                context.go(VideoFeedPage.pathForIndex(0));
                              }
                            },
                            onOpenSortMenu: () => _openSortMenu(
                              context,
                              clipsBloc,
                              clipsState.clipSort,
                              clipsState.gridColumnCount,
                            ),
                            onEnterSelectionMode: () => clipsBloc.add(
                              const ClipsLibraryEnterSelectionMode(),
                            ),
                            onOpenTrash: () => _openTrash(context, clipsBloc),
                            onDeleteSelectedClips:
                                clipsState.selectedClipIds.isNotEmpty
                                ? () => _softDeleteSelectedClips(clipsBloc)
                                : null,
                          ),
                        Expanded(
                          child: _LibraryContent(
                            tabs: _tabs,
                            tabController: tabController,
                            selectionMode: widget.selectionMode,
                            scrollController: widget.scrollController,
                            targetAspectRatio: targetAspectRatio,
                            sortedClips: sortedClips,
                            selectionEnabled: selectionEnabled,
                            onCreateVideo: () => _createVideoFromSelected(
                              context,
                              selectedClips: clipsState.selectedClips,
                              clipsBloc: clipsBloc,
                            ),
                          ),
                        ),
                        _CreateVideoBar(
                          visible:
                              !widget.selectionMode &&
                              selectionEnabled &&
                              isClipsTabActive &&
                              clipsState.selectedClipIds.isNotEmpty,
                          onPressed: () => _createVideoFromSelected(
                            context,
                            selectedClips: clipsState.selectedClips,
                            clipsBloc: clipsBloc,
                          ),
                        ),
                      ],
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
                              context.l10n.libraryPreparingVideo,
                              style: VineTheme.bodyMediumFont(
                                color: context.vineColors.primaryText,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LibraryContent extends StatelessWidget {
  const _LibraryContent({
    required this.tabs,
    required this.tabController,
    required this.selectionMode,
    required this.sortedClips,
    required this.selectionEnabled,
    required this.onCreateVideo,
    this.scrollController,
    this.targetAspectRatio,
  });

  final List<_LibraryTab> tabs;
  final TabController tabController;
  final bool selectionMode;
  final List<DivineVideoClip> sortedClips;
  final bool selectionEnabled;
  final VoidCallback onCreateVideo;
  final ScrollController? scrollController;
  final double? targetAspectRatio;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!selectionMode) const SizedBox(height: 12),
        if (!selectionMode)
          TabBar(
            controller: tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            padding: const EdgeInsetsDirectional.only(start: 16),
            indicatorColor: VineTheme.tabIndicatorGreen,
            indicatorWeight: 4,
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: VineTheme.transparent,
            labelColor: context.vineColors.primaryText,
            unselectedLabelColor: context.vineColors.onSurfaceMuted,
            labelPadding: const EdgeInsets.symmetric(horizontal: 14),
            labelStyle: VineTheme.titleMediumFont(
              color: context.vineColors.primaryText,
            ),
            unselectedLabelStyle: VineTheme.titleMediumFont(
              color: context.vineColors.onSurfaceMuted,
            ),
            tabs: [
              for (final tab in tabs)
                Tab(
                  text: switch (tab) {
                    _LibraryTab.drafts => context.l10n.libraryTabDrafts,
                    _LibraryTab.clips => context.l10n.libraryTabClips,
                    _LibraryTab.sounds => context.l10n.soundsTitle,
                  },
                ),
            ],
          ),
        if (!selectionMode) const SizedBox(height: 2),
        Expanded(
          child: selectionMode
              ? _SelectionBody(
                  scrollController: scrollController,
                  targetAspectRatio: targetAspectRatio,
                  onCreate: onCreateVideo,
                )
              : _TabBody(
                  clips: sortedClips,
                  selectionEnabled: selectionEnabled,
                  tabs: tabs,
                  tabController: tabController,
                  targetAspectRatio: targetAspectRatio,
                ),
        ),
      ],
    );

    // Selection mode renders inside a bottom sheet, which brings its own
    // surface and rounded corners. Skipping the shell here keeps the sheet's
    // colour showing through and stops the 32px corner radius from slicing
    // the top row of thumbnails.
    if (selectionMode) return content;

    // A Material rather than a ColoredBox: the tabs host ink-reactive rows
    // (draft tiles, clip cards), and an opaque box here would swallow their
    // splashes by painting over the Material further up the tree.
    return ClipRRect(
      borderRadius: const BorderRadius.all(
        Radius.circular(VineTheme.shellInnerCornerRadius),
      ),
      child: Material(
        color: context.vineColors.surfaceContainerHigh,
        child: content,
      ),
    );
  }
}

class _CreateVideoBar extends StatelessWidget {
  const _CreateVideoBar({required this.visible, required this.onPressed});

  final bool visible;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 120),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SizeTransition(
          sizeFactor: animation,
          alignment: AlignmentDirectional.topStart,
          child: child,
        ),
      ),
      child: visible
          ? SafeArea(
              top: false,
              child: ColoredBox(
                color: context.vineColors.surface,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: DivineButton(
                    expanded: true,
                    label: context.l10n.libraryCreateVideo,
                    onPressed: onPressed,
                  ),
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}

/// Full-screen message when Library is opened on web (drafts/clips are device-local).
class _LibraryWebUnavailableScreen extends StatelessWidget {
  const _LibraryWebUnavailableScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.vineColors.surface,
      appBar: DiVineAppBar(
        title: context.l10n.profileMyLibraryLabel,
        // No background override: the default `nav` surface already matches
        // the scaffold's `surface` in both appearance modes, so the bar stays
        // flush with the page.
        surfaceTintColor: VineTheme.transparent,
        shape: Border(
          bottom: BorderSide(color: context.vineColors.outlineDisabled),
        ),
        showBackButton: true,
        onBackPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go(VideoFeedPage.pathForIndex(0));
          }
        },
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 12,
            children: [
              Text(
                context.l10n.libraryWebUnavailableHeadline,
                textAlign: TextAlign.center,
                style: VineTheme.titleMediumFont(
                  color: context.vineColors.primaryText,
                ),
              ),
              Text(
                context.l10n.libraryWebUnavailableDescription,
                textAlign: TextAlign.center,
                style: VineTheme.bodyLargeFont(
                  color: context.vineColors.secondaryText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectionBody extends StatelessWidget {
  const _SelectionBody({
    required this.onCreate,
    this.targetAspectRatio,
    this.scrollController,
  });

  final VoidCallback onCreate;
  final double? targetAspectRatio;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ClipsTab(
            targetAspectRatio: targetAspectRatio,
            showRecordButton: true,
            // Selection mode renders straight onto the bottom sheet's own
            // surface; the library shell below is not in the tree here.
            backgroundColor: context.vineColors.surface,
            scrollController: scrollController,
            gridTopPadding: 8,
          ),
        ),
        ClipSelectionFooter(onCreate: onCreate),
      ],
    );
  }
}

class _TabBody extends StatefulWidget {
  const _TabBody({
    required this.tabController,
    required this.tabs,
    required this.clips,
    required this.selectionEnabled,
    this.targetAspectRatio,
  });

  final TabController tabController;
  final List<_LibraryTab> tabs;
  final List<DivineVideoClip> clips;
  final bool selectionEnabled;
  final double? targetAspectRatio;

  @override
  State<_TabBody> createState() => _TabBodyState();
}

class _TabBodyState extends State<_TabBody> {
  /// Whether the clips grid is being pinched right now.
  ///
  /// A pinch and a page swipe compete for the same pointers, and the swipe
  /// reads a two-finger spread as a horizontal drag. Suspending it for the
  /// duration of the pinch keeps the tabs still while the grid zooms.
  bool _isPinching = false;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<PinchZoomNotification>(
      onNotification: (notification) {
        if (notification.active != _isPinching) {
          setState(() => _isPinching = notification.active);
        }
        return false;
      },
      child: TabBarView(
        controller: widget.tabController,
        physics: _isPinching ? const NeverScrollableScrollPhysics() : null,
        children: [
          for (final tab in widget.tabs)
            switch (tab) {
              _LibraryTab.drafts => const DraftsTab(showRecordButton: false),
              _LibraryTab.clips => ClipsTab(
                clips: widget.clips,
                selectionEnabled: widget.selectionEnabled,
                targetAspectRatio: widget.targetAspectRatio,
                showRecordButton: false,
                // Matches the shell _LibraryContent paints behind the tabs.
                backgroundColor: context.vineColors.surfaceContainerHigh,
              ),
              _LibraryTab.sounds => const SoundsTab(),
            },
        ],
      ),
    );
  }
}
