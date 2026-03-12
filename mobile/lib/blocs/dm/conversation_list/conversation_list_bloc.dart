// ABOUTME: BLoC for the conversation list (Messages tab).
// ABOUTME: Manages loading conversations with pagination, handling real-time
// ABOUTME: updates, and marking conversations as read.

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
    on<ConversationListLoadMore>(
      _onLoadMore,
      transformer: droppable(),
    );
    on<ConversationListMarkRead>(
      _onMarkRead,
      transformer: droppable(),
    );
  }

  final DmRepository _dmRepository;

  /// Number of conversations loaded per page.
  static const _pageSize = 20;

  /// Current watch limit — grows as the user loads more pages.
  int _currentLimit = _pageSize;

  Future<void> _onStarted(
    ConversationListStarted event,
    Emitter<ConversationListState> emit,
  ) async {
    // Only show the loading spinner and reset limit on first load.
    if (state.status == ConversationListStatus.initial) {
      emit(state.copyWith(status: ConversationListStatus.loading));
      _currentLimit = _pageSize;
    }

    await emit.forEach(
      _dmRepository.watchConversations(limit: _currentLimit),
      onData: (conversations) => state.copyWith(
        status: ConversationListStatus.loaded,
        conversations: conversations,
        hasMore: conversations.length >= _currentLimit,
        isLoadingMore: false,
      ),
      onError: (error, stackTrace) {
        addError(error, stackTrace);
        return state.copyWith(
          status: ConversationListStatus.error,
        );
      },
    );
  }

  Future<void> _onLoadMore(
    ConversationListLoadMore event,
    Emitter<ConversationListState> emit,
  ) async {
    if (!state.hasMore ||
        state.isLoadingMore ||
        state.status != ConversationListStatus.loaded) {
      return;
    }

    emit(state.copyWith(isLoadingMore: true));
    _currentLimit += _pageSize;

    // Re-trigger the watched stream with the larger limit.
    // restartable() on ConversationListStarted cancels the previous watch.
    add(const ConversationListStarted());
  }

  Future<void> _onMarkRead(
    ConversationListMarkRead event,
    Emitter<ConversationListState> emit,
  ) async {
    await _dmRepository.markConversationAsRead(event.conversationId);
  }
}
