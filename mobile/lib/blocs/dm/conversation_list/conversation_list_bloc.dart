// ABOUTME: BLoC for the conversation list (Messages tab).
// ABOUTME: Manages loading conversations with pagination, handling real-time
// ABOUTME: updates, marking conversations as read, and splitting conversations
// ABOUTME: into normal inbox vs message requests based on follow state.

import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:models/models.dart';
import 'package:openvine/repositories/dm_repository.dart';
import 'package:openvine/repositories/follow_repository.dart';
import 'package:rxdart/rxdart.dart';

part 'conversation_list_event.dart';
part 'conversation_list_state.dart';

class ConversationListBloc
    extends Bloc<ConversationListEvent, ConversationListState> {
  ConversationListBloc({
    required DmRepository dmRepository,
    required FollowRepository followRepository,
  }) : _dmRepository = dmRepository,
       _followRepository = followRepository,
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
  final FollowRepository _followRepository;

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

    // Stream 1: accepted conversations (paginated, user has sent).
    // Stream 2: potential requests (unpaginated, user has NOT sent).
    // Stream 3: following list changes (triggers re-classification).
    // Combining ensures requests are never truncated by pagination
    // and follow-list changes are handled automatically.
    await emit.forEach(
      Rx.combineLatest3(
        _dmRepository.watchAcceptedConversations(
          limit: state.currentLimit,
        ),
        _dmRepository.watchPotentialRequests(),
        _followRepository.followingStream.startWith(const []),
        (accepted, potentialRequests, _) => (
          accepted: accepted,
          potentialRequests: potentialRequests,
        ),
      ),
      onData: (data) {
        final split = DmRepository.classifyPotentialRequests(
          data.potentialRequests,
          userPubkey: _dmRepository.userPubkey,
          isFollowing: _followRepository.isFollowing,
        );
        return state.copyWith(
          status: ConversationListStatus.loaded,
          conversations: DmRepository.mergeAndSort(
            data.accepted,
            split.followed,
          ),
          requestConversations: split.requests,
          potentialRequests: data.potentialRequests,
          hasMore: data.accepted.length >= state.currentLimit,
          isLoadingMore: false,
        );
      },
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
