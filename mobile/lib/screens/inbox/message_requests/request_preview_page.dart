// ABOUTME: Page for previewing a message request before accepting/declining.
// ABOUTME: Shows sender profile, message count, and View/Decline actions.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/dm/message_requests/message_request_actions_cubit.dart';
import 'package:openvine/blocs/dm/message_requests/request_preview_cubit.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/inbox/message_requests/request_preview_view.dart';

/// Request preview page.
///
/// Provides [RequestPreviewCubit] for data loading and
/// [MessageRequestActionsCubit] for the decline action.
class RequestPreviewPage extends ConsumerWidget {
  const RequestPreviewPage({
    required this.conversationId,
    this.participantPubkeys = const [],
    super.key,
  });

  /// Deterministic conversation ID.
  final String conversationId;

  /// Pubkeys of the other participants (excludes current user).
  ///
  /// When empty (e.g. deep link), pubkeys are loaded from the database.
  final List<String> participantPubkeys;

  static const routeName = 'requestPreview';
  static const pathPattern = '/inbox/message-requests/:id';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dmRepository = ref.watch(dmRepositoryProvider);

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => RequestPreviewCubit(
            dmRepository: dmRepository,
            conversationId: conversationId,
            initialParticipantPubkeys: participantPubkeys,
          )..load(),
        ),
        BlocProvider(
          create: (_) => MessageRequestActionsCubit(dmRepository: dmRepository),
        ),
      ],
      child: const RequestPreviewView(),
    );
  }
}
