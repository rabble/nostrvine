// ABOUTME: Inbox page that provides BLoC dependencies for the inbox view.
// ABOUTME: Sets up ConversationListBloc, DmUnreadCountCubit, and
// ABOUTME: MyFollowingBloc from Riverpod providers.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/dm/conversation_list/conversation_list_bloc.dart';
import 'package:openvine/blocs/dm/unread_count/dm_unread_count_cubit.dart';
import 'package:openvine/blocs/my_following/my_following_bloc.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/inbox/inbox_view.dart';

/// Inbox page (DM conversation list + notifications).
///
/// Provides [ConversationListBloc], [DmUnreadCountCubit], and
/// [MyFollowingBloc] to the widget tree.
class InboxPage extends ConsumerWidget {
  const InboxPage({super.key});

  /// Route name for this screen.
  static const routeName = 'inbox';

  /// Path for this route.
  static const path = '/inbox';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dmRepository = ref.watch(dmRepositoryProvider);
    final followRepository = ref.watch(followRepositoryProvider);
    final blocklistService = ref.watch(contentBlocklistServiceProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => ConversationListBloc(
              dmRepository: dmRepository,
              followRepository: followRepository,
            )..add(const ConversationListStarted()),
          ),
          BlocProvider(
            create: (_) => DmUnreadCountCubit(dmRepository: dmRepository),
          ),
          BlocProvider(
            create: (_) => MyFollowingBloc(
              followRepository: followRepository,
              contentBlocklistService: blocklistService,
            )..add(const MyFollowingListLoadRequested()),
          ),
        ],
        child: const InboxView(),
      ),
    );
  }
}
