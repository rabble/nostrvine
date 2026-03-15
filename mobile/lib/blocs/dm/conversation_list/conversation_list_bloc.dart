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
    on<_ConversationListFollowingChanged>(
      _onFollowingChanged,
      transformer: restartable(),
    );

    // Listen to follow-list changes and re-split conversations.
    _followingSubscription = _followRepository.followingStream.listen((_) {
      add(const _ConversationListFollowingChanged());
    });
  }

  final DmRepository _dmRepository;
  final FollowRepository _followRepository;
  StreamSubscription<List<String>>? _followingSubscription;

  @override
  Future<void> close() {
    _followingSubscription?.cancel();
    return super.close();
  }

  /// Splits potential request conversations by follow state.
  ///
  /// Conversations where `currentUserHasSent == false` are "potential
  /// requests". For 1:1 conversations from followed contacts, they go to
  /// the followed list (Messages tab). Everything else is a true request.
  ({
    List<DmConversation> followed,
    List<DmConversation> requests,
  })
  _splitPotentialRequests(List<DmConversation> potentialRequests) {
    final userPubkey = _dmRepository.userPubkey;
    final followed = <DmConversation>[];
    final requests = <DmConversation>[];

    for (final conversation in potentialRequests) {
      final otherPubkeys = conversation.participantPubkeys.where(
        (pk) => pk != userPubkey,
      );

      // A 1:1 conversation from a followed contact is not a request
      // even if the user hasn't replied yet. For groups, follow state
      // is irrelevant per the spec.
      final isFollowedContact =
          !conversation.isGroup &&
          otherPubkeys.any(_followRepository.isFollowing);

      if (otherPubkeys.isEmpty || isFollowedContact) {
        followed.add(conversation);
      } else {
        requests.add(conversation);
      }
    }

    return (followed: followed, requests: requests);
  }

  /// Merges accepted conversations with followed-but-unreplied ones
  /// and sorts by timestamp descending.
  List<DmConversation> _mergeAndSort(
    List<DmConversation> accepted,
    List<DmConversation> followedPotential,
  ) {
    if (followedPotential.isEmpty) return accepted;
    return [...accepted, ...followedPotential]..sort((a, b) {
      final aTime = a.lastMessageTimestamp ?? a.createdAt;
      final bTime = b.lastMessageTimestamp ?? b.createdAt;
      return bTime.compareTo(aTime);
    });
  }

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
    // Combining ensures requests are never truncated by pagination.
    await emit.forEach(
      Rx.combineLatest2(
        _dmRepository.watchAcceptedConversations(
          limit: state.currentLimit,
        ),
        _dmRepository.watchPotentialRequests(),
        (accepted, potentialRequests) => (
          accepted: accepted,
          potentialRequests: potentialRequests,
        ),
      ),
      onData: (data) {
        final split = _splitPotentialRequests(data.potentialRequests);
        return state.copyWith(
          status: ConversationListStatus.loaded,
          conversations: _mergeAndSort(data.accepted, split.followed),
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

  void _onFollowingChanged(
    _ConversationListFollowingChanged event,
    Emitter<ConversationListState> emit,
  ) {
    // Re-split potential requests when the follow list changes.
    // Accepted conversations (currentUserHasSent == true) are unaffected.
    if (state.status != ConversationListStatus.loaded) return;
    if (state.potentialRequests.isEmpty) return;

    final split = _splitPotentialRequests(state.potentialRequests);

    // Rebuild the conversations list: keep only the accepted ones
    // (those NOT in potentialRequests) and merge with newly classified
    // followed conversations.
    final acceptedOnly = state.conversations
        .where(
          (c) => c.currentUserHasSent,
        )
        .toList();

    emit(
      state.copyWith(
        conversations: _mergeAndSort(acceptedOnly, split.followed),
        requestConversations: split.requests,
      ),
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
