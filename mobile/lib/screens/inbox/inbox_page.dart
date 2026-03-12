// ABOUTME: Inbox page that provides BLoC dependencies for the inbox view.
// ABOUTME: Sets up ConversationListBloc and DmUnreadCountCubit from
// ABOUTME: the DmRepository provider.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/dm/conversation_list/conversation_list_bloc.dart';
import 'package:openvine/blocs/dm/unread_count/dm_unread_count_cubit.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/inbox/inbox_view.dart';

/// Inbox page (DM conversation list + notifications).
///
/// Provides [ConversationListBloc] and [DmUnreadCountCubit] to the widget
/// tree, backed by the [DmRepository] from Riverpod.
class InboxPage extends ConsumerWidget {
  const InboxPage({super.key});

  /// Route name for this screen.
  static const routeName = 'inbox';

  /// Path for this route.
  static const path = '/inbox';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dmRepository = ref.watch(dmRepositoryProvider);

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) =>
              ConversationListBloc(dmRepository: dmRepository)
                ..add(const ConversationListStarted()),
        ),
        BlocProvider(
          create: (_) => DmUnreadCountCubit(dmRepository: dmRepository),
        ),
      ],
      child: const InboxView(),
    );
  }
}
