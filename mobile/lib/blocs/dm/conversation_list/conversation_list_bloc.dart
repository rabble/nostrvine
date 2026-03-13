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
    on<ConversationListNavigateToUser>(
      _onNavigateToUser,
      transformer: droppable(),
    );
    on<ConversationListNavigationConsumed>(
      _onNavigationConsumed,
    );
  }

  final DmRepository _dmRepository;

  Future<void> _onStarted(
    ConversationListStarted event,
    Emitter<ConversationListState> emit,
  ) async {
    // Only show the loading spinner and reset limit on first load.
    if (state.status == ConversationListStatus.initial) {
      emit(
        state.copyWith(
          status: ConversationListStatus.loading,
          currentLimit: ConversationListState.pageSize,
        ),
      );
    }

    await emit.forEach(
      _dmRepository.watchConversations(limit: state.currentLimit),
      onData: (conversations) => state.copyWith(
        status: ConversationListStatus.loaded,
        conversations: conversations,
        hasMore: conversations.length >= state.currentLimit,
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

    emit(
      state.copyWith(
        isLoadingMore: true,
        currentLimit: state.currentLimit + ConversationListState.pageSize,
      ),
    );

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

  void _onNavigateToUser(
    ConversationListNavigateToUser event,
    Emitter<ConversationListState> emit,
  ) {
    final currentPubkey = _dmRepository.userPubkey;
    if (currentPubkey.isEmpty) return;

    final conversationId = DmRepository.computeConversationId(
      [currentPubkey, event.participantPubkey],
    );
    emit(
      state.copyWith(
        navigationTarget: ConversationNavigationTarget(
          conversationId: conversationId,
          participantPubkeys: [event.participantPubkey],
        ),
      ),
    );
  }

  void _onNavigationConsumed(
    ConversationListNavigationConsumed event,
    Emitter<ConversationListState> emit,
  ) {
    emit(state.copyWith(clearNavigationTarget: true));
  }
}
