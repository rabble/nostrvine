// ABOUTME: Inbox screen with Messages/Notifications segmented toggle
// ABOUTME: Replaces the old notifications-only screen as tab index 2

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/dm/unread_count/dm_unread_count_cubit.dart';
import 'package:openvine/providers/relay_notifications_provider.dart';
import 'package:openvine/screens/inbox/messages_tab.dart';
import 'package:openvine/screens/inbox/notifications_tab.dart';
import 'package:openvine/widgets/inbox/inbox_tab_toggle.dart';

/// Inbox screen containing Messages and Notifications tabs.
///
/// Uses a segmented toggle at the top to switch between the two tabs.
/// An [IndexedStack] preserves the state of both tabs when switching.
class InboxScreen extends ConsumerStatefulWidget {
  /// Route name for this screen.
  static const routeName = 'inbox';

  /// Path for this route.
  static const path = '/inbox';

  /// Path for this route with index.
  static const pathWithIndex = '/inbox/:index';

  /// Build path for a specific index.
  static String pathForIndex([int? index]) =>
      index == null ? path : '$path/$index';

  const InboxScreen({super.key});

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen> {
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
  }

  void _onTabChanged(int index) {
    setState(() {
      _selectedTabIndex = index;
    });

    // Mark notifications as read when switching to the
    // notifications tab
    if (index == 1) {
      ref.read(relayNotificationsProvider.notifier).markAllAsRead();
    }
  }

  @override
  Widget build(BuildContext context) {
    final notificationUnread = ref.watch(relayNotificationUnreadCountProvider);
    final dmUnread = context.watch<DmUnreadCountCubit>().state;

    return ColoredBox(
      color: VineTheme.surfaceBackground,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            InboxTabToggle(
              selectedIndex: _selectedTabIndex,
              onChanged: _onTabChanged,
              notificationBadgeCount: notificationUnread,
              messagesBadgeCount: dmUnread,
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(48),
                  bottom: Radius.circular(48),
                ),
                child: ColoredBox(
                  color: VineTheme.surfaceContainerHigh,
                  child: IndexedStack(
                    index: _selectedTabIndex,
                    children: const [MessagesTab(), NotificationsTab()],
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
