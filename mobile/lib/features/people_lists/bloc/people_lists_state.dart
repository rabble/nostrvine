// ABOUTME: State for PeopleListsBloc tracking owner-scoped people lists.
// ABOUTME: Holds status, owner pubkey, lists, reverse index, pending mutations.

part of 'people_lists_bloc.dart';

/// Status of the global people-lists bloc.
enum PeopleListsStatus {
  /// No owner pubkey has been observed yet.
  initial,

  /// Loading lists for the current owner.
  loading,

  /// Lists have been loaded (or are streaming) for the current owner.
  ready,

  /// A mutation is in flight.
  submitting,

  /// A recent operation failed. The bloc recovers to [ready] once all
  /// pending mutations drain.
  failure,
}

/// State of [PeopleListsBloc].
///
/// Holds the authenticated owner's editable people lists, a reverse index
/// from pubkey → list IDs for O(1) membership checks, and in-flight
/// [PeopleListsMutation] records so the UI can render optimistic changes.
///
/// Per `rules/state_management.md`, no error text or exception objects are
/// stored here. Errors are reported via `addError` on the bloc and surfaced
/// through [PeopleListsStatus.failure]; translated strings live in the UI.
class PeopleListsState extends Equatable {
  /// Creates a new state value.
  const PeopleListsState({
    this.status = PeopleListsStatus.initial,
    this.ownerPubkey,
    this.lists = const [],
    this.listIdsByPubkey = const {},
    this.pendingMutations = const {},
    this.lastSubmittedEventId,
  });

  /// Current status of the bloc.
  final PeopleListsStatus status;

  /// Full hex pubkey of the authenticated owner, or `null` when
  /// unauthenticated. Never truncated.
  final String? ownerPubkey;

  /// Editable people lists owned by [ownerPubkey], latest snapshot.
  final List<UserList> lists;

  /// Reverse membership index — full pubkey → set of list IDs that
  /// currently contain that pubkey. Pubkeys are never truncated.
  final Map<String, Set<String>> listIdsByPubkey;

  /// In-flight mutations keyed by stable mutation id.
  final Map<String, PeopleListsMutation> pendingMutations;

  /// The id of the most recently submitted event (if any). Submitted
  /// means the repository successfully handed the event to at least one
  /// relay socket — not relay `OK` confirmation.
  final String? lastSubmittedEventId;

  /// Creates a copy with updated fields.
  PeopleListsState copyWith({
    PeopleListsStatus? status,
    String? ownerPubkey,
    bool clearOwnerPubkey = false,
    List<UserList>? lists,
    Map<String, Set<String>>? listIdsByPubkey,
    Map<String, PeopleListsMutation>? pendingMutations,
    String? lastSubmittedEventId,
    bool clearLastSubmittedEventId = false,
  }) {
    return PeopleListsState(
      status: status ?? this.status,
      ownerPubkey: clearOwnerPubkey ? null : (ownerPubkey ?? this.ownerPubkey),
      lists: lists ?? this.lists,
      listIdsByPubkey: listIdsByPubkey ?? this.listIdsByPubkey,
      pendingMutations: pendingMutations ?? this.pendingMutations,
      lastSubmittedEventId: clearLastSubmittedEventId
          ? null
          : (lastSubmittedEventId ?? this.lastSubmittedEventId),
    );
  }

  @override
  List<Object?> get props => [
    status,
    ownerPubkey,
    lists,
    listIdsByPubkey,
    pendingMutations,
    lastSubmittedEventId,
  ];
}
