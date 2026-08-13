// ABOUTME: Screen for displaying videos from a curated NIP-51 kind 30005 list
// ABOUTME: Shows videos in a grid with tap-to-play navigation

import 'package:analytics/analytics.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:feed_repository/feed_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsService;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/extensions/safe_pop_extension.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/view_traffic_source.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/list_providers.dart';
import 'package:openvine/screens/curated_list_by_author_screen.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/screens/other_profile_screen.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/utils/pause_aware_modals.dart';
import 'package:openvine/utils/share_position_origin.dart';
import 'package:openvine/widgets/add_to_list_dialog.dart';
import 'package:openvine/widgets/composable_video_grid.dart';
import 'package:openvine/widgets/user_name.dart';
import 'package:share_plus/share_plus.dart';
import 'package:unified_logger/unified_logger.dart';

enum _CuratedListAction { edit, share, delete, unfollow }

/// Pops the delete-confirmation dialog with [confirmed].
///
/// The route can be gone by the time a tap on one of its buttons is
/// delivered. `Navigator.of` then walks a defunct element and throws, which
/// `FlutterError.onError` records as a fatal even though the pop is moot.
void _popConfirmation(BuildContext dialogContext, {required bool confirmed}) {
  if (!dialogContext.mounted) {
    return;
  }
  Navigator.of(dialogContext).pop(confirmed);
}

class CuratedListFeedScreen extends ConsumerStatefulWidget {
  /// Route name for this screen.
  static const routeName = 'list';

  /// Base path for list routes.
  static const basePath = '/list';

  /// Path for this route.
  static const path = '/list/:listId';

  /// Build path for a specific list.
  static String pathForId(String listId) {
    final encodedId = Uri.encodeComponent(listId);
    return '$basePath/$encodedId';
  }

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

  @override
  Widget build(BuildContext context) {
    // Use direct video IDs if provided (for discovered lists not in local storage)
    // Otherwise look up by list ID from local storage
    final videosAsync = widget.videoIds != null
        ? ref.watch(videoEventsByIdsProvider(widget.videoIds!))
        : ref.watch(curatedListVideoEventsProvider(widget.listId));

    return Scaffold(
      backgroundColor: context.vineColors.background,
      appBar: _activeVideoIndex == null
          ? DiVineAppBar(
              titleWidget: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _localList()?.name ?? widget.listName,
                    style: VineTheme.titleLargeFont(
                      color: context.vineColors.onNav,
                    ),
                  ),
                  const SizedBox(height: 2),
                  _buildSubheading(),
                ],
              ),
              showBackButton: true,
              // safePop: on a cold-start deep link this screen can be the
              // only route, and a raw pop would throw GoError.
              onBackPressed: context.safePop,
              // Subscribing to your own list is meaningless — owners only
              // get the overflow menu (delete).
              actions: [if (!_isOwnedList()) _buildSubscribeAction()],
              customActions: _buildListCustomActions(),
            )
          : null,
      body: videosAsync.when(
        // Keep the current grid on screen while the provider re-runs after a
        // blocklist version bump, instead of flashing the spinner and resetting
        // scroll (#5104).
        skipLoadingOnReload: true,
        data: (videos) {
          if (videos.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.video_library,
                    size: 64,
                    color: context.vineColors.secondaryText,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.l10n.curatedListEmptyTitle,
                    style: TextStyle(
                      color: context.vineColors.primaryText,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.curatedListEmptySubtitle,
                    style: TextStyle(
                      color: context.vineColors.secondaryText,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            );
          }

          ScreenAnalyticsService().markDataLoaded(
            'curated_list',
            dataMetrics: {'video_count': videos.length},
          );

          // If in video mode, show fullscreen video player
          if (_activeVideoIndex != null) {
            return _buildVideoPlayer(videos);
          }

          // Otherwise show grid
          return _buildVideoGrid(videos);
        },
        loading: () => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: VineTheme.vineGreen),
              const SizedBox(height: 16),
              Text(
                context.l10n.curatedListLoadingVideos,
                style: TextStyle(
                  color: context.vineColors.secondaryText,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: VineTheme.likeRed),
              const SizedBox(height: 16),
              Text(
                context.l10n.curatedListFailedToLoad,
                style: const TextStyle(color: VineTheme.likeRed, fontSize: 18),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  error.toString(),
                  style: TextStyle(
                    color: context.vineColors.secondaryText,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  ref.invalidate(curatedListVideoEventsProvider(widget.listId));
                },
                icon: const DivineIcon(
                  icon: DivineIconName.arrowClockwise,
                  color: VineTheme.onPrimary,
                ),
                label: Text(context.l10n.commonRetry),
                style: ElevatedButton.styleFrom(
                  backgroundColor: VineTheme.vineGreen,
                  foregroundColor: context.vineColors.background,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoGrid(List<VideoEvent> videos) {
    return ComposableVideoGrid(
      videos: videos,
      useMasonryLayout: true,
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
      emptyBuilder: () => Center(
        child: Text(
          context.l10n.curatedListNoVideosAvailable,
          style: TextStyle(color: context.vineColors.secondaryText),
        ),
      ),
    );
  }

  void _exitVideoMode() {
    setState(() {
      _activeVideoIndex = null;
    });
  }

  Widget _buildVideoPlayer(List<VideoEvent> videos) {
    if (videos.isEmpty || _activeVideoIndex! >= videos.length) {
      return Center(
        child: Text(
          context.l10n.curatedListVideoNotAvailable,
          style: TextStyle(color: context.vineColors.secondaryText),
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
        _exitVideoMode();
      },
      child: PooledFullscreenVideoFeedScreen(
        source: VideoListViewSource(videos),
        feedRepository: StaticFeedRepository(),
        initialIndex: _activeVideoIndex!,
        contextTitle: widget.listName,
        trafficSource: ViewTrafficSource.search,
        onBack: _exitVideoMode,
      ),
    );
  }

  /// Build the subheading showing the creator and video count.
  Widget _buildSubheading() {
    final localList = _localList();
    final videoCount =
        widget.videoIds?.length ?? localList?.videoEventIds.length ?? 0;
    final videoText = context.l10n.listVideoCount(videoCount);
    final authorPubkey = _isOwnedList()
        ? null
        : widget.authorPubkey ?? localList?.pubkey;

    if (authorPubkey != null) {
      return GestureDetector(
        onTap: () {
          final npub = NostrKeyUtils.encodePubKey(authorPubkey);
          context.push(OtherProfileScreen.pathForNpub(npub));
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.l10n.listByAuthorPrefix,
              style: TextStyle(
                color: context.vineColors.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
            Flexible(
              flex: 0,
              child: UserName.fromPubKey(
                authorPubkey,
                style: TextStyle(
                  color: context.vineColors.primaryText,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              ' • $videoText',
              style: TextStyle(
                color: context.vineColors.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    // No author - just show video count
    final visibility = localList == null
        ? null
        : localList.isPublic
        ? context.l10n.listVisibilityPublic
        : context.l10n.listVisibilityPrivate;
    return Text(
      visibility == null ? videoText : '$videoText • $visibility',
      style: TextStyle(
        color: context.vineColors.onSurfaceVariant,
        fontSize: 12,
      ),
    );
  }

  CuratedList? _localList() => ref
      .read(curatedListsStateProvider.notifier)
      .service
      ?.getListById(widget.listId);

  bool _isOwnedList() {
    final serviceAsync = ref.watch(curatedListsStateProvider);
    final service = ref.read(curatedListsStateProvider.notifier).service;
    return serviceAsync.whenOrNull(
          data: (_) => service?.isOwnedList(widget.listId),
        ) ??
        false;
  }

  DiVineAppBarAction _buildSubscribeAction() {
    final serviceAsync = ref.watch(curatedListsStateProvider);
    final service = ref.read(curatedListsStateProvider.notifier).service;
    final isSubscribed =
        serviceAsync.whenOrNull(
          data: (_) => service?.isSubscribedToList(widget.listId),
        ) ??
        false;

    return DiVineAppBarAction(
      icon: SvgIconSource(
        isSubscribed
            ? DivineIconName.check.assetPath
            : DivineIconName.plus.assetPath,
      ),
      backgroundColor: isSubscribed
          ? context.vineColors.iconButton
          : VineTheme.vineGreen,
      iconColor: isSubscribed
          ? VineTheme.vineGreen
          : context.vineColors.primaryText,
      onPressed: _isTogglingSubscription ? null : _toggleSubscription,
      tooltip: isSubscribed ? 'Subscribed' : 'Subscribe',
    );
  }

  List<Widget> _buildListCustomActions() {
    final actions = _listActions();
    if (actions.isEmpty) {
      return const [];
    }

    return [
      _CuratedListActionsMenu(
        actions: actions,
        onSelected: (action) {
          switch (action) {
            case _CuratedListAction.edit:
              _editList();
            case _CuratedListAction.share:
              _shareList();
            case _CuratedListAction.delete:
              _confirmDeleteList();
            case _CuratedListAction.unfollow:
              _unfollowList();
          }
        },
      ),
    ];
  }

  List<_CuratedListAction> _listActions() {
    final serviceAsync = ref.watch(curatedListsStateProvider);
    final service = ref.read(curatedListsStateProvider.notifier).service;

    return serviceAsync.whenOrNull(
          data: (_) {
            final isOwned = service?.isOwnedList(widget.listId) ?? false;
            if (isOwned) {
              final list = service?.getListById(widget.listId);
              // Sharing needs an author pubkey for the canonical URL, so a
              // public list without one must not offer a no-op menu entry.
              final isShareable =
                  (list?.isPublic ?? false) && list?.pubkey != null;
              return [
                _CuratedListAction.edit,
                if (isShareable) _CuratedListAction.share,
                _CuratedListAction.delete,
              ];
            }

            final isSubscribed =
                service?.isSubscribedToList(widget.listId) ?? false;
            if (isSubscribed) {
              return const [_CuratedListAction.unfollow];
            }

            return const <_CuratedListAction>[];
          },
        ) ??
        const <_CuratedListAction>[];
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
      await SharePlus.instance.share(
        ShareParams(
          text: context.l10n.listShareText(list.name, url),
          subject: context.l10n.listShareSubject(list.name),
          sharePositionOrigin: sharePositionOriginForContext(context),
        ),
      );
    } on Object catch (error, stackTrace) {
      Log.error(
        'Failed to share public list ${list.id}: $error',
        name: 'CuratedListFeedScreen',
        category: LogCategory.ui,
        error: error,
        stackTrace: stackTrace,
      );
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
            onPressed: () => _popConfirmation(dialogContext, confirmed: false),
            child: Text(
              l10n.commonCancel,
              style: VineTheme.labelMediumFont(
                color: context.vineColors.secondaryText,
              ),
            ),
          ),
          TextButton(
            onPressed: () => _popConfirmation(dialogContext, confirmed: true),
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

  Future<void> _unfollowList() async {
    final service = ref.read(curatedListsStateProvider.notifier).service;
    final didUnfollow =
        await service?.unsubscribeFromList(widget.listId) ?? false;

    if (!mounted) {
      return;
    }

    if (!didUnfollow) {
      final message = context.l10n.curatedListUnfollowFailed;
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
    final message = context.l10n.curatedListUnfollowedSnack;
    SemanticsService.sendAnnouncement(
      View.of(context),
      message,
      Directionality.of(context),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: VineTheme.vineGreen),
    );
  }

  Future<void> _toggleSubscription() async {
    setState(() {
      _isTogglingSubscription = true;
    });

    try {
      final service = ref.read(curatedListsStateProvider.notifier).service;
      final isSubscribed = service?.isSubscribedToList(widget.listId) ?? false;

      if (isSubscribed) {
        await service?.unsubscribeFromList(widget.listId);
        Log.info(
          'Unsubscribed from list: ${widget.listName}',
          category: LogCategory.ui,
        );
      } else {
        // Create a CuratedList object for subscribing
        final now = DateTime.now();
        final list = CuratedList(
          id: widget.listId,
          name: widget.listName,
          videoEventIds: widget.videoIds ?? [],
          pubkey: widget.authorPubkey,
          createdAt: now,
          updatedAt: now,
        );
        await service?.subscribeToList(widget.listId, list);
        Log.info(
          'Subscribed to list: ${widget.listName}',
          category: LogCategory.ui,
        );
      }

      // Invalidate providers so Lists tab updates
      ref.invalidate(curatedListsProvider);

      // Trigger rebuild to update button state
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      Log.error('Failed to toggle subscription: $e', category: LogCategory.ui);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.discoverListsFailedToUpdateSubscription('$e'),
            ),
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

class _CuratedListActionsMenu extends StatelessWidget {
  const _CuratedListActionsMenu({
    required this.actions,
    required this.onSelected,
  });

  final List<_CuratedListAction> actions;
  final ValueChanged<_CuratedListAction> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_CuratedListAction>(
      tooltip: context.l10n.curatedListActionsTooltip,
      color: context.vineColors.surfaceContainer,
      icon: DivineIcon(
        icon: DivineIconName.dotsThreeVertical,
        color: context.vineColors.primaryText,
      ),
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final action in actions)
          PopupMenuItem(
            value: action,
            child: Text(switch (action) {
              _CuratedListAction.edit => context.l10n.listEditAction,
              _CuratedListAction.share => context.l10n.listShareAction,
              _CuratedListAction.delete => context.l10n.listDeleteAction,
              _CuratedListAction.unfollow =>
                context.l10n.curatedListUnfollowAction,
            }, style: TextStyle(color: context.vineColors.primaryText)),
          ),
      ],
    );
  }
}
