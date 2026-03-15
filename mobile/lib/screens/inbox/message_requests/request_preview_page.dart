// ABOUTME: Page for previewing a message request before accepting/declining.
// ABOUTME: Shows sender profile, message count, and View/Decline actions.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/dm/message_requests/message_request_actions_cubit.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/inbox/message_requests/request_preview_view.dart';

/// Provides the message count for a specific conversation.
// ignore: specify_nonobvious_property_types
final _messageCountProvider = FutureProvider.family<int, String>((
  ref,
  conversationId,
) {
  final dmRepository = ref.watch(dmRepositoryProvider);
  return dmRepository.countMessagesInConversation(conversationId);
});

/// Derives participant pubkeys from the conversation ID stored in the DB.
///
/// Used as a fallback when pubkeys are not passed via route `extra`, ensuring
/// deep links work without `extra`.
// ignore: specify_nonobvious_property_types
final _participantsProvider = FutureProvider.family<List<String>, String>((
  ref,
  conversationId,
) async {
  final dmRepository = ref.watch(dmRepositoryProvider);
  final conversation = await dmRepository.getConversation(conversationId);
  if (conversation == null) return [];
  final userPubkey = dmRepository.userPubkey;
  return conversation.participantPubkeys
      .where((pk) => pk != userPubkey)
      .toList();
});

/// Request preview page.
///
/// Provides [MessageRequestActionsCubit] for the decline action and
/// fetches the message count via a Riverpod provider.
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
    final messageCount = ref.watch(_messageCountProvider(conversationId));

    // Use provided pubkeys if available, otherwise load from DB.
    final effectivePubkeys = participantPubkeys.isNotEmpty
        ? participantPubkeys
        : ref.watch(_participantsProvider(conversationId)).asData?.value ?? [];

    return BlocProvider(
      create: (_) => MessageRequestActionsCubit(dmRepository: dmRepository),
      child: RequestPreviewView(
        conversationId: conversationId,
        participantPubkeys: effectivePubkeys,
        messageCount: messageCount,
      ),
    );
  }
}
