// ABOUTME: Screen for displaying videos from a curated NIP-51 kind 30005 list
// ABOUTME: Hero header + masonry grid, owner actions sheet, manage-posts mode

import 'package:divine_ui/divine_ui.dart';
import 'package:feed_repository/feed_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsService;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/blocs/curated_list_manage_posts/curated_list_manage_posts_cubit.dart';
import 'package:openvine/extensions/modal_pop_extension.dart';
import 'package:openvine/extensions/safe_pop_extension.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/view_traffic_source.dart';
import 'package:openvine/providers/analytics_providers.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/list_providers.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/screens/curated_list_by_author_screen.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/screens/other_profile_screen.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/utils/pause_aware_modals.dart';
import 'package:openvine/utils/share_sheet.dart';
import 'package:openvine/widgets/add_to_list_dialog.dart';
import 'package:openvine/widgets/composable_video_grid.dart';
import 'package:openvine/widgets/user_name.dart';
import 'package:unified_logger/unified_logger.dart';

/// Owner actions offered by the `...` bottom sheet.
enum _CuratedListAction { editInfo, managePosts, share, delete }

class CuratedListFeedScreen extends ConsumerStatefulWidget {
  /// Route name for this screen.
  static const routeName = 'list';

  /// Base path for list routes.
  static const String basePath = RoutePaths.curatedListFeedBase;

  /// Path for this route.
  static const path = '/list/:listId';

  /// Build path for a specific list.
  static String pathForId(String listId) =>
      RoutePaths.curatedListFeedForId(listId);

  const CuratedListFeedScreen({
    required this.listId,
    required this.listName,
    this.videoIds,
    this.authorPubkey,
    super.key,
  });

  final String listId;
  final String listName;

  /// Optional video IDs to display directly (for discovered lists not in local storage)
  final List<String>? videoIds;

  /// Optional author pubkey to display who created the list
  final String? authorPubkey;

  @override
  ConsumerState<CuratedListFeedScreen> createState() =>
      _CuratedListFeedScreenState();
}

class _CuratedListFeedScreenState extends ConsumerState<CuratedListFeedScreen> {
  int? _activeVideoIndex;
  bool _isTogglingSubscription = false;

  /// Live while manage-posts mode is active; each entry into the mode gets a
  /// fresh cubit so the captured service never outlives its auth session.
  CuratedListManagePostsCubit? _manageCubit;

  bool get _managing => _manageCubit != null;

  @override
  void dispose() {
    _manageCubit?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use direct video IDs if provided (for discovered lists not in local storage)
    // Otherwise look up by list ID from local storage
    final videosAsync = widget.videoIds != null
        ? ref.watch(videoEventsByIdsProvider(widget.videoIds!))
        : ref.watch(curatedListVideoEventsProvider(widget.listId));

    final serviceAsync = ref.watch(curatedListsStateProvider);
    final service = ref.read(curatedListsStateProvider.notifier).service;
    final isOwned =
        serviceAsync.whenOrNull(
          data: (_) => service?.isOwnedList(widget.listId),
        ) ??
        false;
    final isSubscribed =
        serviceAsync.whenOrNull(
          data: (_) => service?.isSubscribedToList(widget.listId),
        ) ??
        false;
    final list = _localList();
    final isShareable = (list?.isPublic ?? false) && list?.pubkey != null;

    final PreferredSizeWidget? appBar;
    if (_activeVideoIndex != null) {
      appBar = null;
    } else if (_managing) {
      appBar = DiVineAppBar(
        titleWidget: Text(
          list?.name ?? widget.listName,
          style: VineTheme.titleLargeFont(color: context.vineColors.onNav),
        ),
        showBackButton: true,
        onBackPressed: _exitManageMode,
      );
    } else {
      appBar = DiVineAppBar(
        // The list title lives in the hero header below, so this bar is
        // intentionally title-less; the empty widget satisfies the app bar's
        // title-or-titleWidget contract without rendering anything.
        titleWidget: const SizedBox.shrink(),
        showBackButton: true,
        // safePop: on a cold-start deep link this screen can be the only
        // route, and a raw pop would throw GoError.
        onBackPressed: context.safePop,
        actions: [
          if (!isOwned && isShareable)
            DiVineAppBarAction(
              icon: SvgIconSource(DivineIconName.share.assetPath),
              onPressed: _shareList,
              tooltip: context.l10n.listShareAction,
            ),
          if (isOwned)
            DiVineAppBarAction(
              icon: SvgIconSource(DivineIconName.dotsThree.assetPath),
              onPressed: _showOwnerActions,
              tooltip: context.l10n.curatedListActionsTooltip,
            ),
        ],
        customActions: [
          if (!isOwned)
            _FollowListButton(
              isSubscribed: isSubscribed,
              isBusy: _isTogglingSubscription,
              onPressed: _toggleSubscription,
            ),
        ],
      );
    }

    final scaffold = Scaffold(
      backgroundColor: context.vineColors.background,
      appBar: appBar,
      body: videosAsync.when(
        // Keep the current grid on screen while the provider re-runs after a
        // blocklist version bump, instead of flashing the spinner and resetting
        // scroll (#5104).
        skipLoadingOnReload: true,
        data: (videos) {
          ref
              .read(screenAnalyticsServiceProvider)
              .markDataLoaded(
                'curated_list',
                dataMetrics: {'video_count': videos.length},
              );

          // If in video mode, show fullscreen video player
          if (_activeVideoIndex != null) {
            return _ListVideoPlayerMode(
              videos: videos,
              activeIndex: _activeVideoIndex!,
              listName: widget.listName,
              onExit: _exitVideoMode,
            );
          }

          if (_manageCubit case final cubit?) {
            return BlocSelector<
              CuratedListManagePostsCubit,
              CuratedListManagePostsState,
              Set<String>
            >(
              bloc: cubit,
              selector: (state) => state.selectedVideoIds,
              builder: (context, selectedVideoIds) => ComposableVideoGrid(
                videos: videos,
                useMasonryLayout: true,
                selectedVideoIds: selectedVideoIds,
                onVideoTap: (videoList, index) =>
                    cubit.togglePost(videoList[index].id),
                emptyBuilder: () => const _EmptyListMessage(),
              ),
            );
          }

          return ComposableVideoGrid(
            videos: videos,
            useMasonryLayout: true,
            headerSlivers: [
              SliverToBoxAdapter(
                child: _ListHeroHeader(
                  name: list?.name ?? widget.listName,
                  videoCount:
                      widget.videoIds?.length ??
                      list?.videoEventIds.length ??
                      0,
                  description: list?.description,
                  authorPubkey: isOwned
                      ? null
                      : widget.authorPubkey ?? list?.pubkey,
                  isPublic: list?.isPublic,
                  onAuthorTap: _openAuthorProfile,
                ),
              ),
            ],
            onVideoTap: (videoList, index) {
              Log.info(
                'Tapped video in curated list: ${videoList[index].id}',
                category: LogCategory.ui,
              );
              setState(() {
                _activeVideoIndex = index;
              });
            },
            onRefresh: () async {
              // Refresh by invalidating the provider
              ref.invalidate(curatedListVideoEventsProvider(widget.listId));
            },
            emptyBuilder: () => const _EmptyListMessage(),
          );
        },
        loading: () => const _ListLoadingView(),
        error: (error, stack) => _ListErrorView(
          error: error,
          onRetry: () {
            ref.invalidate(curatedListVideoEventsProvider(widget.listId));
          },
        ),
      ),
      bottomNavigationBar: _manageCubit == null
          ? null
          : _ManageRemoveBar(cubit: _manageCubit!),
    );

    final cubit = _manageCubit;
    if (cubit == null) {
      return scaffold;
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _exitManageMode();
      },
      child:
          BlocListener<
            CuratedListManagePostsCubit,
            CuratedListManagePostsState
          >(
            bloc: cubit,
            listenWhen: (previous, current) =>
                previous.status != current.status &&
                (current.status == CuratedListManagePostsStatus.success ||
                    current.status == CuratedListManagePostsStatus.failure),
            listener: _onRemovalFinished,
            child: scaffold,
          ),
    );
  }

  void _exitVideoMode() {
    setState(() {
      _activeVideoIndex = null;
    });
  }

  void _openAuthorProfile(String authorPubkey) {
    final npub = NostrKeyUtils.encodePubKey(authorPubkey);
    context.push(OtherProfileScreen.pathForNpub(npub));
  }

  void _enterManageMode() {
    final service = ref.read(curatedListsStateProvider.notifier).service;
    if (service == null || _managing) {
      return;
    }
    setState(() {
      _manageCubit = CuratedListManagePostsCubit(
        service: service,
        listId: widget.listId,
      );
    });
    SemanticsService.sendAnnouncement(
      View.of(context),
      context.l10n.listManagePostsAction,
      Directionality.of(context),
    );
  }

  void _exitManageMode() {
    final cubit = _manageCubit;
    if (cubit == null) {
      return;
    }
    setState(() {
      _manageCubit = null;
    });
    cubit.close();
  }

  void _onRemovalFinished(
    BuildContext context,
    CuratedListManagePostsState state,
  ) {
    final failed = state.status == CuratedListManagePostsStatus.failure;
    // On failure some removals may still have landed, so refresh either way.
    ref.invalidate(curatedListVideoEventsProvider(widget.listId));
    final message = failed
        ? context.l10n.listRemovePostsFailure(state.failedCount)
        : context.l10n.listRemovePostsSuccess(state.removedCount);
    SemanticsService.sendAnnouncement(
      View.of(context),
      message,
      Directionality.of(context),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: failed ? VineTheme.error : VineTheme.vineGreen,
      ),
    );
    _exitManageMode();
  }

  CuratedList? _localList() => ref
      .read(curatedListsStateProvider.notifier)
      .service
      ?.getListById(widget.listId);

  Future<void> _showOwnerActions() async {
    final list = _localList();
    // Sharing needs an author pubkey for the canonical URL, so a public
    // list without one must not offer a no-op sheet entry.
    final isShareable = (list?.isPublic ?? false) && list?.pubkey != null;

    final action = await VineBottomSheet.show<_CuratedListAction>(
      context: context,
      expanded: false,
      scrollable: false,
      children: [
        _OwnerActionTile(
          identifier: 'list_edit_info_option',
          label: context.l10n.listEditInfoAction,
          icon: DivineIconName.info,
          action: _CuratedListAction.editInfo,
        ),
        _OwnerActionTile(
          identifier: 'list_manage_posts_option',
          label: context.l10n.listManagePostsAction,
          icon: DivineIconName.pencilSimple,
          action: _CuratedListAction.managePosts,
        ),
        if (isShareable)
          _OwnerActionTile(
            identifier: 'list_share_option',
            label: context.l10n.listShareAction,
            icon: DivineIconName.share,
            action: _CuratedListAction.share,
          ),
        _OwnerActionTile(
          identifier: 'list_delete_option',
          label: context.l10n.listDeleteAction,
          icon: DivineIconName.trash,
          action: _CuratedListAction.delete,
          isDestructive: true,
        ),
      ],
    );

    if (!mounted || action == null) {
      return;
    }
    switch (action) {
      case _CuratedListAction.editInfo:
        await _editList();
      case _CuratedListAction.managePosts:
        _enterManageMode();
      case _CuratedListAction.share:
        await _shareList();
      case _CuratedListAction.delete:
        await _confirmDeleteList();
    }
  }

  Future<void> _editList() async {
    final list = _localList();
    if (list == null) return;
    await context.showVideoPausingDialog<void>(
      builder: (_) => CreateListDialog(existingList: list),
    );
  }

  Future<void> _shareList() async {
    final list = _localList();
    final authorPubkey = list?.pubkey;
    if (list == null || !list.isPublic || authorPubkey == null) return;

    final path = CuratedListByAuthorScreen.pathFor(
      pubkey: authorPubkey,
      listId: list.id,
    );
    final url = 'https://divine.video$path';
    try {
      await showShareSheet(
        context,
        ShareParams(
          text: context.l10n.listShareText(list.name, url),
          subject: context.l10n.listShareSubject(list.name),
        ),
      );
    } catch (e) {
      Log.error('Failed to share list: $e', category: LogCategory.ui);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.listShareFailed)));
      }
    }
  }

  Future<void> _confirmDeleteList() async {
    final l10n = context.l10n;
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.vineColors.surfaceContainer,
        title: Text(
          l10n.curatedListDeleteConfirmTitle,
          style: VineTheme.titleMediumFont(
            color: context.vineColors.primaryText,
          ),
        ),
        content: Text(
          l10n.curatedListDeleteConfirmBody,
          style: VineTheme.bodyMediumFont(
            color: context.vineColors.secondaryText,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => dialogContext.popModalIfMounted(false),
            child: Text(
              l10n.commonCancel,
              style: VineTheme.labelMediumFont(
                color: context.vineColors.secondaryText,
              ),
            ),
          ),
          TextButton(
            onPressed: () => dialogContext.popModalIfMounted(true),
            child: Text(
              l10n.commonDelete,
              style: VineTheme.labelMediumFont(color: VineTheme.error),
            ),
          ),
        ],
      ),
    );

    if (shouldDelete != true || !mounted) {
      return;
    }

    await _deleteOwnedList();
  }

  Future<void> _deleteOwnedList() async {
    final service = ref.read(curatedListsStateProvider.notifier).service;
    final didDelete = await service?.deleteOwnedList(widget.listId) ?? false;

    if (!mounted) {
      return;
    }

    if (!didDelete) {
      final message = context.l10n.curatedListDeleteFailed;
      SemanticsService.sendAnnouncement(
        View.of(context),
        message,
        Directionality.of(context),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: VineTheme.error),
      );
      return;
    }

    ref.invalidate(curatedListsProvider);
    final message = context.l10n.curatedListDeletedSnack;
    SemanticsService.sendAnnouncement(
      View.of(context),
      message,
      Directionality.of(context),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: VineTheme.vineGreen),
    );

    if (context.canPop()) {
      context.pop();
    }
  }

  Future<void> _toggleSubscription() async {
    final service = ref.read(curatedListsStateProvider.notifier).service;
    if (service == null || _isTogglingSubscription) {
      return;
    }

    setState(() {
      _isTogglingSubscription = true;
    });

    try {
      if (service.isSubscribedToList(widget.listId)) {
        await service.unsubscribeFromList(widget.listId);
        Log.info(
          'Unsubscribed from list: ${widget.listName}',
          category: LogCategory.ui,
        );
      } else {
        final list =
            service.getListById(widget.listId) ??
            CuratedList(
              id: widget.listId,
              name: widget.listName,
              pubkey: widget.authorPubkey,
              videoEventIds: widget.videoIds ?? const [],
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
        await service.subscribeToList(widget.listId, list);
        Log.info(
          'Subscribed to list: ${widget.listName}',
          category: LogCategory.ui,
        );
      }

      // Invalidate providers so the Lists tab updates
      ref.invalidate(curatedListsProvider);
    } catch (e) {
      Log.error('Failed to toggle subscription: $e', category: LogCategory.ui);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.discoverListsFailedToUpdateSubscription),
            backgroundColor: VineTheme.likeRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTogglingSubscription = false;
        });
      }
    }
  }
}

/// Follow/Following pill shown to non-owners in the app bar.
class _FollowListButton extends StatelessWidget {
  const _FollowListButton({
    required this.isSubscribed,
    required this.isBusy,
    required this.onPressed,
  });

  final bool isSubscribed;
  final bool isBusy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DivineButton(
      label: isSubscribed
          ? context.l10n.listFollowingButton
          : context.l10n.listFollowButton,
      size: DivineButtonSize.small,
      type: isSubscribed
          ? DivineButtonType.secondary
          : DivineButtonType.primary,
      leadingIcon: isSubscribed ? DivineIconName.check : DivineIconName.plus,
      isLoading: isBusy,
      onPressed: isBusy ? null : onPressed,
    );
  }
}

/// Hero block scrolled with the grid: list title, video count, description
/// and the creator/visibility attribution.
class _ListHeroHeader extends StatelessWidget {
  const _ListHeroHeader({
    required this.name,
    required this.videoCount,
    this.description,
    this.authorPubkey,
    this.isPublic,
    this.onAuthorTap,
  });

  final String name;
  final int videoCount;
  final String? description;

  /// Creator to credit; `null` for an owned list (no self-attribution).
  final String? authorPubkey;

  /// List visibility; `null` when the list is not in local storage.
  final bool? isPublic;

  final ValueChanged<String>? onAuthorTap;

  @override
  Widget build(BuildContext context) {
    final description = this.description;
    final authorPubkey = this.authorPubkey;
    final isPublic = this.isPublic;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Text(
            name,
            style: VineTheme.headlineMediumFont(
              color: context.vineColors.primaryText,
            ),
          ),
          Text(
            context.l10n.listVideoCount(videoCount),
            style: VineTheme.titleSmallFont(
              color: context.vineColors.primaryText,
            ),
          ),
          if (description != null && description.isNotEmpty)
            Text(
              description,
              style: VineTheme.bodyMediumFont(
                color: context.vineColors.secondaryText,
              ),
            ),
          if (authorPubkey != null)
            _ListAuthorAttribution(
              authorPubkey: authorPubkey,
              onTap: () => onAuthorTap?.call(authorPubkey),
            )
          else if (isPublic != null)
            Text(
              isPublic
                  ? context.l10n.listVisibilityPublic
                  : context.l10n.listVisibilityPrivate,
              style: VineTheme.bodySmallFont(
                color: context.vineColors.secondaryText,
              ),
            ),
        ],
      ),
    );
  }
}

/// Tappable "By {creator}" row for a list the viewer does not own.
class _ListAuthorAttribution extends StatelessWidget {
  const _ListAuthorAttribution({
    required this.authorPubkey,
    required this.onTap,
  });

  final String authorPubkey;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.l10n.listByAuthorPrefix,
              style: VineTheme.bodySmallFont(
                color: context.vineColors.secondaryText,
              ),
            ),
            Flexible(
              child: UserName.fromPubKey(
                authorPubkey,
                style: VineTheme.bodySmallFont(
                  color: context.vineColors.primaryText,
                ).copyWith(fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One row of the owner actions sheet; pops the sheet with its [action].
class _OwnerActionTile extends StatelessWidget {
  const _OwnerActionTile({
    required this.identifier,
    required this.label,
    required this.icon,
    required this.action,
    this.isDestructive = false,
  });

  final String identifier;
  final String label;
  final DivineIconName icon;
  final _CuratedListAction action;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    // onErrorContainer, not fixed likeRed/error: the sheet surface follows
    // the palette and the token keeps destructive contrast in both
    // appearances (#7147, matching the comment options sheet).
    final color = isDestructive
        ? context.vineColors.onErrorContainer
        : context.vineColors.onSurface;

    void select() => Navigator.of(context).pop(action);

    return Semantics(
      identifier: identifier,
      button: true,
      label: label,
      // excludeSemantics drops the child subtree — including the
      // GestureDetector's tap action — so the action is re-declared here.
      onTap: select,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: select,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            spacing: 16,
            children: [
              DivineIcon(icon: icon, color: color),
              Expanded(
                child: Text(
                  label,
                  style: VineTheme.titleMediumFont(color: color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom bar in manage-posts mode: removes the selected posts.
class _ManageRemoveBar extends StatelessWidget {
  const _ManageRemoveBar({required this.cubit});

  final CuratedListManagePostsCubit cubit;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child:
          BlocBuilder<CuratedListManagePostsCubit, CuratedListManagePostsState>(
            bloc: cubit,
            builder: (context, state) {
              final count = state.selectedVideoIds.length;
              final removing =
                  state.status == CuratedListManagePostsStatus.removing;
              return DivineButton(
                label: context.l10n.listRemovePostsButton(count),
                type: DivineButtonType.secondary,
                expanded: true,
                isLoading: removing,
                onPressed: count == 0 || removing ? null : cubit.removeSelected,
              );
            },
          ),
    );
  }
}

/// Fullscreen playback mode for a tapped grid tile.
class _ListVideoPlayerMode extends StatelessWidget {
  const _ListVideoPlayerMode({
    required this.videos,
    required this.activeIndex,
    required this.listName,
    required this.onExit,
  });

  final List<VideoEvent> videos;
  final int activeIndex;
  final String listName;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    if (videos.isEmpty || activeIndex >= videos.length) {
      return Center(
        child: Text(
          context.l10n.curatedListVideoNotAvailable,
          style: VineTheme.bodyMediumFont(
            color: context.vineColors.secondaryText,
          ),
        ),
      );
    }

    // Embedded as this screen's "video mode": both the feed's own app-bar back
    // button ([onBack]) and the system back gesture ([PopScope]) return to the
    // grid instead of popping the whole route, so the user sees a single back
    // button and hardware back stays consistent with it.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        onExit();
      },
      child: PooledFullscreenVideoFeedScreen(
        source: VideoListViewSource(videos),
        feedRepository: StaticFeedRepository(),
        initialIndex: activeIndex,
        contextTitle: listName,
        trafficSource: ViewTrafficSource.search,
        onBack: onExit,
      ),
    );
  }
}

/// Empty-list body rendered under the hero header.
class _EmptyListMessage extends StatelessWidget {
  const _EmptyListMessage();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 8,
        children: [
          DivineIcon(
            icon: DivineIconName.filmSlate,
            size: 64,
            color: context.vineColors.secondaryText,
          ),
          Text(
            context.l10n.curatedListEmptyTitle,
            style: VineTheme.titleMediumFont(
              color: context.vineColors.primaryText,
            ),
          ),
          Text(
            context.l10n.curatedListEmptySubtitle,
            style: VineTheme.bodyMediumFont(
              color: context.vineColors.secondaryText,
            ),
          ),
        ],
      ),
    );
  }
}

/// Loading body shown while the list's videos resolve.
class _ListLoadingView extends StatelessWidget {
  const _ListLoadingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 16,
        children: [
          const CircularProgressIndicator(color: VineTheme.vineGreen),
          Text(
            context.l10n.curatedListLoadingVideos,
            style: VineTheme.bodyMediumFont(
              color: context.vineColors.secondaryText,
            ),
          ),
        ],
      ),
    );
  }
}

/// Error body with a retry affordance.
class _ListErrorView extends StatelessWidget {
  const _ListErrorView({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 8,
        children: [
          const DivineIcon(
            icon: DivineIconName.warningCircle,
            size: 64,
            color: VineTheme.likeRed,
          ),
          Text(
            context.l10n.curatedListFailedToLoad,
            style: VineTheme.titleMediumFont(color: VineTheme.likeRed),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              error.toString(),
              style: VineTheme.bodySmallFont(
                color: context.vineColors.secondaryText,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 8),
          DivineButton(
            label: context.l10n.commonRetry,
            leadingIcon: DivineIconName.arrowClockwise,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}
