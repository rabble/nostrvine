// ABOUTME: Events for ConversationListBloc.

part of 'conversation_list_bloc.dart';

sealed class ConversationListEvent extends Equatable {
  const ConversationListEvent();

  @override
  List<Object?> get props => [];
}

/// Start watching conversations from the database.
class ConversationListStarted extends ConversationListEvent {
  const ConversationListStarted();
}

/// Load the next page of conversations.
class ConversationListLoadMore extends ConversationListEvent {
  const ConversationListLoadMore();
}

/// Navigate to a conversation with the given participant.
///
/// The BLoC computes the conversation ID from the sorted pubkeys
/// and emits a navigation-ready state.
class ConversationListNavigateToUser extends ConversationListEvent {
  const ConversationListNavigateToUser(this.participantPubkey);

  final String participantPubkey;

  @override
  List<Object?> get props => [participantPubkey];
}

/// Clear the navigation target after the UI has consumed it.
class ConversationListNavigationConsumed extends ConversationListEvent {
  const ConversationListNavigationConsumed();
}

/// Toggle the unread-only filter on the Messages list.
class ConversationListUnreadFilterToggled extends ConversationListEvent {
  const ConversationListUnreadFilterToggled();
}

/// The inbox search query changed.
class ConversationListSearchQueryChanged extends ConversationListEvent {
  const ConversationListSearchQueryChanged(this.query);

  final String query;

  @override
  List<Object?> get props => [query];
}

/// Mark a conversation as read.
class ConversationListMarkRead extends ConversationListEvent {
  const ConversationListMarkRead(this.conversationId);

  final String conversationId;

  @override
  List<Object?> get props => [conversationId];
}

/// The blocklist changed — re-filter conversations to hide blocked users.
class ConversationListBlocklistChanged extends ConversationListEvent {
  const ConversationListBlocklistChanged();
}

/// A freshly built [ProfileRepository] is available for name resolution.
///
/// `profileRepositoryProvider` is nullable-gated on Nostr readiness, so it
/// resolves null -> instance shortly after cold start. Delivering that
/// instance as an event swaps the dependency in place instead of re-keying
/// the `BlocProvider`, which would re-inflate the whole inbox subtree.
class ConversationListProfileRepositoryChanged extends ConversationListEvent {
  const ConversationListProfileRepositoryChanged(this.profileRepository);

  final ProfileRepository? profileRepository;

  @override
  List<Object?> get props => [profileRepository];
}

/// Resolve names for newly streamed conversations without changing the query.
class _ConversationListProfileResolutionRequested
    extends ConversationListEvent {
  const _ConversationListProfileResolutionRequested();
}
