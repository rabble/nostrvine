// ABOUTME: Cubit for message request actions (decline, mark-all-read,
// ABOUTME: remove-all). Used by the Message Requests inbox and preview screens.

import 'package:bloc/bloc.dart';
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
  MessageRequestActionsCubit({required DmRepository dmRepository})
    : _dmRepository = dmRepository,
      super(const MessageRequestActionsState());

  final DmRepository _dmRepository;

  /// Decline and remove a single message request.
  ///
  /// Returns `true` when the removal completed, `false` when it threw. The
  /// caller must consume this result rather than reading [state] after the
  /// await: a keyed provider closing this cubit mid-operation (account switch)
  /// skips the guarded `success` emit even though the removal succeeded, so a
  /// state read would report a false failure.
  Future<bool> declineRequest(String conversationId) async {
    emit(state.copyWith(status: MessageRequestActionsStatus.processing));
    try {
      await _dmRepository.removeConversation(conversationId);
      if (!isClosed) {
        emit(state.copyWith(status: MessageRequestActionsStatus.success));
      }
      return true;
    } catch (e, stackTrace) {
      // Drift IO failures are expected. Per
      // .claude/rules/error_handling.md they are NOT Reportable.
      addError(e, stackTrace);
      if (!isClosed) {
        emit(state.copyWith(status: MessageRequestActionsStatus.error));
      }
      return false;
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
