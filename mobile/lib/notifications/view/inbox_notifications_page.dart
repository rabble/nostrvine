// ABOUTME: Inbox notifications scaffold — TabBar (All/Likes/Comments/
// ABOUTME: Follows/Reposts) + invites banner wrapping the BLoC-driven
// ABOUTME: NotificationsView.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart';
import 'package:notification_repository/notification_repository.dart';
import 'package:openvine/blocs/invite_status/invite_status_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/mixins/reduced_motion_tab_controller_mixin.dart';
import 'package:openvine/notifications/bloc/notification_feed_bloc.dart';
import 'package:openvine/notifications/providers/notification_repository_provider.dart';
import 'package:openvine/notifications/view/notifications_view.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/settings/invites_screen.dart';
import 'package:openvine/widgets/signup_invites_availability_builder.dart';

/// Inbox notifications page — owns the BLoC and tab scaffold.
///
/// Wraps [NotificationsView] with the existing 5-tab UI (All / Likes /
/// Comments / Follows / Reposts) and the invites banner shown on the All
/// tab. Each tab owns a feed BLoC with independent server-side pagination.
class InboxNotificationsPage extends ConsumerWidget {
  /// Creates an [InboxNotificationsPage].
  const InboxNotificationsPage({this.isVisible = true, super.key});

  /// Whether the kept-alive inbox notifications pane is currently visible.
  final bool isVisible;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationRepository = ref.watch(notificationRepositoryProvider);
    if (notificationRepository == null) {
      return ColoredBox(
        color: context.vineColors.background,
        child: const Center(
          child: CircularProgressIndicator(color: VineTheme.vineGreen),
        ),
      );
    }
    final followRepository = ref.watch(followRepositoryProvider);

    return _InboxNotificationsScaffold(
      notificationRepository: notificationRepository,
      followRepository: followRepository,
      isVisible: isVisible,
    );
  }
}

class _InboxNotificationsScaffold extends StatefulWidget {
  const _InboxNotificationsScaffold({
    required this.notificationRepository,
    required this.followRepository,
    required this.isVisible,
  });

  final NotificationRepository notificationRepository;
  final FollowRepository followRepository;
  final bool isVisible;

  @override
  State<_InboxNotificationsScaffold> createState() =>
      _InboxNotificationsScaffoldState();
}

class _InboxNotificationsScaffoldState
    extends State<_InboxNotificationsScaffold>
    with TickerProviderStateMixin, ReducedMotionTabControllerMixin {
  @override
  int get tabCount => 5;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<InviteStatusCubit>().load();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    syncTabController();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(VineTheme.shellInnerCornerRadius),
      ),
      child: ColoredBox(
        color: context.vineColors.surfaceContainerHigh,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Material(
              type: MaterialType.transparency,
              child: TabBar(
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
                  Tab(text: context.l10n.notificationsTabAll),
                  Tab(text: context.l10n.notificationsTabLikes),
                  Tab(text: context.l10n.notificationsTabComments),
                  Tab(text: context.l10n.notificationsTabFollows),
                  Tab(text: context.l10n.notificationsTabReposts),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: tabController,
                children: [
                  _NotificationTab(
                    notificationRepository: widget.notificationRepository,
                    followRepository: widget.followRepository,
                    isVisible: widget.isVisible,
                    child: const Column(
                      children: [
                        _InvitesBanner(),
                        Expanded(child: NotificationsView()),
                      ],
                    ),
                  ),
                  _NotificationTab(
                    notificationRepository: widget.notificationRepository,
                    followRepository: widget.followRepository,
                    isVisible: widget.isVisible,
                    filter: NotificationKind.like,
                  ),
                  _NotificationTab(
                    notificationRepository: widget.notificationRepository,
                    followRepository: widget.followRepository,
                    isVisible: widget.isVisible,
                    filter: NotificationKind.comment,
                  ),
                  _NotificationTab(
                    notificationRepository: widget.notificationRepository,
                    followRepository: widget.followRepository,
                    isVisible: widget.isVisible,
                    filter: NotificationKind.follow,
                  ),
                  _NotificationTab(
                    notificationRepository: widget.notificationRepository,
                    followRepository: widget.followRepository,
                    isVisible: widget.isVisible,
                    filter: NotificationKind.repost,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationTab extends ConsumerStatefulWidget {
  const _NotificationTab({
    required this.notificationRepository,
    required this.followRepository,
    required this.isVisible,
    this.filter,
    this.child = const NotificationsView(),
  });

  final NotificationRepository notificationRepository;
  final FollowRepository followRepository;
  final bool isVisible;
  final NotificationKind? filter;
  final Widget child;

  @override
  ConsumerState<_NotificationTab> createState() => _NotificationTabState();
}

class _NotificationTabState extends ConsumerState<_NotificationTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final appBadgeClearer = ref.watch(appBadgeServiceProvider);
    // Key on the watched dependency identities plus filter so each tab's bloc
    // rebuilds when repositories swap and keeps an independent pagination
    // stream for its server-side category.
    return BlocProvider(
      key: ValueKey((
        widget.notificationRepository,
        widget.followRepository,
        widget.filter,
      )),
      create: (_) => NotificationFeedBloc(
        notificationRepository: widget.notificationRepository,
        followRepository: widget.followRepository,
        appBadgeClearer: appBadgeClearer,
        filter: widget.filter,
      )..add(const NotificationFeedStarted()),
      child: _NotificationVisibilityDispatcher(
        isVisible: widget.isVisible,
        child: widget.child,
      ),
    );
  }
}

class _NotificationVisibilityDispatcher extends StatefulWidget {
  const _NotificationVisibilityDispatcher({
    required this.isVisible,
    required this.child,
  });

  final bool isVisible;
  final Widget child;

  @override
  State<_NotificationVisibilityDispatcher> createState() =>
      _NotificationVisibilityDispatcherState();
}

class _NotificationVisibilityDispatcherState
    extends State<_NotificationVisibilityDispatcher> {
  bool? _wasVisible;

  void _observeVisibility() {
    final visible = widget.isVisible;
    final wasVisible = _wasVisible;
    _wasVisible = visible;
    if (wasVisible == false && visible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<NotificationFeedBloc>().add(
          const NotificationFeedBecameVisible(),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    _observeVisibility();
    return widget.child;
  }
}

class _InvitesBanner extends StatelessWidget {
  const _InvitesBanner();

  @override
  Widget build(BuildContext context) {
    return SignupInvitesAvailabilityBuilder(
      builder: (context, availability) {
        if (!availability.isEnabled) return const SizedBox.shrink();
        return BlocBuilder<InviteStatusCubit, InviteStatusState>(
          builder: (context, state) {
            if (!state.hasAvailableInvites) return const SizedBox.shrink();
            return _InviteNotificationCard(count: state.availableInviteCount);
          },
        );
      },
    );
  }
}

class _InviteNotificationCard extends StatelessWidget {
  const _InviteNotificationCard({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final label = count == 1
        ? context.l10n.notificationsInviteSingular
        : context.l10n.notificationsInvitePlural(count);
    return InkWell(
      onTap: () => context.push(InvitesScreen.path),
      child: Container(
        padding: const EdgeInsets.all(16),
        color: context.vineColors.card,
        child: Row(
          spacing: 12,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: VineTheme.vineGreen,
                shape: BoxShape.circle,
              ),
              child: DivineIcon(
                icon: DivineIconName.shareNetwork,
                color: context.vineColors.background,
              ),
            ),
            Expanded(
              child: Text(
                label,
                style: VineTheme.bodyMediumFont(
                  color: context.vineColors.primaryText,
                ),
              ),
            ),
            DivineIcon(
              icon: DivineIconName.caretRight,
              color: context.vineColors.mutedText,
            ),
          ],
        ),
      ),
    );
  }
}
