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

/// Global, auth-scoped BLoC that owns the authenticated user's people
/// lists.
///
/// The bloc subscribes to [PeopleListsRepository.watchLists] for the
/// currently authenticated owner, rebuilds the [PeopleListsState.listIdsByPubkey]
/// reverse index whenever the snapshot changes, and applies optimistic
/// updates for user-initiated mutations before the repository returns.
///
/// It depends only on the repository and an owner-pubkey stream — it does
/// not import other BLoCs. Owner transitions cancel the prior
/// subscription, clear pending mutations, and start a new subscription
/// plus an out-of-band sync.
class PeopleListsBloc extends Bloc<PeopleListsEvent, PeopleListsState> {
  /// Creates a new bloc instance.
  ///
  /// [ownerPubkeyStream] must emit `null` when unauthenticated and the
  /// full hex pubkey of the current owner when authenticated. The caller
  /// typically adapts an auth service's state stream into this shape so
  /// the bloc has no Flutter or Riverpod dependency.
  PeopleListsBloc({
    required PeopleListsRepository repository,
    required Stream<String?> ownerPubkeyStream,
    String? initialOwnerPubkey,
  }) : _repository = repository,
       _ownerPubkeyStream = ownerPubkeyStream,
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

  final PeopleListsRepository _repository;
  final Stream<String?> _ownerPubkeyStream;

  StreamSubscription<String?>? _ownerSubscription;
  StreamSubscription<List<UserList>>? _listsSubscription;

  int _mutationCounter = 0;

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

    final mutation = _registerMutation(
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
      emit(
        _withoutMutation(
          state,
          mutation.id,
          failed: true,
        ),
      );
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

    final mutation = _registerMutation(
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
    final owner = state.ownerPubkey;
    if (owner == null || owner.isEmpty) {
      return;
    }

    // No-op when the pubkey is already a member.
    final currentMembers =
        state.listIdsByPubkey[event.pubkey] ?? const <String>{};
    if (currentMembers.contains(event.listId)) {
      return;
    }

    final mutation = _registerMutation(
      PeopleListsMutationKind.addPubkey,
      listId: event.listId,
      pubkey: event.pubkey,
    );

    final optimisticLists = _applyOptimisticAdd(
      state.lists,
      listId: event.listId,
      pubkey: event.pubkey,
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
        listId: event.listId,
        pubkey: event.pubkey,
      );
      emit(
        _withoutMutation(state, mutation.id, resultEventId: result.eventId),
      );
    } catch (e, stackTrace) {
      addError(e, stackTrace);
      emit(_withoutMutation(state, mutation.id, failed: true));
    }
  }

  Future<void> _onPubkeyRemoveRequested(
    PeopleListsPubkeyRemoveRequested event,
    Emitter<PeopleListsState> emit,
  ) async {
    final owner = state.ownerPubkey;
    if (owner == null || owner.isEmpty) {
      return;
    }

    // No-op when the pubkey is not a member.
    final currentMembers =
        state.listIdsByPubkey[event.pubkey] ?? const <String>{};
    if (!currentMembers.contains(event.listId)) {
      return;
    }

    final mutation = _registerMutation(
      PeopleListsMutationKind.removePubkey,
      listId: event.listId,
      pubkey: event.pubkey,
    );

    final optimisticLists = _applyOptimisticRemove(
      state.lists,
      listId: event.listId,
      pubkey: event.pubkey,
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
        listId: event.listId,
        pubkey: event.pubkey,
      );
      emit(
        _withoutMutation(state, mutation.id, resultEventId: result.eventId),
      );
    } catch (e, stackTrace) {
      addError(e, stackTrace);
      emit(_withoutMutation(state, mutation.id, failed: true));
    }
  }

  Future<void> _onPubkeyToggleRequested(
    PeopleListsPubkeyToggleRequested event,
    Emitter<PeopleListsState> emit,
  ) async {
    final currentMembers =
        state.listIdsByPubkey[event.pubkey] ?? const <String>{};
    if (currentMembers.contains(event.listId)) {
      add(
        PeopleListsPubkeyRemoveRequested(
          listId: event.listId,
          pubkey: event.pubkey,
        ),
      );
    } else {
      add(
        PeopleListsPubkeyAddRequested(
          listId: event.listId,
          pubkey: event.pubkey,
        ),
      );
    }
  }

  // --------------------------------------------------------------------------
  // Helpers
  // --------------------------------------------------------------------------

  PeopleListsMutation _registerMutation(
    PeopleListsMutationKind kind, {
    String? listId,
    String? pubkey,
  }) {
    _mutationCounter += 1;
    return PeopleListsMutation(
      id: 'mut-$_mutationCounter-${kind.name}',
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
    final nextStatus = failed
        ? PeopleListsStatus.failure
        : (next.isEmpty ? PeopleListsStatus.ready : current.status);
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

  static List<UserList> _applyOptimisticAdd(
    List<UserList> lists, {
    required String listId,
    required String pubkey,
  }) {
    return lists
        .map((list) {
          if (list.id != listId) return list;
          if (list.pubkeys.contains(pubkey)) return list;
          return list.copyWith(
            pubkeys: [...list.pubkeys, pubkey],
            updatedAt: DateTime.now().toUtc(),
          );
        })
        .toList(growable: false);
  }

  static List<UserList> _applyOptimisticRemove(
    List<UserList> lists, {
    required String listId,
    required String pubkey,
  }) {
    return lists
        .map((list) {
          if (list.id != listId) return list;
          if (!list.pubkeys.contains(pubkey)) return list;
          return list.copyWith(
            pubkeys: list.pubkeys.where((p) => p != pubkey).toList(),
            updatedAt: DateTime.now().toUtc(),
          );
        })
        .toList(growable: false);
  }
}
