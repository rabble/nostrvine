// ABOUTME: Events for the PeopleListsBloc.
// ABOUTME: Covers startup, owner transitions, and user-driven mutations.

part of 'people_lists_bloc.dart';

/// Base class for all [PeopleListsBloc] events.
sealed class PeopleListsEvent extends Equatable {
  const PeopleListsEvent();

  @override
  List<Object?> get props => const [];
}

/// Triggers the bloc to begin observing the owner pubkey stream.
class PeopleListsStarted extends PeopleListsEvent {
  /// Creates a startup event.
  const PeopleListsStarted();
}

/// Internal event emitted when the owner pubkey stream changes.
class PeopleListsOwnerChanged extends PeopleListsEvent {
  /// Creates an owner-change event.
  const PeopleListsOwnerChanged({required this.ownerPubkey});

  /// The new owner pubkey (full hex), or `null` when unauthenticated.
  final String? ownerPubkey;

  @override
  List<Object?> get props => [ownerPubkey];
}

/// Internal event emitted whenever the repository publishes a new set of
/// lists for the active owner.
class PeopleListsRepositoryListsChanged extends PeopleListsEvent {
  /// Creates a repository-lists-changed event.
  const PeopleListsRepositoryListsChanged({
    required this.ownerPubkey,
    required this.lists,
  });

  /// The owner pubkey whose lists changed. Full hex; never truncated.
  final String ownerPubkey;

  /// The new list snapshot from the repository.
  final List<UserList> lists;

  @override
  List<Object?> get props => [ownerPubkey, lists];
}

/// Requests creation of a new people list.
class PeopleListsCreateRequested extends PeopleListsEvent {
  /// Creates a create-list request.
  const PeopleListsCreateRequested({
    required this.name,
    this.description,
    this.imageUrl,
    this.initialPubkeys = const [],
  });

  /// Display name for the new list.
  final String name;

  /// Optional description text.
  final String? description;

  /// Optional image URL.
  final String? imageUrl;

  /// Full-hex pubkeys to seed the list with.
  final List<String> initialPubkeys;

  @override
  List<Object?> get props => [name, description, imageUrl, initialPubkeys];
}

/// Requests deletion of a people list.
class PeopleListsDeleteRequested extends PeopleListsEvent {
  /// Creates a delete-list request.
  const PeopleListsDeleteRequested({required this.listId});

  /// The full addressable id of the list to delete.
  final String listId;

  @override
  List<Object?> get props => [listId];
}

/// Requests adding a pubkey to an existing list.
class PeopleListsPubkeyAddRequested extends PeopleListsEvent {
  /// Creates an add-pubkey request.
  const PeopleListsPubkeyAddRequested({
    required this.listId,
    required this.pubkey,
  });

  /// The target list's id.
  final String listId;

  /// The full hex pubkey to add. Never truncated.
  final String pubkey;

  @override
  List<Object?> get props => [listId, pubkey];
}

/// Requests removal of a pubkey from an existing list.
class PeopleListsPubkeyRemoveRequested extends PeopleListsEvent {
  /// Creates a remove-pubkey request.
  const PeopleListsPubkeyRemoveRequested({
    required this.listId,
    required this.pubkey,
  });

  /// The target list's id.
  final String listId;

  /// The full hex pubkey to remove. Never truncated.
  final String pubkey;

  @override
  List<Object?> get props => [listId, pubkey];
}

/// Toggles a pubkey's membership in a list (add if absent, remove if
/// present).
class PeopleListsPubkeyToggleRequested extends PeopleListsEvent {
  /// Creates a toggle-pubkey request.
  const PeopleListsPubkeyToggleRequested({
    required this.listId,
    required this.pubkey,
  });

  /// The target list's id.
  final String listId;

  /// The full hex pubkey to toggle. Never truncated.
  final String pubkey;

  @override
  List<Object?> get props => [listId, pubkey];
}
