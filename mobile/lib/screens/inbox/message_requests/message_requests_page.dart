// ABOUTME: Page for the message requests inbox.
// ABOUTME: Provides MessageRequestActionsCubit and ConversationListBloc
// ABOUTME: for the message requests list view.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/dm/conversation_list/conversation_list_bloc.dart';
import 'package:openvine/blocs/dm/message_requests/message_request_actions_cubit.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/inbox/message_requests/message_requests_view.dart';

/// Message Requests inbox page.
///
/// Provides [ConversationListBloc] (for the request list) and
/// [MessageRequestActionsCubit] (for bulk actions) to the widget tree.
class MessageRequestsPage extends ConsumerWidget {
  const MessageRequestsPage({super.key});

  static const routeName = 'messageRequests';
  static const path = '/inbox/message-requests';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dmRepository = ref.watch(dmRepositoryProvider);
    final followRepository = ref.watch(followRepositoryProvider);
    final blocklistService = ref.watch(contentBlocklistServiceProvider);

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => ConversationListBloc(
            dmRepository: dmRepository,
            followRepository: followRepository,
            contentBlocklistService: blocklistService,
          )..add(const ConversationListStarted()),
        ),
        BlocProvider(
          create: (_) => MessageRequestActionsCubit(
            dmRepository: dmRepository,
          ),
        ),
      ],
      child: const MessageRequestsView(),
    );
  }
}
