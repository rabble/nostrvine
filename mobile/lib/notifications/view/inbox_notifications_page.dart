// ABOUTME: Inbox notifications scaffold — TabBar (All/Likes/Comments/
// ABOUTME: Follows/Reposts) + invites banner wrapping the BLoC-driven
// ABOUTME: NotificationsView. Replaces legacy NotificationsScreen in inbox.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/invite_status/invite_status_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/notifications/bloc/notification_feed_bloc.dart';
import 'package:openvine/notifications/providers/notification_repository_provider.dart';
import 'package:openvine/notifications/view/notifications_view.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/settings/invites_screen.dart';

/// Inbox notifications page — owns the BLoC and tab scaffold.
///
/// Wraps [NotificationsView] with the existing 5-tab UI (All / Likes /
/// Comments / Follows / Reposts) and the invites banner shown on the All
/// tab. Each tab passes a [NotificationKind] filter to the same view; the
/// underlying [NotificationFeedBloc] is shared across tabs.
class InboxNotificationsPage extends ConsumerWidget {
  /// Creates an [InboxNotificationsPage].
  const InboxNotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationRepository = ref.watch(notificationRepositoryProvider);
    if (notificationRepository == null) {
      return const ColoredBox(
        color: VineTheme.backgroundColor,
        child: Center(
          child: CircularProgressIndicator(color: VineTheme.vineGreen),
        ),
      );
    }
    final followRepository = ref.watch(followRepositoryProvider);

    return BlocProvider(
      create: (_) => NotificationFeedBloc(
        notificationRepository: notificationRepository,
        followRepository: followRepository,
      )..add(const NotificationFeedStarted()),
      child: const _InboxNotificationsScaffold(),
    );
  }
}

class _InboxNotificationsScaffold extends StatefulWidget {
  const _InboxNotificationsScaffold();

  @override
  State<_InboxNotificationsScaffold> createState() =>
      _InboxNotificationsScaffoldState();
}

class _InboxNotificationsScaffoldState
    extends State<_InboxNotificationsScaffold>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  static const _tabCount = 5;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabCount, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<InviteStatusCubit>().load();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(VineTheme.shellInnerCornerRadius),
      ),
      child: ColoredBox(
        color: VineTheme.surfaceContainerHigh,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Material(
              type: MaterialType.transparency,
              child: TabBar(
                controller: _tabController,
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
                controller: _tabController,
                children: const [
                  _AllTabContent(),
                  NotificationsView(kindFilter: NotificationKind.like),
                  NotificationsView(kindFilter: NotificationKind.comment),
                  NotificationsView(kindFilter: NotificationKind.follow),
                  NotificationsView(kindFilter: NotificationKind.repost),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// All tab — invites banner above the unfiltered notifications list.
class _AllTabContent extends StatelessWidget {
  const _AllTabContent();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _InvitesBanner(),
        Expanded(child: NotificationsView()),
      ],
    );
  }
}

class _InvitesBanner extends StatelessWidget {
  const _InvitesBanner();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<InviteStatusCubit, InviteStatusState>(
      builder: (context, state) {
        if (!state.hasAvailableInvites) return const SizedBox.shrink();
        return _InviteNotificationCard(count: state.availableInviteCount);
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
        color: VineTheme.cardBackground,
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
              child: const DivineIcon(
                icon: DivineIconName.shareNetwork,
                color: VineTheme.backgroundColor,
              ),
            ),
            Expanded(child: Text(label, style: VineTheme.bodyMediumFont())),
            const DivineIcon(
              icon: DivineIconName.caretRight,
              color: VineTheme.lightText,
            ),
          ],
        ),
      ),
    );
  }
}
