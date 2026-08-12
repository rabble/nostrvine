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

/// The user selected a chip in the Messages filter row.
class ConversationListFilterChanged extends ConversationListEvent {
  const ConversationListFilterChanged(this.filter);

  final InboxFilter filter;

  @override
  List<Object?> get props => [filter];
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

/// The user tapped Retry on the restore-paused banner.
///
/// Re-arms the one-time history drain and the failed-decrypt replay. Both are
/// idempotent and share their in-flight future, so a stray tap during an active
/// pass is a no-op rather than a second drain.
class ConversationListRestoreRetryRequested extends ConversationListEvent {
  const ConversationListRestoreRetryRequested();
}

/// Resolve names for newly streamed conversations without changing the query.
class _ConversationListProfileResolutionRequested
    extends ConversationListEvent {
  const _ConversationListProfileResolutionRequested();
}
