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
import 'package:openvine/models/divine_video_clip.dart';
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

enum LibraryTabsMode { allTabs, clipsOnly }

class LibraryScreen extends ConsumerWidget {
  /// Route name for drafts path.
  static const draftsRouteName = 'drafts';

  /// Path for drafts route.
  static const draftsPath = '/drafts';

  /// Route name for clips path.
  static const clipsRouteName = 'clips';

  /// Path for clips route.
  static const clipsPath = '/clips';

  /// Route name for clips-only path.
  static const clipsOnlyRouteName = 'clipsOnly';

  /// Path for clips-only route.
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
          key: ValueKey((clipLibraryService, gallerySaveService)),
          create: (_) {
            final editorClipIds = selectionMode
                ? editorClips.map((c) => c.id).toSet()
                : ref.read(clipManagerProvider).clips.map((c) => c.id).toSet();
            return ClipsLibraryBloc(
              clipLibraryService: clipLibraryService,
              gallerySaveService: gallerySaveService,
              sharedPreferences: ref.read(sharedPreferencesProvider),
            )..add(
              ClipsLibraryLoadRequested(
                preSelectedIds: editorClipIds,
                disabledClipIds: selectionMode ? editorClipIds : const {},
              ),
            );
          },
        ),
        BlocProvider<DraftsLibraryBloc>(
          key: ValueKey(draftStorageService),
          create: (_) =>
              DraftsLibraryBloc(draftStorageService: draftStorageService)
                ..add(const DraftsLibraryLoadRequested()),
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
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late int _activeTabIndex;

  bool get _isClipsOnlyMode =>
      widget.selectionMode || widget.tabsMode == LibraryTabsMode.clipsOnly;

  bool get _shouldAutoOpenSelectionMode =>
      !widget.selectionMode && widget.tabsMode == LibraryTabsMode.clipsOnly;

  bool _isSelectionEnabled(ClipsLibraryState state) =>
      widget.selectionMode || state.isLibrarySelectionMode;

  bool _isSelectionModeLockedToCloseOnly(ClipsLibraryState state) =>
      _shouldAutoOpenSelectionMode &&
      state.didAutoOpenSelectionMode &&
      state.isLibrarySelectionMode;

  @override
  void initState() {
    super.initState();
    final initialIndex = _isClipsOnlyMode
        ? 0
        : widget.initialTabIndex.clamp(0, 2);
    _activeTabIndex = initialIndex;
    _tabController = TabController(
      length: _isClipsOnlyMode ? 1 : 3,
      initialIndex: initialIndex,
      vsync: this,
    )..addListener(_onTabChanged);

    Log.info(
      '📚 ClipLibrary opened (selectionMode: ${widget.selectionMode})',
      name: 'LibraryScreen',
      category: LogCategory.video,
    );
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!mounted) return;
    if (_activeTabIndex == _tabController.index) return;
    setState(() {
      _activeTabIndex = _tabController.index;
    });

    final clipsBloc = context.read<ClipsLibraryBloc>();
    final clipsState = clipsBloc.state;
    final isClipsTabActive = _isClipsOnlyMode || _tabController.index == 1;
    if (!widget.selectionMode &&
        !_isClipsOnlyMode &&
        clipsState.isLibrarySelectionMode &&
        !isClipsTabActive) {
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

  Future<void> _openSortMenu(
    BuildContext context,
    ClipsLibraryBloc clipsBloc,
    ClipSort currentSort,
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
      ],
    );

    if (selected == null) return;
    clipsBloc.add(
      ClipsLibrarySortChanged(ClipSort.fromPersistenceKey(selected)),
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
          final isClipsTabActive = _isClipsOnlyMode || _activeTabIndex == 1;
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
            backgroundColor: VineTheme.onPrimary,
            body: Stack(
              children: [
                Material(
                  color: VineTheme.onPrimary,
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
                            isClipsOnlyMode: _isClipsOnlyMode,
                            tabController: _tabController,
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
                              (_activeTabIndex == 1 ||
                                  widget.tabsMode ==
                                      LibraryTabsMode.clipsOnly) &&
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
                              style: VineTheme.bodyMediumFont(),
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
    required this.isClipsOnlyMode,
    required this.tabController,
    required this.selectionMode,
    required this.sortedClips,
    required this.selectionEnabled,
    required this.onCreateVideo,
    this.scrollController,
    this.targetAspectRatio,
  });

  final bool isClipsOnlyMode;
  final TabController tabController;
  final bool selectionMode;
  final List<DivineVideoClip> sortedClips;
  final bool selectionEnabled;
  final VoidCallback onCreateVideo;
  final ScrollController? scrollController;
  final double? targetAspectRatio;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.all(
        Radius.circular(VineTheme.shellInnerCornerRadius),
      ),
      child: ColoredBox(
        color: VineTheme.surfaceContainerHigh,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!isClipsOnlyMode) const SizedBox(height: 12),
            if (!isClipsOnlyMode)
              TabBar(
                controller: tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                padding: const EdgeInsetsDirectional.only(start: 16),
                indicatorColor: VineTheme.tabIndicatorGreen,
                indicatorWeight: 4,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: VineTheme.transparent,
                labelColor: VineTheme.whiteText,
                unselectedLabelColor: VineTheme.onSurfaceMuted55,
                labelPadding: const EdgeInsets.symmetric(horizontal: 14),
                labelStyle: VineTheme.titleMediumFont(),
                unselectedLabelStyle: VineTheme.titleMediumFont(
                  color: VineTheme.onSurfaceMuted55,
                ),
                tabs: [
                  Tab(text: context.l10n.libraryTabDrafts),
                  Tab(text: context.l10n.libraryTabClips),
                  Tab(text: context.l10n.soundsTitle),
                ],
              ),
            if (!isClipsOnlyMode) const SizedBox(height: 2),
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
                      isClipsOnlyMode: isClipsOnlyMode,
                      tabController: tabController,
                      targetAspectRatio: targetAspectRatio,
                    ),
            ),
          ],
        ),
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
                color: VineTheme.onPrimary,
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
      backgroundColor: VineTheme.onPrimary,
      appBar: DiVineAppBar(
        title: context.l10n.profileMyLibraryLabel,
        backgroundColor: VineTheme.onPrimary,
        surfaceTintColor: VineTheme.transparent,
        shape: const Border(
          bottom: BorderSide(color: VineTheme.outlineDisabled),
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
                style: VineTheme.titleMediumFont(),
              ),
              Text(
                context.l10n.libraryWebUnavailableDescription,
                textAlign: TextAlign.center,
                style: VineTheme.bodyLargeFont(color: VineTheme.secondaryText),
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
        ClipSelectionHeader(onCreate: onCreate),
        Expanded(
          child: ClipsTab(
            targetAspectRatio: targetAspectRatio,
            showRecordButton: true,
            scrollController: scrollController,
          ),
        ),
      ],
    );
  }
}

class _TabBody extends StatelessWidget {
  const _TabBody({
    required this.tabController,
    required this.isClipsOnlyMode,
    required this.clips,
    required this.selectionEnabled,
    this.targetAspectRatio,
  });

  final TabController tabController;
  final bool isClipsOnlyMode;
  final List<DivineVideoClip> clips;
  final bool selectionEnabled;
  final double? targetAspectRatio;

  @override
  Widget build(BuildContext context) {
    if (isClipsOnlyMode) {
      return ClipsTab(
        clips: clips,
        selectionEnabled: selectionEnabled,
        targetAspectRatio: targetAspectRatio,
        showRecordButton: false,
      );
    }

    return TabBarView(
      controller: tabController,
      children: [
        const DraftsTab(showRecordButton: false, showAutosavedDraft: false),
        ClipsTab(
          clips: clips,
          selectionEnabled: selectionEnabled,
          targetAspectRatio: targetAspectRatio,
          showRecordButton: false,
        ),
        const SoundsTab(),
      ],
    );
  }
}
