// ABOUTME: BLoC for the conversation list (Messages tab).
// ABOUTME: Manages loading conversations, handling real-time updates,
// ABOUTME: and marking conversations as read.

import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:models/models.dart';
import 'package:openvine/repositories/dm_repository.dart';

part 'conversation_list_event.dart';
part 'conversation_list_state.dart';

class ConversationListBloc
    extends Bloc<ConversationListEvent, ConversationListState> {
  ConversationListBloc({required DmRepository dmRepository})
    : _dmRepository = dmRepository,
      super(const ConversationListState()) {
    on<ConversationListStarted>(
      _onStarted,
      transformer: restartable(),
    );
    on<ConversationListMarkRead>(
      _onMarkRead,
      transformer: droppable(),
    );
  }

  final DmRepository _dmRepository;

  Future<void> _onStarted(
    ConversationListStarted event,
    Emitter<ConversationListState> emit,
  ) async {
    emit(state.copyWith(status: ConversationListStatus.loading));

    await emit.forEach(
      _dmRepository.watchConversations(),
      onData: (conversations) => state.copyWith(
        status: ConversationListStatus.loaded,
        conversations: conversations,
      ),
      onError: (error, stackTrace) {
        addError(error, stackTrace);
        return state.copyWith(
          status: ConversationListStatus.error,
        );
      },
    );
  }

  Future<void> _onMarkRead(
    ConversationListMarkRead event,
    Emitter<ConversationListState> emit,
  ) async {
    await _dmRepository.markConversationAsRead(event.conversationId);
  }
}
