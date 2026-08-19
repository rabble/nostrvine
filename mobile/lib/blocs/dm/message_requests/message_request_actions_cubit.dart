// ABOUTME: Cubit for message request actions (decline, block, mark-all-read,
// ABOUTME: remove-all). Used by the Message Requests inbox and preview screens.

import 'package:bloc/bloc.dart';
import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:equatable/equatable.dart';

enum MessageRequestActionsStatus { idle, processing, success, error }

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
    required ContentBlocklistRepository blocklistRepository,
  }) : _dmRepository = dmRepository,
       _blocklistRepository = blocklistRepository,
       super(const MessageRequestActionsState());

  final DmRepository _dmRepository;
  final ContentBlocklistRepository _blocklistRepository;

  /// Decline and remove a single message request.
  Future<void> declineRequest(String conversationId) async {
    emit(state.copyWith(status: MessageRequestActionsStatus.processing));
    try {
      await _dmRepository.removeConversation(conversationId);
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

  /// Block the sender of a request, then remove the conversation.
  ///
  /// Blocking runs through the same blocklist the conversation-list filter
  /// reads, so the request drops out of the inbox; removal clears the local
  /// history behind an owner-scoped tombstone. A later message from the
  /// blocked sender is still received and retained (readable behind the
  /// Blocked filter, per #7026) but the filter keeps it out of the inbox.
  Future<void> blockAndRemoveRequest(
    String conversationId,
    String pubkey,
  ) async {
    emit(state.copyWith(status: MessageRequestActionsStatus.processing));
    try {
      await _blocklistRepository.blockUser(
        pubkey,
        ourPubkey: _dmRepository.userPubkey,
      );
      await _dmRepository.removeConversation(conversationId);
      if (!isClosed) {
        emit(state.copyWith(status: MessageRequestActionsStatus.success));
      }
    } catch (e, stackTrace) {
      // Blocklist / Drift IO failures are expected. Per
      // .claude/rules/error_handling.md they are NOT Reportable.
      addError(e, stackTrace);
      if (!isClosed) {
        emit(state.copyWith(status: MessageRequestActionsStatus.error));
      }
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

  /// Remove all provided request conversations.
  Future<void> removeAllRequests(List<String> conversationIds) async {
    if (conversationIds.isEmpty) return;
    emit(state.copyWith(status: MessageRequestActionsStatus.processing));
    try {
      await _dmRepository.removeConversations(conversationIds);
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
}
