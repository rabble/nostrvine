// ABOUTME: Main view for the inbox screen with Messages/Notifications toggle.
// ABOUTME: Shows conversation list (with following bar) or notifications
// ABOUTME: depending on the selected tab.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/conversation_actions/conversation_actions_cubit.dart';
import 'package:openvine/blocs/dm/conversation_list/conversation_list_bloc.dart';
import 'package:openvine/blocs/dm/conversation_mute/conversation_mute_cubit.dart';
import 'package:openvine/blocs/dm/unread_count/dm_unread_count_cubit.dart';
import 'package:openvine/blocs/notifications/badge/notification_badge_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/mixins/scroll_pagination_mixin.dart';
import 'package:openvine/notifications/view/inbox_notifications_page.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/inbox/conversation/conversation_page.dart';
import 'package:openvine/screens/inbox/message_requests/message_requests_page.dart';
import 'package:openvine/screens/inbox/message_requests/widgets/message_requests_banner.dart';
import 'package:openvine/screens/inbox/new_message_sheet.dart';
import 'package:openvine/screens/inbox/widgets/conversation_actions_sheet.dart';
import 'package:openvine/screens/inbox/widgets/conversation_tile.dart';
import 'package:openvine/screens/inbox/widgets/following_bar.dart';
import 'package:openvine/screens/inbox/widgets/inbox_empty_state.dart';
import 'package:openvine/screens/inbox/widgets/inbox_error_state.dart';
import 'package:openvine/screens/inbox/widgets/inbox_fab.dart';
import 'package:openvine/screens/inbox/widgets/inbox_segmented_toggle.dart';
import 'package:openvine/screens/inbox/widgets/restore_paused_banner.dart';
import 'package:openvine/screens/inbox/widgets/unread_filter_chips.dart';
import 'package:unified_logger/unified_logger.dart';

/// Main inbox view containing the Messages/Notifications segmented toggle
/// and the corresponding content for each tab.
class InboxView extends ConsumerStatefulWidget {
  const InboxView({super.key});

  @override
  ConsumerState<InboxView> createState() => _InboxViewState();
}

class _InboxViewState extends ConsumerState<InboxView>
    with SingleTickerProviderStateMixin {
  /// Drives the shared-axis transition between the two tabs. `0` fully shows
  /// Notifications, `1` fully shows Messages. Runs linearly; the curves are
  /// applied per-property in [_InboxTabContent].
  late final AnimationController _transitionController;

  /// Currently selected tab.
  InboxTab _selectedTab = InboxTab.notifications;

  /// Whether the Messages tab UI has been opened at least once. The
  /// `ConversationListBloc` is provided by `InboxPage` and starts immediately
  /// so DM backfill and streams can warm the tab before it is visible; this flag
  /// only keeps the Messages pane out of the animated stack until first open.
  /// After that first open, the pane stays mounted so later switches preserve
  /// UI state. Notifications is the default tab and is always mounted.
  bool _messagesActivated = false;

  /// Pubkey the current tab state belongs to. When the signed-in identity
  /// changes we collapse back to Notifications and re-arm lazy Messages UI
  /// activation. The account-scoped DM bloc still starts from `InboxPage` so
  /// Messages can be ready by the time the user opens it.
  String? _activePubkey;
  bool _pubkeyObserved = false;

  @override
  void initState() {
    super.initState();
    _transitionController = AnimationController(
      vsync: this,
      duration: kInboxTabTransitionDuration,
      // Notifications is the default tab (value 0); Messages is value 1.
      value: 0,
    );
  }

  @override
  void dispose() {
    _transitionController.dispose();
    super.dispose();
  }

  void _onTabSelected(InboxTab tab) {
    if (tab == _selectedTab) return;
    setState(() {
      _selectedTab = tab;
      if (tab == InboxTab.messages) _messagesActivated = true;
    });
    final target = tab == InboxTab.messages ? 1.0 : 0.0;
    if (MediaQuery.disableAnimationsOf(context)) {
      _transitionController.value = target;
    } else {
      _transitionController.animateTo(target);
    }
  }

  /// Resets the tab state to its defaults when the signed-in identity changes,
  /// so a new account opens on Notifications and re-arms lazy Messages UI.
  void _syncToIdentity(String? currentPubkey) {
    if (!_pubkeyObserved) {
      _pubkeyObserved = true;
      _activePubkey = currentPubkey;
      return;
    }
    if (currentPubkey == _activePubkey) return;
    _activePubkey = currentPubkey;
    _selectedTab = InboxTab.notifications;
    _messagesActivated = false;
    _transitionController.value = 0;
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild the inbox surfaces when auth identity changes so per-screen UI
    // state does not linger across account switches.
    ref.watch(currentAuthStateProvider);

    // Re-filter conversation list when blocklist changes.
    ref.listen(blocklistVersionProvider, (previous, current) {
      if (previous != null && current > previous) {
        context.read<ConversationListBloc>().add(
          const ConversationListBlocklistChanged(),
        );
      }
    });

    // Watch unread counts for both segments. Without a Messages-side badge
    // users had no signal that a still-lit bottom-nav inbox dot was caused
    // by unread DMs rather than notifications they thought they'd cleared.
    final notificationCount = context.watch<NotificationBadgeCubit>().state;
    final messageCount = context.watch<DmUnreadCountCubit>().state;
    final currentPubkey = ref.read(authServiceProvider).currentPublicKeyHex;
    _syncToIdentity(currentPubkey);

    return ColoredBox(
      color: context.vineColors.surface,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Segmented toggle (Messages / Notifications)
            InboxSegmentedToggle(
              selected: _selectedTab,
              onChanged: _onTabSelected,
              notificationCount: notificationCount,
              messageCount: messageCount,
            ),
            // Content area with rounded top corners. Both tabs stay mounted
            // (Notifications always, Messages once first opened) so returning
            // to a tab never reloads. The shared-axis transition slides +
            // cross-fades between them; each pane sits on an opaque surface so
            // neither the near-black background nor the other tab shows
            // through.
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: ColoredBox(
                  color: context.vineColors.surfaceContainerHigh,
                  child: _InboxTabContent(
                    animation: _transitionController,
                    selected: _selectedTab,
                    // BLoC-driven view (video-anchored grouping + 56x56
                    // thumbnails + l10n); see
                    // lib/notifications/view/inbox_notifications_page.dart.
                    notifications: KeyedSubtree(
                      key: ValueKey('notifications-$currentPubkey'),
                      child: const InboxNotificationsPage(),
                    ),
                    messages: _messagesActivated
                        ? KeyedSubtree(
                            key: ValueKey('messages-$currentPubkey'),
                            child: const _MessagesContent(),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Horizontal travel of each pane during the transition, as a fraction of the
/// pane width — the subtle shared-axis slide.
const double _kTabSlideFraction = 0.06;

/// Inset of the compose FAB from the bottom-right of the Messages pane.
const double _kFabInset = 16;

/// Bottom padding reserved on the conversation list so the compose FAB
/// ([InboxFab], inset [_kFabInset] from the bottom) never covers the last
/// conversation tile when scrolled to the end. Equals the FAB's footprint
/// plus a margin, so it tracks [InboxFab.size] automatically.
const double _kConversationListBottomInset =
    _kFabInset + InboxFab.size + _kFabInset;

/// Material shared-axis transition between the two inbox tabs: a short
/// horizontal slide combined with an overlapping cross-fade.
///
/// [animation] runs `0` (Notifications) → `1` (Messages). Both panes stay
/// mounted and are painted on an opaque surface, so the near-black background
/// never flashes and the panes never bleed through one another. The selected
/// pane is the only one that receives pointer events.
class _InboxTabContent extends StatelessWidget {
  const _InboxTabContent({
    required this.animation,
    required this.selected,
    required this.notifications,
    required this.messages,
  });

  final Animation<double> animation;
  final InboxTab selected;
  final Widget notifications;
  final Widget messages;

  @override
  Widget build(BuildContext context) {
    final notificationsSelected = selected == InboxTab.notifications;
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = animation.value;
        final slide = Curves.easeInOut.transform(t);
        return Stack(
          fit: StackFit.expand,
          children: [
            _InboxTabPane(
              opacity: Curves.easeInOut.transform(1 - t),
              dx: -_kTabSlideFraction * slide,
              active: notificationsSelected,
              child: notifications,
            ),
            _InboxTabPane(
              opacity: Curves.easeInOut.transform(t),
              dx: _kTabSlideFraction * (1 - slide),
              active: !notificationsSelected,
              child: messages,
            ),
          ],
        );
      },
    );
  }
}

/// A single inbox pane within the shared-axis transition: opaque background,
/// [opacity] + horizontal [dx] (fraction of width) for the slide/fade, and
/// [active] gating pointer events, semantics, and tickers so the faded-out pane
/// never intercepts taps, appears to assistive technologies, or keeps
/// descendant animations running.
class _InboxTabPane extends StatelessWidget {
  const _InboxTabPane({
    required this.opacity,
    required this.dx,
    required this.active,
    required this.child,
  });

  final double opacity;
  final double dx;
  final bool active;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TickerMode(
      enabled: active,
      child: ExcludeSemantics(
        excluding: !active,
        child: IgnorePointer(
          ignoring: !active,
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: FractionalTranslation(
              translation: Offset(dx, 0),
              child: ColoredBox(
                color: context.vineColors.surfaceContainerHigh,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pushes the conversation page using the [GoRouter] instance directly,
/// bypassing the nested Navigator's context which cannot reach GoRouter.
void _pushConversation(
  BuildContext context,
  String conversationId,
  List<String> participantPubkeys,
) {
  Log.info(
    '🚀 Pushing conversation: id=$conversationId',
    name: 'InboxView',
    category: LogCategory.ui,
  );
  context.push(
    ConversationPage.pathForId(conversationId),
    extra: participantPubkeys,
  );
}

/// Content for the Messages tab: following bar + conversation list or
/// empty state, with a FAB for composing new messages.
class _MessagesContent extends ConsumerWidget {
  const _MessagesContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authService = ref.watch(authServiceProvider);
    final currentPubkey = authService.currentPublicKeyHex ?? '';

    return BlocListener<ConversationListBloc, ConversationListState>(
      listenWhen: (prev, curr) =>
          curr.navigationTarget != null &&
          prev.navigationTarget != curr.navigationTarget,
      listener: (context, state) {
        final target = state.navigationTarget;
        if (target == null) return;

        Log.info(
          '🎯 Navigation target received: ${target.conversationId}',
          name: 'InboxView',
          category: LogCategory.ui,
        );

        // Clear the navigation target so it doesn't re-fire.
        context.read<ConversationListBloc>().add(
          const ConversationListNavigationConsumed(),
        );

        _pushConversation(
          context,
          target.conversationId,
          target.participantPubkeys,
        );
      },
      child: Stack(
        children: [
          _MessagesScrollView(currentUserPubkey: currentPubkey),
          // FAB positioned bottom-right
          PositionedDirectional(
            end: _kFabInset,
            bottom: _kFabInset,
            child: InboxFab(onPressed: () => _onNewConversation(context, ref)),
          ),
        ],
      ),
    );
  }

  Future<void> _onNewConversation(BuildContext context, WidgetRef ref) async {
    final profileRepo = ref.read(profileRepositoryProvider);
    if (profileRepo == null) {
      Log.warning(
        'Cannot open new message: profileRepo is null',
        name: 'InboxView',
        category: LogCategory.ui,
      );
      return;
    }

    final selectedUser = await NewMessageSheet.show(
      context,
      profileRepository: profileRepo,
      followRepository: ref.read(followRepositoryProvider),
    );

    if (selectedUser == null || !context.mounted) return;

    final authService = ref.read(authServiceProvider);
    final currentPubkey = authService.currentPublicKeyHex;
    if (currentPubkey == null) return;

    final conversationId = DmRepository.computeConversationId([
      currentPubkey,
      selectedUser.pubkey,
    ]);
    _pushConversation(context, conversationId, [selectedUser.pubkey]);
  }
}

/// Thin progress bar shown at the top of the Messages list while the one-time
/// DM history recovery (reinstall backfill / failed-decrypt replay) is still
/// running, so the user knows older chats are still being restored. See #5202.
class _RestoringHistoryIndicator extends StatelessWidget {
  const _RestoringHistoryIndicator();

  @override
  Widget build(BuildContext context) {
    final isRestoring = context.select<ConversationListBloc, bool>(
      (bloc) => bloc.state.isRestoringHistory,
    );
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return AnimatedSwitcher(
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 200),
      child: isRestoring
          ? LinearProgressIndicator(
              minHeight: 2,
              backgroundColor: context.vineColors.surfaceContainerHigh,
              color: VineTheme.primary,
              semanticsLabel: context.l10n.inboxRestoringMessages,
            )
          : const SizedBox.shrink(),
    );
  }
}

/// Renders [RestorePausedBanner] while the recovery gate is hiding would-be
/// message requests.
///
/// Scoped to the loaded state on purpose: the loading branch already shows a
/// spinner, and [InboxErrorState] carries its own retry, so surfacing a second
/// one above it would be redundant.
class _RestorePausedBannerGate extends StatelessWidget {
  const _RestorePausedBannerGate();

  @override
  Widget build(BuildContext context) {
    final withheld = context.select<ConversationListBloc, bool>(
      (bloc) =>
          bloc.state.requestsWithheld &&
          !bloc.state.isRestoringHistory &&
          bloc.state.status == ConversationListStatus.loaded,
    );
    if (!withheld) return const SizedBox.shrink();
    return RestorePausedBanner(
      onRetry: () => context.read<ConversationListBloc>().add(
        const ConversationListRestoreRetryRequested(),
      ),
    );
  }
}

/// "Divine Moderation" support tile, always rendered as the first row of the
/// conversation list (#6283).
///
/// It sits *inside* the scroll view rather than above it: as fixed chrome it
/// cost ~92px of a viewport the keyboard already halves on a small phone, and
/// it read as the screen's headline rather than as one chat among many.
/// Ordering is not left to the list's recency sort — a synthetic row carries
/// no timestamp and would sink out of reach.
///
/// The caller only builds this when [ConversationListState.pinnedSupport] is
/// non-null: the bloc composes that inside the same pipeline that applies the
/// blocklist filter and the protected-minor gate, so a user who blocked the
/// moderation account, or a restricted minor whose approval was revoked, gets
/// no row rather than one the conversation route guard would bounce.
class _PinnedSupportRow extends StatelessWidget {
  const _PinnedSupportRow({
    required this.pinned,
    required this.currentUserPubkey,
    required this.onLongPress,
  });

  /// The adopted real moderation thread, or the synthetic stand-in.
  final PinnedSupport pinned;

  /// Signed-in pubkey. Passed in rather than derived from the conversation's
  /// participant list — that list is sorted, so its first entry is not
  /// reliably self, and [ConversationTile] uses self to pick which
  /// participant's avatar to render.
  final String currentUserPubkey;

  /// Opens the conversation action sheet. Null while the pin is synthetic:
  /// there is no row to mute or remove yet, and the confirmation snackbars
  /// would report work that did not happen.
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final conversation = pinned.conversation;

    return ConversationTile(
      conversation: conversation,
      currentUserPubkey: currentUserPubkey,
      // Fixed identity: the profile lookup yields null until the relay client
      // is ready, and the tile's fallback is a generated name — so sourcing
      // this from kind-0 would show a random display name at cold start.
      displayNameOverride: context.l10n.inboxSupportRowTitle,
      // Only stand in for the preview when there is no real thread yet; once
      // the team replies, the last message is more useful than the blurb.
      subtitleOverride: conversation.lastMessageContent == null
          ? context.l10n.inboxSupportRowSubtitle
          : null,
      onTap: () => _pushConversation(
        context,
        conversation.id,
        // Self must be stripped, matching _onConversationTapped: the route
        // reads `extra` as the COUNTERPARTY list, so passing the raw
        // participants opens a conversation with the signed-in user instead
        // of with moderation.
        conversation.participantPubkeys
            .where((pk) => pk != currentUserPubkey)
            .toList(),
      ),
      onLongPress: onLongPress,
    );
  }
}

/// Vertical padding [UnreadFilterChips] puts above and below its chip row.
const double _kFilterChipsVerticalPadding = 8;

/// Inner vertical padding of a [DivineButtonSize.tiny] chip. Fixed per size.
const double _kTinyChipVerticalPadding = 6;

/// Line box of a tiny chip's `titleSmallFont` label (14/20) — the only part of
/// the chip's height that grows with the text scaler.
const double _kTinyChipLineHeight = 20;

/// Height [UnreadFilterChips] needs at the current text scale.
///
/// A pinned sliver declares its extent before its child is laid out, so this
/// reproduces the child's height rather than measuring it. Under-declaring
/// silently clips the label — a Row overflowing on its cross axis does not
/// throw. Duplicating the arithmetic is safe only because a widget test pins
/// it against the chips' real intrinsic height at two scales, so a moved
/// `divine_ui` token fails there instead of on a phone.
double _filterChipsExtent(BuildContext context) =>
    _kFilterChipsVerticalPadding * 2 +
    _kTinyChipVerticalPadding * 2 +
    MediaQuery.textScalerOf(context).scale(_kTinyChipLineHeight);

/// The whole Messages pane as a single scroll view.
///
/// Every piece of chrome — following bar, search field, filter chips — used to
/// be a fixed-height child of a [Column] wrapping the list, which on a small
/// Android phone left the list roughly one row tall once the keyboard opened,
/// and overflowed outright (#6388 review, items 4 and 5). Only the filter
/// chips stay pinned now; everything above them scrolls away, handing the
/// viewport back on every device rather than only below some height
/// threshold. The keyboard, not the screen, is what collapses the viewport —
/// a threshold would have missed the tall-phone case entirely.
class _MessagesScrollView extends ConsumerStatefulWidget {
  const _MessagesScrollView({required this.currentUserPubkey});

  final String currentUserPubkey;

  @override
  ConsumerState<_MessagesScrollView> createState() =>
      _MessagesScrollViewState();
}

class _MessagesScrollViewState extends ConsumerState<_MessagesScrollView>
    with ScrollPaginationMixin {
  final ScrollController _scrollController = ScrollController();
  late final TextEditingController _searchController;
  final FocusNode _searchFocusNode = FocusNode();

  /// Whether the search field holds focus, i.e. the keyboard is up and the
  /// viewport is roughly halved.
  bool _searchFocused = false;

  /// ID of the conversation whose long-press action sheet is currently open.
  /// Drives the [ConversationTile] highlight so the user can see which row
  /// the sheet refers to. Cleared in a `finally` block after the sheet closes.
  String? _highlightedConversationId;

  @override
  ScrollController get paginationScrollController => _scrollController;

  @override
  bool canLoadMore() {
    final state = context.read<ConversationListBloc>().state;
    // Re-entrancy is guarded by ScrollPaginationMixin's own pending-load latch.
    return state.hasMore && !state.isFiltering;
  }

  @override
  FutureOr<void> onLoadMore() {
    context.read<ConversationListBloc>().add(const ConversationListLoadMore());
  }

  @override
  void initState() {
    super.initState();
    // Seed from the bloc rather than starting empty. This State survives a
    // status change now that it owns every branch, but a keyed BlocProvider
    // above still re-inflates it while the bloc — and so state.searchQuery —
    // survives. A fresh empty controller would leave the list filtered by an
    // invisible query: the search empty state over a blank field, with
    // pagination silently suspended.
    _searchController = TextEditingController(
      text: context.read<ConversationListBloc>().state.searchQuery,
    );
    _searchFocusNode.addListener(_onSearchFocusChanged);
    initPagination();
  }

  void _onSearchFocusChanged() {
    if (_searchFocusNode.hasFocus == _searchFocused) return;
    setState(() => _searchFocused = _searchFocusNode.hasFocus);
  }

  @override
  void dispose() {
    disposePagination();
    _scrollController.dispose();
    _searchFocusNode
      ..removeListener(_onSearchFocusChanged)
      ..dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = context.select<ConversationListBloc, ConversationListStatus>(
      (bloc) => bloc.state.status,
    );

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        // Collapses while the search field holds focus (#6388 review, item 5).
        //
        // Keyed off focus rather than off a non-empty query on purpose: the
        // keyboard is what halves the viewport, and `state.searchQuery` stays
        // empty below `minSearchQueryLength` (2) — so a query-driven collapse
        // would still be showing 128px of faces after the first keystroke,
        // which is exactly the moment the list has the least room.
        SliverToBoxAdapter(
          child: AnimatedSize(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _searchFocused
                ? const SizedBox(width: double.infinity)
                : FollowingBar(
                    onUserTapped: (pubkey) {
                      Log.info(
                        '👤 User tapped in following bar: $pubkey',
                        name: 'InboxView',
                        category: LogCategory.ui,
                      );
                      context.read<ConversationListBloc>().add(
                        ConversationListNavigateToUser(pubkey),
                      );
                    },
                  ),
          ),
        ),
        // Thin restore progress bar while the one-time reinstall history
        // recovery is still running (#5202).
        const SliverToBoxAdapter(child: _RestoringHistoryIndicator()),
        // Static banner while the recovery gate is still hiding would-be
        // message requests (#6431). Emitted OUTSIDE the status switch, which
        // is what its Column placement bought before this pane became a single
        // scroll view: it still covers every branch below — empty inbox,
        // requests-only, filtered, and populated — without threading a flag
        // through each one. It gates itself on the loaded status, so the
        // loading spinner and InboxErrorState branches are unaffected.
        const SliverToBoxAdapter(child: _RestorePausedBannerGate()),
        ...switch (status) {
          ConversationListStatus.initial ||
          ConversationListStatus.loading => const [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: CircularProgressIndicator(color: VineTheme.primary),
              ),
            ),
          ],
          ConversationListStatus.error => [
            SliverFillRemaining(
              hasScrollBody: false,
              child: InboxErrorState(
                onRetry: () => context.read<ConversationListBloc>().add(
                  const ConversationListStarted(),
                ),
              ),
            ),
          ],
          ConversationListStatus.loaded => _loadedSlivers(context),
        },
      ],
    );
  }

  /// Slivers for the `loaded` status, in render order.
  List<Widget> _loadedSlivers(BuildContext context) {
    final conversations = context
        .select<ConversationListBloc, List<DmConversation>>(
          (bloc) => bloc.state.conversations,
        );
    final visibleConversations = context
        .select<ConversationListBloc, List<DmConversation>>(
          (bloc) => bloc.state.visibleConversations,
        );
    final unreadOnly = context.select<ConversationListBloc, bool>(
      (bloc) => bloc.state.unreadOnly,
    );
    final hasRequests = context.select<ConversationListBloc, bool>(
      (bloc) => bloc.state.requestConversations.isNotEmpty,
    );
    final requestUnreadCount = context.select<ConversationListBloc, int>(
      (bloc) => bloc.state.requestUnreadCount,
    );
    final hasMore = context.select<ConversationListBloc, bool>(
      (bloc) => bloc.state.hasMore,
    );
    final searchQuery = context.select<ConversationListBloc, String>(
      (bloc) => bloc.state.searchQuery,
    );
    final isFiltering = context.select<ConversationListBloc, bool>(
      (bloc) => bloc.state.isFiltering,
    );
    final pinned = context.select<ConversationListBloc, PinnedSupport?>(
      (bloc) => bloc.state.pinnedSupport,
    );

    final supportRow = pinned == null
        ? null
        : _PinnedSupportRow(
            pinned: pinned,
            currentUserPubkey: widget.currentUserPubkey,
            // Only an adopted thread has something to act on. Its actions are
            // the ones the ordinary row carried before the pin replaced it —
            // blocking moderation hides the pin, and Safety Settings is the
            // way back, exactly as for any other blocked account.
            onLongPress: pinned.isPersisted
                ? () => _onConversationLongPressed(
                    context,
                    ref,
                    pinned.conversation,
                    displayNameOverride: context.l10n.inboxSupportRowTitle,
                  )
                : null,
          );

    // Nothing but the support row to show. Keep the empty-state copy — a
    // brand-new user still needs to be told the inbox is empty — but render
    // the row above it rather than dropping it, and skip the search field and
    // filter chips, which have nothing to act on.
    if (conversations.isEmpty) {
      return [
        if (supportRow != null) SliverToBoxAdapter(child: supportRow),
        if (hasRequests)
          SliverToBoxAdapter(
            child: MessageRequestsBanner(
              requestCount: requestUnreadCount,
              onTap: () => _openMessageRequests(context),
            ),
          ),
        const SliverFillRemaining(
          hasScrollBody: false,
          child: InboxEmptyState(),
        ),
      ];
    }

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: DivineSearchBar(
            controller: _searchController,
            focusNode: _searchFocusNode,
            hintText: context.l10n.inboxSearchHint,
            onChanged: (value) => context.read<ConversationListBloc>().add(
              ConversationListSearchQueryChanged(value),
            ),
          ),
        ),
      ),
      SliverPersistentHeader(
        pinned: true,
        delegate: _FilterChipsHeaderDelegate(
          unreadOnly: unreadOnly,
          extent: _filterChipsExtent(context),
          onUnreadOnlyChanged: (value) {
            if (value == unreadOnly) return;
            context.read<ConversationListBloc>().add(
              const ConversationListUnreadFilterToggled(),
            );
          },
        ),
      ),
      // First tile of the list, ahead of the requests banner and every real
      // conversation — but only when it would survive the active filter. A
      // row that matches neither the query nor the Unread chip, sitting atop
      // a filtered result set, reads as a search hit that isn't one.
      if (supportRow != null &&
          _supportRowSurvivesFilter(
            context,
            pinned: pinned!.conversation,
            unreadOnly: unreadOnly,
            query: searchQuery,
          ))
        SliverToBoxAdapter(child: supportRow),
      if (visibleConversations.isEmpty) ...[
        if (hasRequests)
          SliverToBoxAdapter(
            child: MessageRequestsBanner(
              requestCount: requestUnreadCount,
              onTap: () => _openMessageRequests(context),
            ),
          ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: _FilteredEmptyContent(
            title: searchQuery.isNotEmpty
                ? context.l10n.inboxSearchEmptyTitle
                : context.l10n.inboxUnreadEmptyTitle,
            subtitle: searchQuery.isNotEmpty
                ? context.l10n.inboxSearchEmptySubtitle
                : context.l10n.inboxUnreadEmptySubtitle,
          ),
        ),
      ] else ...[
        if (hasRequests)
          SliverToBoxAdapter(
            child: MessageRequestsBanner(
              requestCount: requestUnreadCount,
              onTap: () => _openMessageRequests(context),
            ),
          ),
        SliverList.builder(
          itemCount: visibleConversations.length,
          itemBuilder: (context, index) {
            final conversation = visibleConversations[index];
            return ConversationTile(
              conversation: conversation,
              currentUserPubkey: widget.currentUserPubkey,
              highlighted: conversation.id == _highlightedConversationId,
              onTap: () => _onConversationTapped(context, conversation),
              onLongPress: () =>
                  _onConversationLongPressed(context, ref, conversation),
            );
          },
        ),
        // Suppress the load-more affordance while a filter/search narrows the
        // list: the filtered result is already complete, and a short one
        // can't scroll to trigger a load — leaving a spinner that never
        // resolves.
        if (hasMore && !isFiltering)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: VineTheme.primary,
                    strokeWidth: 2,
                  ),
                ),
              ),
            ),
          ),
        // Clears the compose FAB so it never covers the last tile.
        const SliverToBoxAdapter(
          child: SizedBox(height: _kConversationListBottomInset),
        ),
      ],
    ];
  }

  /// Whether the support row should still render under the active filter.
  ///
  /// It is pinned against the *sort*, not against the user's filters: hiding
  /// it here is what makes it behave like any other chat once a query or the
  /// Unread chip is on. [query] arrives already thresholded by the bloc — it
  /// is `''` below `minSearchQueryLength` — so an empty string reliably means
  /// "no search active".
  ///
  /// Matches title OR whatever the row renders as its preview, mirroring the
  /// bloc's `_applyFilters`. Once the team has replied the preview is a real
  /// message, and a query drawn from it should surface this row for the same
  /// reason it surfaces any other. Before that it is the subtitle blurb — the
  /// same string [_PinnedSupportRow] passes as `subtitleOverride`, and matching
  /// it is what stops a search for a word the user can read on screen from
  /// hiding the row that shows it.
  bool _supportRowSurvivesFilter(
    BuildContext context, {
    required DmConversation pinned,
    required bool unreadOnly,
    required String query,
  }) {
    if (unreadOnly && pinned.isRead) return false;
    if (query.isEmpty) return true;
    final needle = query.toLowerCase();
    final preview =
        pinned.lastMessageContent ?? context.l10n.inboxSupportRowSubtitle;
    return context.l10n.inboxSupportRowTitle.toLowerCase().contains(needle) ||
        preview.toLowerCase().contains(needle);
  }

  void _openMessageRequests(BuildContext context) {
    context.pushNamed(MessageRequestsPage.routeName);
  }

  void _onConversationTapped(
    BuildContext context,
    DmConversation conversation,
  ) {
    Log.info(
      '💬 Conversation tapped: ${conversation.id}',
      name: 'InboxView',
      category: LogCategory.ui,
    );
    final otherPubkeys = conversation.participantPubkeys
        .where((pk) => pk != widget.currentUserPubkey)
        .toList();

    _pushConversation(context, conversation.id, otherPubkeys);
  }

  Future<void> _onConversationLongPressed(
    BuildContext context,
    WidgetRef ref,
    DmConversation conversation, {
    String? displayNameOverride,
  }) async {
    final otherPubkey = conversation.participantPubkeys.firstWhere(
      (pk) => pk != widget.currentUserPubkey,
      orElse: () => conversation.participantPubkeys.first,
    );

    // A known identity skips the lookup entirely: kind-0 for the moderation
    // account resolves late, and the sheet would open labelled with the
    // generated fallback name the row's own override exists to avoid.
    String displayName;
    if (displayNameOverride != null) {
      displayName = displayNameOverride;
    } else {
      final profile = await ref.read(
        fetchUserProfileProvider(otherPubkey).future,
      );
      if (!context.mounted) return;
      displayName = profile?.bestDisplayName ?? 'user';
    }

    if (!context.mounted) return;

    final muteCubit = context.read<ConversationMuteCubit>();
    final isMuted = muteCubit.state.isMuted(conversation.id);

    final actionsCubit = context.read<ConversationActionsCubit>();
    final isBlocked = actionsCubit.isBlocked(otherPubkey);

    setState(() => _highlightedConversationId = conversation.id);
    try {
      final action = await ConversationActionsSheet.show(
        context,
        displayName: displayName,
        isMuted: isMuted,
        isBlocked: isBlocked,
      );

      if (action == null || !context.mounted) return;

      switch (action) {
        case ConversationAction.toggleMute:
          final nowMuted = await muteCubit.toggleMute(conversation.id);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  nowMuted
                      ? context.l10n.inboxConversationMuted
                      : context.l10n.inboxConversationUnmuted,
                ),
              ),
            );
          }

        case ConversationAction.report:
          final reported = await actionsCubit.reportUser(otherPubkey);
          if (context.mounted) {
            // `reported` is false when the report reached no channel off
            // this device. Staying silent there would be worse than the
            // false confirmation it replaced — the user would have no way
            // to tell the report was lost.
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  reported
                      ? context.l10n.inboxReportedUser(displayName)
                      : context.l10n.reportFailed(
                          context.l10n.commonSomethingWentWrong,
                        ),
                ),
              ),
            );
          }

        case ConversationAction.block:
          if (isBlocked) {
            actionsCubit.unblockUser(otherPubkey);
          } else {
            actionsCubit.blockUser(otherPubkey);
          }
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  isBlocked
                      ? context.l10n.inboxUnblockedUser(displayName)
                      : context.l10n.inboxBlockedUser(displayName),
                ),
              ),
            );
          }

        case ConversationAction.remove:
          if (!context.mounted) return;
          final confirmed = await _confirmRemove(context, displayName);
          if (confirmed && context.mounted) {
            final removed = await actionsCubit.removeConversation(
              conversation.id,
            );
            if (context.mounted && removed) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(context.l10n.inboxRemovedConversation)),
              );
            }
          }
      }
    } finally {
      if (mounted) {
        setState(() => _highlightedConversationId = null);
      }
    }
  }

  Future<bool> _confirmRemove(BuildContext context, String displayName) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.vineColors.card,
        title: Text(
          context.l10n.inboxRemoveConfirmTitle,
          style: VineTheme.titleLargeFont(
            color: context.vineColors.primaryText,
          ),
        ),
        content: Text(
          context.l10n.inboxRemoveConfirmBody(displayName),
          style: VineTheme.bodyMediumFont(
            color: context.vineColors.secondaryText,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              context.l10n.commonCancel,
              style: VineTheme.bodyMediumFont(
                color: context.vineColors.onSurface,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              context.l10n.inboxRemoveConfirmConfirm,
              style: VineTheme.bodyMediumFont(color: VineTheme.error),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

/// Shown when an active filter (Unread chip or search) leaves nothing to
/// list, confirming the list is not empty by accident.
///
/// The requests banner is emitted as its own sliver above this, so it stays
/// reachable without this widget having to lay it out.
class _FilteredEmptyContent extends StatelessWidget {
  const _FilteredEmptyContent({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 8,
          children: [
            Text(
              title,
              style: VineTheme.titleMediumFont(
                color: context.vineColors.onSurfaceMuted,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              subtitle,
              style: VineTheme.bodyMediumFont(
                color: context.vineColors.onSurfaceMuted,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Pinned header carrying [UnreadFilterChips].
///
/// Pinned rather than scrolled away so the user can always drop back to All
/// after narrowing to Unread without hunting for the chip. Opaque, because the
/// conversation list scrolls underneath it.
class _FilterChipsHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _FilterChipsHeaderDelegate({
    required this.unreadOnly,
    required this.onUnreadOnlyChanged,
    required this.extent,
  });

  final bool unreadOnly;
  final ValueChanged<bool> onUnreadOnlyChanged;

  /// Height the chips need at the caller's text scale. Passed in rather than
  /// read here: [SliverPersistentHeaderDelegate]'s extent getters take no
  /// [BuildContext], so the MediaQuery lookup has to happen in the widget
  /// that builds the delegate. Same shape as the `topInset` pattern in
  /// `.claude/rules/ui_theming.md`.
  final double extent;

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    return ColoredBox(
      color: context.vineColors.surfaceContainerHigh,
      child: UnreadFilterChips(
        unreadOnly: unreadOnly,
        onUnreadOnlyChanged: onUnreadOnlyChanged,
      ),
    );
  }

  @override
  bool shouldRebuild(_FilterChipsHeaderDelegate oldDelegate) =>
      oldDelegate.unreadOnly != unreadOnly ||
      oldDelegate.onUnreadOnlyChanged != onUnreadOnlyChanged ||
      oldDelegate.extent != extent;
}
