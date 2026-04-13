// ABOUTME: Conversation detail page that provides BLoC dependencies.
// ABOUTME: Sets up ConversationBloc from DmRepository for a specific
// ABOUTME: conversation ID derived from participant pubkeys.

import 'package:dm_repository/dm_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/dm/conversation/conversation_bloc.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/inbox/conversation/conversation_view.dart';

/// Conversation detail page (single DM thread).
///
/// Provides [ConversationBloc] to the widget tree, backed by [DmRepository].
/// The conversation ID is computed deterministically from the sorted
/// participant pubkeys.
class ConversationPage extends ConsumerWidget {
  const ConversationPage({
    required this.conversationId,
    required this.participantPubkeys,
    super.key,
  });

  /// Deterministic conversation ID (SHA-256 of sorted pubkeys).
  final String conversationId;

  /// Pubkeys of the other participants (excludes current user).
  final List<String> participantPubkeys;

  /// Route name for this screen.
  static const routeName = 'conversation';

  /// Path pattern for GoRouter.
  static const pathPattern = '/inbox/conversation/:id';

  /// Build a path for a specific conversation.
  static String pathForId(String id) => '/inbox/conversation/$id';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dmRepository = ref.watch(dmRepositoryProvider);
    final authService = ref.watch(authServiceProvider);
    final currentPubkey = authService.currentPublicKeyHex ?? '';

    return BlocProvider(
      create: (_) => ConversationBloc(
        dmRepository: dmRepository,
        conversationId: conversationId,
        currentUserPubkey: currentPubkey,
      )..add(const ConversationStarted()),
      child: ConversationView(participantPubkeys: participantPubkeys),
    );
  }
}
