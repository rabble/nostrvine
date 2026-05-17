// ABOUTME: Conversation detail page that provides BLoC dependencies.
// ABOUTME: Sets up ConversationBloc from DmRepository for a specific
// ABOUTME: conversation ID derived from participant pubkeys.

import 'package:dm_repository/dm_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/dm/conversation/collaborator_invite_actions_cubit.dart';
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
    final inviteStateStore = ref.watch(collaboratorInviteStateStoreProvider);
    final inviteResponseService = ref.watch(
      collaboratorResponseServiceProvider,
    );
    final confirmationRepository = ref.watch(
      collaboratorConfirmationRepositoryProvider,
    );
    final authService = ref.watch(authServiceProvider);
    final currentPubkey = authService.currentPublicKeyHex ?? '';

    return MultiBlocProvider(
      providers: [
        // Key tracks the captured Riverpod-provided dependencies so the
        // bloc is recreated when their identity flips (auth flip, account
        // switch, sign-out). Without this key, a stale `dmRepository`
        // captured during a brief unauthenticated window would scope all
        // reads/writes by an empty/wrong `_userPubkey` for the lifetime of
        // the bloc, causing sent messages to "disappear" on re-entry.
        // See `state_management.md` → "Bridging Riverpod-provided
        // dependencies into BlocProvider" and the canonical four sites in
        // `video_feed_page.dart` / `pooled_fullscreen_video_feed_screen.dart`.
        BlocProvider<ConversationBloc>(
          key: ValueKey((dmRepository, currentPubkey)),
          create: (_) => ConversationBloc(
            dmRepository: dmRepository,
            conversationId: conversationId,
          )..add(const ConversationStarted()),
        ),
        // Same identity-keying as ConversationBloc above: the response
        // service composes `authServiceProvider` + `nostrServiceProvider`
        // (`app_providers.dart`), so its identity flips on auth changes.
        // Without the key, accept-invite would publish through whichever
        // signer/relay the cubit captured at first build, even after
        // auth flipped.
        BlocProvider<CollaboratorInviteActionsCubit>(
          key: ValueKey((
            inviteStateStore,
            inviteResponseService,
            confirmationRepository,
            currentPubkey,
          )),
          create: (_) => CollaboratorInviteActionsCubit(
            stateStore: inviteStateStore,
            responseService: inviteResponseService,
            currentUserPubkey: currentPubkey,
            confirmationRepository: confirmationRepository,
          ),
        ),
      ],
      child: ConversationView(participantPubkeys: participantPubkeys),
    );
  }
}
