// ABOUTME: Cubit for message request actions (decline, mark-all-read,
// ABOUTME: remove-all). Used by the Message Requests inbox and preview screens.

import 'package:bloc/bloc.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/dm_peer_account_predicate.dart';

enum MessageRequestActionsStatus { idle, processing, success, error }

/// What [MessageRequestActionsCubit.declineRequest] actually did.
///
/// Three-valued rather than a `bool` because a refusal is not a failure: the
/// caller must not report `commonSomethingWentWrong` for a request the policy
/// deliberately protects.
enum DeclineRequestOutcome {
  /// The conversation was removed.
  removed,

  /// The conversation belongs to a Divine moderation identity and is not
  /// removable. Nothing was deleted.
  refused,

  /// The removal threw.
  failed,
}

class MessageRequestActionsState extends Equatable {
  const MessageRequestActionsState({
    this.status = MessageRequestActionsStatus.idle,
  });

  final MessageRequestActionsStatus status;

  MessageRequestActionsState copyWith({MessageRequestActionsStatus? status}) {
    return MessageRequestActionsState(status: status ?? this.status);
  }

  @override
  List<Object?> get props => [status];
}

class MessageRequestActionsCubit extends Cubit<MessageRequestActionsState> {
  MessageRequestActionsCubit({
    required DmRepository dmRepository,
    DmPeerAccountPredicate moderationAccount = neverDmPeerAccount,
  }) : _dmRepository = dmRepository,
       _moderationAccount = moderationAccount,
       super(const MessageRequestActionsState());

  final DmRepository _dmRepository;

  /// Whether a peer is a Divine moderation identity, current or retired.
  ///
  /// Injected so this cubit never learns Divine's own pubkeys — same seam as
  /// `ConversationListBloc`'s. Defaults permissive, so a fixture that injects
  /// nothing keeps the pre-policy behaviour.
  final DmPeerAccountPredicate _moderationAccount;

  /// Whether [conversation] is one this cubit refuses to remove.
  ///
  /// An enforcement notice is the user's only copy of why they were actioned:
  /// there is no reason field on the account-status API and no appeals
  /// workflow behind it, while removal here is permanent — `removeConversation`
  /// writes a tombstone that suppresses relay replay for the account's
  /// lifetime. So the row stays (#6971).
  ///
  /// Self is excluded, so a signed-in moderation account can still clear its
  /// own request list. Any *other* moderation participant is enough, which
  /// covers a group that happens to include one.
  bool _isProtected(DmConversation conversation) {
    final me = _dmRepository.userPubkey;
    return conversation.participantPubkeys.any(
      (pubkey) => pubkey != me && _moderationAccount(pubkey),
    );
  }

  /// Decline and remove a single message request.
  ///
  /// Returns [DeclineRequestOutcome.removed] when the removal completed,
  /// [DeclineRequestOutcome.refused] when the conversation is protected, and
  /// [DeclineRequestOutcome.failed] when it threw. The caller must consume this
  /// result rather than reading [state] after the await: a keyed provider
  /// closing this cubit mid-operation (account switch) skips the guarded
  /// `success` emit even though the removal succeeded, so a state read would
  /// report a false failure.
  ///
  /// The guard is here rather than only in the widget because the request
  /// preview renders its decline button in states where the counterparty is
  /// not resolved yet — a conversation id is a hash of the participants, so
  /// the widget cannot always answer the question this cubit can.
  Future<DeclineRequestOutcome> declineRequest(String conversationId) async {
    emit(state.copyWith(status: MessageRequestActionsStatus.processing));
    try {
      // A missing row fails OPEN: a stale id must not become an undeletable
      // request.
      final conversation = await _dmRepository.getConversation(conversationId);
      if (conversation != null && _isProtected(conversation)) {
        if (!isClosed) {
          emit(state.copyWith(status: MessageRequestActionsStatus.idle));
        }
        return DeclineRequestOutcome.refused;
      }

      await _dmRepository.removeConversation(conversationId);
      if (!isClosed) {
        emit(state.copyWith(status: MessageRequestActionsStatus.success));
      }
      return DeclineRequestOutcome.removed;
    } catch (e, stackTrace) {
      // Drift IO failures are expected. Per
      // .claude/rules/error_handling.md they are NOT Reportable.
      addError(e, stackTrace);
      if (!isClosed) {
        emit(state.copyWith(status: MessageRequestActionsStatus.error));
      }
      return DeclineRequestOutcome.failed;
    }
  }

  /// Mark all provided request conversations as read.
  Future<void> markAllRequestsAsRead(List<String> conversationIds) async {
    if (conversationIds.isEmpty) return;
    emit(state.copyWith(status: MessageRequestActionsStatus.processing));
    try {
      await _dmRepository.markConversationsAsRead(conversationIds);
      if (!isClosed) {
        emit(state.copyWith(status: MessageRequestActionsStatus.success));
      }
    } catch (e, stackTrace) {
      // Drift IO failures are expected. Per
      // .claude/rules/error_handling.md they are NOT Reportable.
      addError(e, stackTrace);
      if (!isClosed) {
        emit(state.copyWith(status: MessageRequestActionsStatus.error));
      }
    }
  }

  /// Remove every removable conversation in [conversations].
  ///
  /// Takes conversations rather than ids so the filter can read participants
  /// without a lookup per row, and so the caller can keep passing its whole
  /// list — the decision about what "all requests" excludes lives here, not in
  /// the view, and a new caller cannot forget it.
  ///
  /// Protected conversations are skipped and remain in the request list.
  ///
  /// [withheld] is true when at least one row was kept back, so the caller can
  /// say why one stayed behind — without it the guard is invisible in the bulk
  /// path: a list holding nothing but a notice removes nothing, emits nothing,
  /// and reads as a broken button (#8347).
  ///
  /// [failed] is reported separately for the same reason [declineRequest] is
  /// three-valued: a refusal is not a failure, and the two must not share one
  /// flag. `removeConversations` runs in a transaction, so a throw rolls back
  /// every row — reporting only [withheld] there would blame the notice for a
  /// sweep that removed nothing.
  ///
  /// The caller must consume this result rather than reading [state] after the
  /// await, for the reason given on [declineRequest].
  Future<({bool withheld, bool failed})> removeAllRequests(
    List<DmConversation> conversations,
  ) async {
    final removable = [
      for (final conversation in conversations)
        if (!_isProtected(conversation)) conversation.id,
    ];
    final withheld = removable.length != conversations.length;
    if (removable.isEmpty) return (withheld: withheld, failed: false);
    emit(state.copyWith(status: MessageRequestActionsStatus.processing));
    try {
      await _dmRepository.removeConversations(removable);
      if (!isClosed) {
        emit(state.copyWith(status: MessageRequestActionsStatus.success));
      }
    } catch (e, stackTrace) {
      // Drift IO failures are expected. Per
      // .claude/rules/error_handling.md they are NOT Reportable.
      addError(e, stackTrace);
      if (!isClosed) {
        emit(state.copyWith(status: MessageRequestActionsStatus.error));
      }
      return (withheld: withheld, failed: true);
    }
    return (withheld: withheld, failed: false);
  }
}
