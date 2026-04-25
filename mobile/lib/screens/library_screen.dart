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
import 'package:openvine/providers/video_publish_provider.dart';
import 'package:openvine/screens/feed/video_feed_page.dart';
import 'package:openvine/screens/video_editor/video_editor_screen.dart';
import 'package:openvine/services/gallery_save_service.dart';
import 'package:openvine/widgets/library/library.dart';
import 'package:unified_logger/unified_logger.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  /// Route name for drafts path.
  static const draftsRouteName = 'drafts';

  /// Path for drafts route.
  static const draftsPath = '/drafts';

  /// Route name for clips path.
  static const clipsRouteName = 'clips';

  /// Path for clips route.
  static const clipsPath = '/clips';

  /// Route name for clips path without Sounds tab.
  static const clipsNoSoundRouteName = 'clipsNoSound';

  /// Path for clips route without Sounds tab.
  static const clipsNoSoundPath = '/clips-no-sound';

  /// Route name for sounds path.
  static const soundsRouteName = 'sounds';

  /// Path for sounds route.
  static const soundsPath = '/sounds';

  const LibraryScreen({
    super.key,
    this.initialTabIndex = 0,
    this.selectionMode = false,
    this.enableSoundTab = true,
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

  /// Whether the Sounds tab is visible.
  final bool enableSoundTab;

  /// Current editor clips, used to calculate remaining duration and
  /// target aspect ratio in selection mode.
  final List<DivineVideoClip> editorClips;

  /// Optional scroll controller, e.g. from a parent [DraggableScrollableSheet].
  final ScrollController? scrollController;

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
      length: widget.enableSoundTab ? 3 : 2,
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

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const _LibraryWebUnavailableScreen();
    }

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
              ClipsLibraryLoadRequested(
                preSelectedIds: editorClipIds,
                disabledClipIds: widget.selectionMode
                    ? editorClipIds
                    : const {},
              ),
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
                          ? context.l10n.libraryClipsSavedToDestination(
                              successCount,
                              GallerySaveService.destinationName,
                            )
                          : context.l10n.libraryClipsSavePartialResult(
                              successCount,
                              failureCount,
                            );
                      _showSnackBar(
                        context,
                        label: label,
                        error: failureCount > 0,
                      );
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

                  _showSnackBar(
                    context,
                    label: context.l10n.libraryClipsDeletedCount(count),
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
                              enableSoundTab: widget.enableSoundTab,
                              onNext: () => _createVideoFromSelected(
                                context,
                                selectedClips: clipsState.selectedClips,
                                clipsBloc: clipsBloc,
                              ),
                            ),
                      body: widget.selectionMode
                          ? _SelectionBody(
                              scrollController: widget.scrollController,
                              targetAspectRatio: targetAspectRatio,
                              onCreate: () => _createVideoFromSelected(
                                context,
                                selectedClips: clipsState.selectedClips,
                                clipsBloc: clipsBloc,
                              ),
                            )
                          : _TabBody(
                              tabController: _tabController,
                              enableSoundTab: widget.enableSoundTab,
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
                                  context.l10n.libraryPreparingVideo,
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

/// Full-screen message when Library is opened on web (drafts/clips are device-local).
class _LibraryWebUnavailableScreen extends StatelessWidget {
  const _LibraryWebUnavailableScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VineTheme.onPrimary,
      appBar: DiVineAppBar(
        title: context.l10n.profileLibraryLabel,
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

class _LibraryAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _LibraryAppBar({
    required this.tabController,
    required this.onNext,
    this.enableSoundTab = true,
  });

  final TabController tabController;
  final VoidCallback onNext;
  final bool enableSoundTab;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 48);

  @override
  Widget build(BuildContext context) {
    return BlocSelector<ClipsLibraryBloc, ClipsLibraryState, bool>(
      selector: (state) => state.selectedClipIds.isNotEmpty,
      builder: (context, hasSelection) {
        return DiVineAppBar(
          title: context.l10n.profileLibraryLabel,
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
                    icon: SvgIconSource(DivineIconName.caretRight.assetPath),
                    onPressed: onNext,
                    tooltip: context.l10n.commonNext,
                    semanticLabel: context.l10n.commonNext,
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
            tabs: [
              Tab(text: context.l10n.libraryTabDrafts),
              Tab(text: context.l10n.libraryTabClips),
              if (enableSoundTab) Tab(text: context.l10n.soundsTitle),
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
    this.enableSoundTab = true,
    this.targetAspectRatio,
  });

  final TabController tabController;
  final bool enableSoundTab;
  final double? targetAspectRatio;

  @override
  Widget build(BuildContext context) {
    return TabBarView(
      controller: tabController,
      children: [
        const DraftsTab(showRecordButton: false, showAutosavedDraft: false),
        ClipsTab(targetAspectRatio: targetAspectRatio, showRecordButton: false),
        if (enableSoundTab) const SoundsTab(),
      ],
    );
  }
}
