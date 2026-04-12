// ABOUTME: Cubit for message request actions (decline, mark-all-read, remove-all).
// ABOUTME: Used by the Message Requests inbox and preview screens.

import 'package:bloc/bloc.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:equatable/equatable.dart';

enum MessageRequestActionsStatus { idle, processing, success, error }

class MessageRequestActionsState extends Equatable {
  const MessageRequestActionsState({
    this.status = MessageRequestActionsStatus.idle,
  });

  final MessageRequestActionsStatus status;

  MessageRequestActionsState copyWith({
    MessageRequestActionsStatus? status,
  }) {
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
  Future<void> declineRequest(String conversationId) async {
    emit(state.copyWith(status: MessageRequestActionsStatus.processing));
    try {
      await _dmRepository.removeConversation(conversationId);
      emit(state.copyWith(status: MessageRequestActionsStatus.success));
    } catch (e, stackTrace) {
      addError(e, stackTrace);
      emit(state.copyWith(status: MessageRequestActionsStatus.error));
    }
  }

  /// Mark all provided request conversations as read.
  Future<void> markAllRequestsAsRead(List<String> conversationIds) async {
    if (conversationIds.isEmpty) return;
    emit(state.copyWith(status: MessageRequestActionsStatus.processing));
    try {
      await _dmRepository.markConversationsAsRead(conversationIds);
      emit(state.copyWith(status: MessageRequestActionsStatus.success));
    } catch (e, stackTrace) {
      addError(e, stackTrace);
      emit(state.copyWith(status: MessageRequestActionsStatus.error));
    }
  }

  /// Remove all provided request conversations.
  Future<void> removeAllRequests(List<String> conversationIds) async {
    if (conversationIds.isEmpty) return;
    emit(state.copyWith(status: MessageRequestActionsStatus.processing));
    try {
      await _dmRepository.removeConversations(conversationIds);
      emit(state.copyWith(status: MessageRequestActionsStatus.success));
    } catch (e, stackTrace) {
      addError(e, stackTrace);
      emit(state.copyWith(status: MessageRequestActionsStatus.error));
    }
  }
}
