// ABOUTME: Global auth-scoped BLoC that exposes the owner's people lists.
// ABOUTME: Subscribes to PeopleListsRepository and applies optimistic changes.

import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart';
import 'package:people_lists_repository/people_lists_repository.dart';

part 'people_lists_event.dart';
part 'people_lists_mutation.dart';
part 'people_lists_state.dart';

/// Signature for a clock used by [PeopleListsBloc] to stamp optimistic
/// `updatedAt` values and mutation ids. Injected via the constructor so
/// tests can supply a deterministic clock.
typedef PeopleListsClock = DateTime Function();

/// Global, auth-scoped BLoC that owns the authenticated user's people
/// lists.
///
/// The bloc subscribes to [PeopleListsRepository.watchLists] for the
/// currently authenticated owner, rebuilds the
/// [PeopleListsState.listIdsByPubkey] reverse index whenever the snapshot
/// changes, and applies optimistic updates for user-initiated mutations
/// before the repository returns.
///
/// It depends only on the repository and an owner-pubkey stream — it does
/// not import other BLoCs. Owner transitions cancel the prior
/// subscription, clear pending mutations, and start a new subscription
/// plus an out-of-band sync.
///
/// ## Failure recovery contract
///
/// A mutation that throws transitions [PeopleListsState.status] to
/// [PeopleListsStatus.failure] and reports the error via `addError`. The
/// status automatically recovers to [PeopleListsStatus.ready] once all
/// pending mutations drain without a fresh failure, so the UI does not
/// stay stuck on `failure` when subsequent mutations succeed or the
/// repository stream never re-emits.
class PeopleListsBloc extends Bloc<PeopleListsEvent, PeopleListsState> {
  /// Creates a new bloc instance.
  ///
  /// [ownerPubkeyStream] must emit `null` when unauthenticated and the
  /// full hex pubkey of the current owner when authenticated. The caller
  /// typically adapts an auth service's state stream into this shape so
  /// the bloc has no Flutter or Riverpod dependency.
  ///
  /// [clock] stamps optimistic `updatedAt` values and mutation ids.
  /// Defaults to [DateTime.now] in UTC. Tests inject a fixed clock for
  /// determinism.
  PeopleListsBloc({
    required PeopleListsRepository repository,
    required Stream<String?> ownerPubkeyStream,
    String? initialOwnerPubkey,
    PeopleListsClock? clock,
  }) : _repository = repository,
       _ownerPubkeyStream = ownerPubkeyStream,
       _clock = clock ?? _defaultClock,
       super(
         PeopleListsState(ownerPubkey: initialOwnerPubkey),
       ) {
    on<PeopleListsStarted>(_onStarted);
    on<PeopleListsOwnerChanged>(_onOwnerChanged, transformer: sequential());
    on<PeopleListsRepositoryListsChanged>(_onRepositoryListsChanged);
    on<PeopleListsCreateRequested>(
      _onCreateRequested,
      transformer: droppable(),
    );
    on<PeopleListsDeleteRequested>(
      _onDeleteRequested,
      transformer: sequential(),
    );
    on<PeopleListsPubkeyAddRequested>(
      _onPubkeyAddRequested,
      transformer: sequential(),
    );
    on<PeopleListsPubkeyRemoveRequested>(
      _onPubkeyRemoveRequested,
      transformer: sequential(),
    );
    on<PeopleListsPubkeyToggleRequested>(
      _onPubkeyToggleRequested,
      transformer: sequential(),
    );
  }

  static DateTime _defaultClock() => DateTime.now().toUtc();

  final PeopleListsRepository _repository;
  final Stream<String?> _ownerPubkeyStream;
  final PeopleListsClock _clock;

  StreamSubscription<String?>? _ownerSubscription;
  StreamSubscription<List<UserList>>? _listsSubscription;

  @override
  Future<void> close() async {
    await _ownerSubscription?.cancel();
    await _listsSubscription?.cancel();
    return super.close();
  }

  // --------------------------------------------------------------------------
  // Stream wiring
  // --------------------------------------------------------------------------

  Future<void> _onStarted(
    PeopleListsStarted event,
    Emitter<PeopleListsState> emit,
  ) async {
    await _ownerSubscription?.cancel();
    _ownerSubscription = _ownerPubkeyStream.listen(
      (ownerPubkey) => add(
        PeopleListsOwnerChanged(ownerPubkey: ownerPubkey),
      ),
      onError: (Object error, StackTrace stackTrace) {
        addError(error, stackTrace);
      },
    );

    final currentOwner = state.ownerPubkey;
    if (currentOwner != null && currentOwner.isNotEmpty) {
      add(PeopleListsOwnerChanged(ownerPubkey: currentOwner));
    }
  }

  Future<void> _onOwnerChanged(
    PeopleListsOwnerChanged event,
    Emitter<PeopleListsState> emit,
  ) async {
    final newOwner = event.ownerPubkey;
    if (newOwner == state.ownerPubkey &&
        state.status != PeopleListsStatus.initial) {
      return;
    }

    await _listsSubscription?.cancel();
    _listsSubscription = null;

    if (newOwner == null || newOwner.isEmpty) {
      emit(const PeopleListsState());
      return;
    }

    emit(
      PeopleListsState(
        status: PeopleListsStatus.loading,
        ownerPubkey: newOwner,
      ),
    );

    _listsSubscription = _repository
        .watchLists(ownerPubkey: newOwner)
        .listen(
          (lists) => add(
            PeopleListsRepositoryListsChanged(
              ownerPubkey: newOwner,
              lists: lists,
            ),
          ),
          onError: (Object error, StackTrace stackTrace) {
            addError(error, stackTrace);
          },
        );

    unawaited(_repository.syncOwner(ownerPubkey: newOwner));
  }

  void _onRepositoryListsChanged(
    PeopleListsRepositoryListsChanged event,
    Emitter<PeopleListsState> emit,
  ) {
    // Ignore late emissions from a previous owner.
    if (event.ownerPubkey != state.ownerPubkey) {
      return;
    }

    emit(
      state.copyWith(
        status: PeopleListsStatus.ready,
        lists: event.lists,
        listIdsByPubkey: _buildReverseIndex(event.lists),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Mutation handlers
  // --------------------------------------------------------------------------

  Future<void> _onCreateRequested(
    PeopleListsCreateRequested event,
    Emitter<PeopleListsState> emit,
  ) async {
    final owner = state.ownerPubkey;
    if (owner == null || owner.isEmpty) {
      return;
    }

    final mutation = _buildMutation(
      PeopleListsMutationKind.createList,
    );
    emit(_withMutation(state, mutation, status: PeopleListsStatus.submitting));

    try {
      final result = await _repository.createList(
        ownerPubkey: owner,
        name: event.name,
        description: event.description,
        imageUrl: event.imageUrl,
        initialPubkeys: event.initialPubkeys,
      );
      emit(
        _withoutMutation(state, mutation.id, resultEventId: result.eventId),
      );
    } catch (e, stackTrace) {
      addError(e, stackTrace);
      emit(_withoutMutation(state, mutation.id, failed: true));
    }
  }

  Future<void> _onDeleteRequested(
    PeopleListsDeleteRequested event,
    Emitter<PeopleListsState> emit,
  ) async {
    final owner = state.ownerPubkey;
    if (owner == null || owner.isEmpty) {
      return;
    }

    final mutation = _buildMutation(
      PeopleListsMutationKind.deleteList,
      listId: event.listId,
    );

    // Optimistically remove the list and any reverse-index entries.
    final optimisticLists = state.lists
        .where((list) => list.id != event.listId)
        .toList(growable: false);
    emit(
      _withMutation(
        state.copyWith(
          lists: optimisticLists,
          listIdsByPubkey: _buildReverseIndex(optimisticLists),
        ),
        mutation,
        status: PeopleListsStatus.submitting,
      ),
    );

    try {
      final result = await _repository.deleteList(
        ownerPubkey: owner,
        listId: event.listId,
      );
      emit(
        _withoutMutation(state, mutation.id, resultEventId: result.eventId),
      );
    } catch (e, stackTrace) {
      addError(e, stackTrace);
      emit(_withoutMutation(state, mutation.id, failed: true));
    }
  }

  Future<void> _onPubkeyAddRequested(
    PeopleListsPubkeyAddRequested event,
    Emitter<PeopleListsState> emit,
  ) async {
    await _performAdd(
      listId: event.listId,
      pubkey: event.pubkey,
      emit: emit,
    );
  }

  Future<void> _onPubkeyRemoveRequested(
    PeopleListsPubkeyRemoveRequested event,
    Emitter<PeopleListsState> emit,
  ) async {
    await _performRemove(
      listId: event.listId,
      pubkey: event.pubkey,
      emit: emit,
    );
  }

  Future<void> _onPubkeyToggleRequested(
    PeopleListsPubkeyToggleRequested event,
    Emitter<PeopleListsState> emit,
  ) async {
    final currentMembers =
        state.listIdsByPubkey[event.pubkey] ?? const <String>{};
    final alreadyMember = currentMembers.contains(event.listId);

    // Run the shared add/remove helpers inline. The handler is
    // registered with `sequential()`, so a rapid double-tap is serialized
    // and each invocation reads the up-to-date state instead of
    // re-dispatching a stale action.
    if (alreadyMember) {
      await _performRemove(
        listId: event.listId,
        pubkey: event.pubkey,
        emit: emit,
      );
    } else {
      await _performAdd(
        listId: event.listId,
        pubkey: event.pubkey,
        emit: emit,
      );
    }
  }

  // --------------------------------------------------------------------------
  // Shared add/remove implementation
  // --------------------------------------------------------------------------

  Future<void> _performAdd({
    required String listId,
    required String pubkey,
    required Emitter<PeopleListsState> emit,
  }) async {
    final owner = state.ownerPubkey;
    if (owner == null || owner.isEmpty) {
      return;
    }

    // No-op when the pubkey is already a member.
    final currentMembers = state.listIdsByPubkey[pubkey] ?? const <String>{};
    if (currentMembers.contains(listId)) {
      return;
    }

    final mutation = _buildMutation(
      PeopleListsMutationKind.addPubkey,
      listId: listId,
      pubkey: pubkey,
    );
    final previousLists = List<UserList>.of(state.lists, growable: false);
    final previousIndex = _copyReverseIndex(state.listIdsByPubkey);

    final optimisticLists = _applyOptimisticAdd(
      state.lists,
      listId: listId,
      pubkey: pubkey,
      now: _clock(),
    );
    emit(
      _withMutation(
        state.copyWith(
          lists: optimisticLists,
          listIdsByPubkey: _buildReverseIndex(optimisticLists),
        ),
        mutation,
        status: PeopleListsStatus.submitting,
      ),
    );

    try {
      final result = await _repository.addPubkey(
        ownerPubkey: owner,
        listId: listId,
        pubkey: pubkey,
      );
      emit(
        _withoutMutation(state, mutation.id, resultEventId: result.eventId),
      );
    } catch (e, stackTrace) {
      addError(e, stackTrace);
      emit(
        _withoutMutation(state, mutation.id, failed: true).copyWith(
          lists: previousLists,
          listIdsByPubkey: previousIndex,
        ),
      );
    }
  }

  Future<void> _performRemove({
    required String listId,
    required String pubkey,
    required Emitter<PeopleListsState> emit,
  }) async {
    final owner = state.ownerPubkey;
    if (owner == null || owner.isEmpty) {
      return;
    }

    // No-op when the pubkey is not a member.
    final currentMembers = state.listIdsByPubkey[pubkey] ?? const <String>{};
    if (!currentMembers.contains(listId)) {
      return;
    }

    final mutation = _buildMutation(
      PeopleListsMutationKind.removePubkey,
      listId: listId,
      pubkey: pubkey,
    );
    final previousLists = List<UserList>.of(state.lists, growable: false);
    final previousIndex = _copyReverseIndex(state.listIdsByPubkey);

    final optimisticLists = _applyOptimisticRemove(
      state.lists,
      listId: listId,
      pubkey: pubkey,
      now: _clock(),
    );
    emit(
      _withMutation(
        state.copyWith(
          lists: optimisticLists,
          listIdsByPubkey: _buildReverseIndex(optimisticLists),
        ),
        mutation,
        status: PeopleListsStatus.submitting,
      ),
    );

    try {
      final result = await _repository.removePubkey(
        ownerPubkey: owner,
        listId: listId,
        pubkey: pubkey,
      );
      emit(
        _withoutMutation(state, mutation.id, resultEventId: result.eventId),
      );
    } catch (e, stackTrace) {
      addError(e, stackTrace);
      emit(
        _withoutMutation(state, mutation.id, failed: true).copyWith(
          lists: previousLists,
          listIdsByPubkey: previousIndex,
        ),
      );
    }
  }

  // --------------------------------------------------------------------------
  // Helpers
  // --------------------------------------------------------------------------

  /// Builds a mutation record with a unique id.
  ///
  /// The id combines the clock's microsecond epoch with the mutation
  /// kind and target — unique without needing a mutable counter on the
  /// bloc instance (forbidden by `rules/state_management.md`). The clock
  /// is injected so tests can feed a monotonically increasing sequence.
  PeopleListsMutation _buildMutation(
    PeopleListsMutationKind kind, {
    String? listId,
    String? pubkey,
  }) {
    final stamp = _clock().microsecondsSinceEpoch;
    final suffix = listId != null
        ? '-$listId'
        : (pubkey != null ? '-$pubkey' : '');
    return PeopleListsMutation(
      id: 'mut-$stamp-${kind.name}$suffix',
      kind: kind,
      listId: listId,
      pubkey: pubkey,
    );
  }

  PeopleListsState _withMutation(
    PeopleListsState current,
    PeopleListsMutation mutation, {
    PeopleListsStatus? status,
  }) {
    final next = Map<String, PeopleListsMutation>.from(
      current.pendingMutations,
    )..[mutation.id] = mutation;
    return current.copyWith(
      status: status,
      pendingMutations: next,
    );
  }

  PeopleListsState _withoutMutation(
    PeopleListsState current,
    String mutationId, {
    String? resultEventId,
    bool failed = false,
  }) {
    final next = Map<String, PeopleListsMutation>.from(
      current.pendingMutations,
    )..remove(mutationId);
    // Recovery contract: a fresh failure pins `failure`; otherwise, once
    // the last pending mutation drains, reset any sticky `failure` back
    // to `ready` so the UI isn't stuck if the repository never re-emits.
    final PeopleListsStatus nextStatus;
    if (failed) {
      nextStatus = PeopleListsStatus.failure;
    } else if (next.isEmpty) {
      nextStatus = PeopleListsStatus.ready;
    } else {
      nextStatus = current.status;
    }
    return current.copyWith(
      status: nextStatus,
      pendingMutations: next,
      lastSubmittedEventId: resultEventId,
    );
  }

  /// Rebuilds the pubkey→listIds reverse index from [lists].
  static Map<String, Set<String>> _buildReverseIndex(List<UserList> lists) {
    final index = <String, Set<String>>{};
    for (final list in lists) {
      for (final pubkey in list.pubkeys) {
        (index[pubkey] ??= <String>{}).add(list.id);
      }
    }
    return index;
  }

  static Map<String, Set<String>> _copyReverseIndex(
    Map<String, Set<String>> index,
  ) {
    return {
      for (final entry in index.entries) entry.key: Set<String>.of(entry.value),
    };
  }

  static List<UserList> _applyOptimisticAdd(
    List<UserList> lists, {
    required String listId,
    required String pubkey,
    required DateTime now,
  }) {
    return lists
        .map((list) {
          if (list.id != listId) return list;
          if (list.pubkeys.contains(pubkey)) return list;
          return list.copyWith(
            pubkeys: [...list.pubkeys, pubkey],
            updatedAt: now,
          );
        })
        .toList(growable: false);
  }

  static List<UserList> _applyOptimisticRemove(
    List<UserList> lists, {
    required String listId,
    required String pubkey,
    required DateTime now,
  }) {
    return lists
        .map((list) {
          if (list.id != listId) return list;
          if (!list.pubkeys.contains(pubkey)) return list;
          return list.copyWith(
            pubkeys: list.pubkeys.where((p) => p != pubkey).toList(),
            updatedAt: now,
          );
        })
        .toList(growable: false);
  }
}
