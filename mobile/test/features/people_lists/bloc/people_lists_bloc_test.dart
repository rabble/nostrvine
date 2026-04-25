// ABOUTME: Unit tests for PeopleListsBloc global owner-scoped lists state.
// ABOUTME: Covers auth transitions, optimistic mutations, and submitted state.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/features/people_lists/bloc/people_lists_bloc.dart';
import 'package:people_lists_repository/people_lists_repository.dart';

class _MockPeopleListsRepository extends Mock
    implements PeopleListsRepository {}

// Full-length Nostr pubkeys — never truncate.
const String _ownerA =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const String _ownerB =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const String _memberAlice =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
const String _memberBob =
    'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';

final DateTime _frozenNow = DateTime.utc(2026, 4, 20, 12);
DateTime _fixedClock() => _frozenNow;

UserList _buildList({
  required String id,
  required String name,
  required List<String> pubkeys,
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  return UserList(
    id: id,
    name: name,
    pubkeys: pubkeys,
    createdAt: createdAt ?? _frozenNow,
    updatedAt: updatedAt ?? _frozenNow,
  );
}

Future<void> _flush() => Future<void>.delayed(Duration.zero);

void main() {
  setUpAll(() {
    registerFallbackValue(const <String>[]);
  });

  group(PeopleListsBloc, () {
    late _MockPeopleListsRepository repository;
    late StreamController<String?> ownerPubkeyController;
    late StreamController<List<UserList>> ownerAListsController;
    late StreamController<List<UserList>> ownerBListsController;

    setUp(() {
      repository = _MockPeopleListsRepository();
      ownerPubkeyController = StreamController<String?>.broadcast();
      ownerAListsController = StreamController<List<UserList>>.broadcast();
      ownerBListsController = StreamController<List<UserList>>.broadcast();

      when(
        () => repository.watchLists(ownerPubkey: _ownerA),
      ).thenAnswer((_) => ownerAListsController.stream);
      when(
        () => repository.watchLists(ownerPubkey: _ownerB),
      ).thenAnswer((_) => ownerBListsController.stream);
      when(
        () => repository.syncOwner(ownerPubkey: any(named: 'ownerPubkey')),
      ).thenAnswer((_) async {});
    });

    tearDown(() async {
      await ownerPubkeyController.close();
      if (!ownerAListsController.isClosed) {
        await ownerAListsController.close();
      }
      if (!ownerBListsController.isClosed) {
        await ownerBListsController.close();
      }
    });

    PeopleListsBloc buildBloc({String? initialOwnerPubkey}) {
      return PeopleListsBloc(
        repository: repository,
        ownerPubkeyStream: ownerPubkeyController.stream,
        initialOwnerPubkey: initialOwnerPubkey,
        clock: _fixedClock,
      );
    }

    test('initial state is unauthenticated with empty lists', () {
      final bloc = buildBloc();
      expect(bloc.state, equals(const PeopleListsState()));
      expect(bloc.state.ownerPubkey, isNull);
      expect(bloc.state.lists, isEmpty);
      expect(bloc.state.listIdsByPubkey, isEmpty);
      addTearDown(bloc.close);
    });

    blocTest<PeopleListsBloc, PeopleListsState>(
      'loads current account lists when owner pubkey is set',
      build: buildBloc,
      act: (bloc) async {
        bloc.add(const PeopleListsStarted());
        await _flush();
        ownerPubkeyController.add(_ownerA);
        await _flush();
        ownerAListsController.add([
          _buildList(
            id: 'list-1',
            name: 'Friends',
            pubkeys: const [_memberAlice],
          ),
        ]);
        await _flush();
      },
      verify: (bloc) {
        expect(bloc.state.status, equals(PeopleListsStatus.ready));
        expect(bloc.state.ownerPubkey, equals(_ownerA));
        expect(bloc.state.lists, hasLength(1));
        expect(bloc.state.lists.first.id, equals('list-1'));
        verify(() => repository.syncOwner(ownerPubkey: _ownerA)).called(1);
      },
    );

    blocTest<PeopleListsBloc, PeopleListsState>(
      'clears lists and pending mutations on owner pubkey change',
      build: buildBloc,
      seed: () => PeopleListsState(
        status: PeopleListsStatus.ready,
        ownerPubkey: _ownerA,
        lists: [
          _buildList(
            id: 'list-1',
            name: 'Friends',
            pubkeys: const [_memberAlice],
          ),
        ],
        listIdsByPubkey: const {
          _memberAlice: {'list-1'},
        },
        pendingMutations: const {
          'mut-1': PeopleListsMutation(
            id: 'mut-1',
            listId: 'list-1',
            pubkey: _memberBob,
            kind: PeopleListsMutationKind.addPubkey,
          ),
        },
      ),
      act: (bloc) async {
        bloc.add(const PeopleListsStarted());
        await _flush();
        ownerPubkeyController.add(_ownerB);
        await _flush();
      },
      verify: (bloc) {
        expect(bloc.state.ownerPubkey, equals(_ownerB));
        expect(bloc.state.lists, isEmpty);
        expect(bloc.state.listIdsByPubkey, isEmpty);
        expect(bloc.state.pendingMutations, isEmpty);
        verify(() => repository.syncOwner(ownerPubkey: _ownerB)).called(1);
      },
    );

    blocTest<PeopleListsBloc, PeopleListsState>(
      'resets to empty state when owner pubkey becomes null',
      build: buildBloc,
      seed: () => PeopleListsState(
        status: PeopleListsStatus.ready,
        ownerPubkey: _ownerA,
        lists: [
          _buildList(
            id: 'list-1',
            name: 'Friends',
            pubkeys: const [_memberAlice],
          ),
        ],
        listIdsByPubkey: const {
          _memberAlice: {'list-1'},
        },
      ),
      act: (bloc) async {
        bloc.add(const PeopleListsStarted());
        await _flush();
        ownerPubkeyController.add(null);
        await _flush();
      },
      verify: (bloc) {
        expect(bloc.state, equals(const PeopleListsState()));
        verifyNever(
          () => repository.syncOwner(ownerPubkey: any(named: 'ownerPubkey')),
        );
      },
    );

    blocTest<PeopleListsBloc, PeopleListsState>(
      'builds listIdsByPubkey reverse index from repository lists',
      build: buildBloc,
      act: (bloc) async {
        bloc.add(const PeopleListsStarted());
        await _flush();
        ownerPubkeyController.add(_ownerA);
        await _flush();
        ownerAListsController.add([
          _buildList(
            id: 'list-friends',
            name: 'Friends',
            pubkeys: const [_memberAlice, _memberBob],
          ),
          _buildList(
            id: 'list-favs',
            name: 'Favs',
            pubkeys: const [_memberAlice],
          ),
        ]);
        await _flush();
      },
      verify: (bloc) {
        expect(
          bloc.state.listIdsByPubkey[_memberAlice],
          equals({'list-friends', 'list-favs'}),
        );
        expect(
          bloc.state.listIdsByPubkey[_memberBob],
          equals({'list-friends'}),
        );
      },
    );

    blocTest<PeopleListsBloc, PeopleListsState>(
      'emits optimistic state for add pubkey before repository returns',
      build: buildBloc,
      setUp: () {
        when(
          () => repository.addPubkey(
            ownerPubkey: _ownerA,
            listId: 'list-1',
            pubkey: _memberBob,
          ),
        ).thenAnswer(
          (_) async => const PeopleListPublishResult.submitted(
            eventId:
                '1111111111111111111111111111111111111111111111111111111111111111',
          ),
        );
      },
      seed: () => PeopleListsState(
        status: PeopleListsStatus.ready,
        ownerPubkey: _ownerA,
        lists: [
          _buildList(
            id: 'list-1',
            name: 'Friends',
            pubkeys: const [_memberAlice],
          ),
        ],
        listIdsByPubkey: const {
          _memberAlice: {'list-1'},
        },
      ),
      act: (bloc) => bloc.add(
        const PeopleListsPubkeyAddRequested(
          listId: 'list-1',
          pubkey: _memberBob,
        ),
      ),
      verify: (bloc) {
        verify(
          () => repository.addPubkey(
            ownerPubkey: _ownerA,
            listId: 'list-1',
            pubkey: _memberBob,
          ),
        ).called(1);
        expect(
          bloc.state.listIdsByPubkey[_memberBob],
          equals({'list-1'}),
        );
        expect(bloc.state.pendingMutations, isEmpty);
      },
    );

    blocTest<PeopleListsBloc, PeopleListsState>(
      'emits optimistic state for remove pubkey before repository returns',
      build: buildBloc,
      setUp: () {
        when(
          () => repository.removePubkey(
            ownerPubkey: _ownerA,
            listId: 'list-1',
            pubkey: _memberAlice,
          ),
        ).thenAnswer(
          (_) async => const PeopleListPublishResult.submitted(
            eventId:
                '2222222222222222222222222222222222222222222222222222222222222222',
          ),
        );
      },
      seed: () => PeopleListsState(
        status: PeopleListsStatus.ready,
        ownerPubkey: _ownerA,
        lists: [
          _buildList(
            id: 'list-1',
            name: 'Friends',
            pubkeys: const [_memberAlice, _memberBob],
          ),
        ],
        listIdsByPubkey: const {
          _memberAlice: {'list-1'},
          _memberBob: {'list-1'},
        },
      ),
      act: (bloc) => bloc.add(
        const PeopleListsPubkeyRemoveRequested(
          listId: 'list-1',
          pubkey: _memberAlice,
        ),
      ),
      verify: (bloc) {
        verify(
          () => repository.removePubkey(
            ownerPubkey: _ownerA,
            listId: 'list-1',
            pubkey: _memberAlice,
          ),
        ).called(1);
        expect(
          bloc.state.listIdsByPubkey.containsKey(_memberAlice),
          isFalse,
        );
        expect(bloc.state.pendingMutations, isEmpty);
      },
    );

    blocTest<PeopleListsBloc, PeopleListsState>(
      'restores exact prior lists and reverse index when add pubkey fails',
      build: buildBloc,
      setUp: () {
        when(
          () => repository.addPubkey(
            ownerPubkey: _ownerA,
            listId: 'list-1',
            pubkey: _memberBob,
          ),
        ).thenThrow(StateError('relay down'));
      },
      seed: () {
        final priorLists = [
          _buildList(
            id: 'list-1',
            name: 'Friends',
            pubkeys: const [_memberAlice],
          ),
        ];
        return PeopleListsState(
          status: PeopleListsStatus.ready,
          ownerPubkey: _ownerA,
          lists: priorLists,
          listIdsByPubkey: const {
            _memberAlice: {'list-1'},
          },
        );
      },
      errors: () => [isA<StateError>()],
      act: (bloc) => bloc.add(
        const PeopleListsPubkeyAddRequested(
          listId: 'list-1',
          pubkey: _memberBob,
        ),
      ),
      verify: (bloc) {
        final expectedLists = [
          _buildList(
            id: 'list-1',
            name: 'Friends',
            pubkeys: const [_memberAlice],
          ),
        ];
        expect(bloc.state.status, equals(PeopleListsStatus.failure));
        expect(bloc.state.pendingMutations, isEmpty);
        expect(bloc.state.lists, equals(expectedLists));
        expect(
          bloc.state.listIdsByPubkey,
          equals({
            _memberAlice: {'list-1'},
          }),
        );
      },
    );

    blocTest<PeopleListsBloc, PeopleListsState>(
      'restores exact prior lists and reverse index when remove pubkey fails',
      build: buildBloc,
      setUp: () {
        when(
          () => repository.removePubkey(
            ownerPubkey: _ownerA,
            listId: 'list-1',
            pubkey: _memberAlice,
          ),
        ).thenThrow(StateError('relay down'));
      },
      seed: () {
        final priorLists = [
          _buildList(
            id: 'list-1',
            name: 'Friends',
            pubkeys: const [_memberAlice, _memberBob],
          ),
        ];
        return PeopleListsState(
          status: PeopleListsStatus.ready,
          ownerPubkey: _ownerA,
          lists: priorLists,
          listIdsByPubkey: const {
            _memberAlice: {'list-1'},
            _memberBob: {'list-1'},
          },
        );
      },
      errors: () => [isA<StateError>()],
      act: (bloc) => bloc.add(
        const PeopleListsPubkeyRemoveRequested(
          listId: 'list-1',
          pubkey: _memberAlice,
        ),
      ),
      verify: (bloc) {
        final expectedLists = [
          _buildList(
            id: 'list-1',
            name: 'Friends',
            pubkeys: const [_memberAlice, _memberBob],
          ),
        ];
        expect(bloc.state.status, equals(PeopleListsStatus.failure));
        expect(bloc.state.pendingMutations, isEmpty);
        expect(bloc.state.lists, equals(expectedLists));
        expect(
          bloc.state.listIdsByPubkey,
          equals({
            _memberAlice: {'list-1'},
            _memberBob: {'list-1'},
          }),
        );
      },
    );

    blocTest<PeopleListsBloc, PeopleListsState>(
      'emits optimistic state for create list before repository returns',
      build: buildBloc,
      setUp: () {
        when(
          () => repository.createList(
            ownerPubkey: _ownerA,
            name: 'New List',
            initialPubkeys: [_memberAlice],
          ),
        ).thenAnswer(
          (_) async => const PeopleListPublishResult.submitted(
            eventId:
                '3333333333333333333333333333333333333333333333333333333333333333',
          ),
        );
      },
      seed: () => const PeopleListsState(
        status: PeopleListsStatus.ready,
        ownerPubkey: _ownerA,
      ),
      act: (bloc) => bloc.add(
        const PeopleListsCreateRequested(
          name: 'New List',
          initialPubkeys: [_memberAlice],
        ),
      ),
      verify: (bloc) {
        verify(
          () => repository.createList(
            ownerPubkey: _ownerA,
            name: 'New List',
            initialPubkeys: [_memberAlice],
          ),
        ).called(1);
      },
    );

    blocTest<PeopleListsBloc, PeopleListsState>(
      'emits optimistic state for delete list before repository returns',
      build: buildBloc,
      setUp: () {
        when(
          () => repository.deleteList(
            ownerPubkey: _ownerA,
            listId: 'list-1',
          ),
        ).thenAnswer(
          (_) async => const PeopleListPublishResult.submitted(
            eventId:
                '4444444444444444444444444444444444444444444444444444444444444444',
          ),
        );
      },
      seed: () => PeopleListsState(
        status: PeopleListsStatus.ready,
        ownerPubkey: _ownerA,
        lists: [
          _buildList(
            id: 'list-1',
            name: 'Friends',
            pubkeys: const [_memberAlice],
          ),
        ],
        listIdsByPubkey: const {
          _memberAlice: {'list-1'},
        },
      ),
      act: (bloc) => bloc.add(
        const PeopleListsDeleteRequested(listId: 'list-1'),
      ),
      verify: (bloc) {
        verify(
          () => repository.deleteList(
            ownerPubkey: _ownerA,
            listId: 'list-1',
          ),
        ).called(1);
        // Optimistic delete removes the list and any reverse index entries.
        expect(bloc.state.lists, isEmpty);
        expect(bloc.state.listIdsByPubkey, isEmpty);
      },
    );

    blocTest<PeopleListsBloc, PeopleListsState>(
      'reports submitted from repository without claiming relay confirmation',
      build: buildBloc,
      setUp: () {
        when(
          () => repository.addPubkey(
            ownerPubkey: _ownerA,
            listId: 'list-1',
            pubkey: _memberBob,
          ),
        ).thenAnswer(
          (_) async => const PeopleListPublishResult.submitted(
            eventId:
                '5555555555555555555555555555555555555555555555555555555555555555',
          ),
        );
      },
      seed: () => PeopleListsState(
        status: PeopleListsStatus.ready,
        ownerPubkey: _ownerA,
        lists: [
          _buildList(
            id: 'list-1',
            name: 'Friends',
            pubkeys: const [_memberAlice],
          ),
        ],
        listIdsByPubkey: const {
          _memberAlice: {'list-1'},
        },
      ),
      act: (bloc) => bloc.add(
        const PeopleListsPubkeyAddRequested(
          listId: 'list-1',
          pubkey: _memberBob,
        ),
      ),
      verify: (bloc) {
        expect(
          bloc.state.lastSubmittedEventId,
          equals(
            '5555555555555555555555555555555555555555555555555555555555555555',
          ),
        );
        expect(bloc.state.status, equals(PeopleListsStatus.ready));
      },
    );

    blocTest<PeopleListsBloc, PeopleListsState>(
      'ignores duplicate add no-ops',
      build: buildBloc,
      seed: () => PeopleListsState(
        status: PeopleListsStatus.ready,
        ownerPubkey: _ownerA,
        lists: [
          _buildList(
            id: 'list-1',
            name: 'Friends',
            pubkeys: const [_memberAlice],
          ),
        ],
        listIdsByPubkey: const {
          _memberAlice: {'list-1'},
        },
      ),
      act: (bloc) => bloc.add(
        const PeopleListsPubkeyAddRequested(
          listId: 'list-1',
          pubkey: _memberAlice,
        ),
      ),
      verify: (bloc) {
        verifyNever(
          () => repository.addPubkey(
            ownerPubkey: any(named: 'ownerPubkey'),
            listId: any(named: 'listId'),
            pubkey: any(named: 'pubkey'),
          ),
        );
      },
      expect: () => const <PeopleListsState>[],
    );

    blocTest<PeopleListsBloc, PeopleListsState>(
      'ignores duplicate remove no-ops',
      build: buildBloc,
      seed: () => PeopleListsState(
        status: PeopleListsStatus.ready,
        ownerPubkey: _ownerA,
        lists: [
          _buildList(
            id: 'list-1',
            name: 'Friends',
            pubkeys: const [_memberAlice],
          ),
        ],
        listIdsByPubkey: const {
          _memberAlice: {'list-1'},
        },
      ),
      act: (bloc) => bloc.add(
        const PeopleListsPubkeyRemoveRequested(
          listId: 'list-1',
          pubkey: _memberBob,
        ),
      ),
      verify: (bloc) {
        verifyNever(
          () => repository.removePubkey(
            ownerPubkey: any(named: 'ownerPubkey'),
            listId: any(named: 'listId'),
            pubkey: any(named: 'pubkey'),
          ),
        );
      },
      expect: () => const <PeopleListsState>[],
    );

    blocTest<PeopleListsBloc, PeopleListsState>(
      'toggle adds when member is absent and removes when present',
      build: buildBloc,
      setUp: () {
        when(
          () => repository.addPubkey(
            ownerPubkey: _ownerA,
            listId: 'list-1',
            pubkey: _memberBob,
          ),
        ).thenAnswer(
          (_) async => const PeopleListPublishResult.submitted(
            eventId:
                '6666666666666666666666666666666666666666666666666666666666666666',
          ),
        );
        when(
          () => repository.removePubkey(
            ownerPubkey: _ownerA,
            listId: 'list-1',
            pubkey: _memberBob,
          ),
        ).thenAnswer(
          (_) async => const PeopleListPublishResult.submitted(
            eventId:
                '7777777777777777777777777777777777777777777777777777777777777777',
          ),
        );
      },
      seed: () => PeopleListsState(
        status: PeopleListsStatus.ready,
        ownerPubkey: _ownerA,
        lists: [
          _buildList(
            id: 'list-1',
            name: 'Friends',
            pubkeys: const [_memberAlice],
          ),
        ],
        listIdsByPubkey: const {
          _memberAlice: {'list-1'},
        },
      ),
      act: (bloc) async {
        // First toggle: Bob is absent → should add.
        bloc.add(
          const PeopleListsPubkeyToggleRequested(
            listId: 'list-1',
            pubkey: _memberBob,
          ),
        );
        await _flush();
        // Second toggle: Bob is now present → should remove.
        bloc.add(
          const PeopleListsPubkeyToggleRequested(
            listId: 'list-1',
            pubkey: _memberBob,
          ),
        );
        await _flush();
      },
      verify: (bloc) {
        verify(
          () => repository.addPubkey(
            ownerPubkey: _ownerA,
            listId: 'list-1',
            pubkey: _memberBob,
          ),
        ).called(1);
        verify(
          () => repository.removePubkey(
            ownerPubkey: _ownerA,
            listId: 'list-1',
            pubkey: _memberBob,
          ),
        ).called(1);
        // Net result: Bob is absent again.
        expect(
          bloc.state.listIdsByPubkey.containsKey(_memberBob),
          isFalse,
        );
      },
    );

    blocTest<PeopleListsBloc, PeopleListsState>(
      'recovers from sticky failure once pending mutations drain',
      build: buildBloc,
      setUp: () {
        when(
          () => repository.addPubkey(
            ownerPubkey: _ownerA,
            listId: 'list-1',
            pubkey: _memberBob,
          ),
        ).thenThrow(StateError('relay down'));
        when(
          () => repository.removePubkey(
            ownerPubkey: _ownerA,
            listId: 'list-1',
            pubkey: _memberAlice,
          ),
        ).thenAnswer(
          (_) async => const PeopleListPublishResult.submitted(
            eventId:
                '8888888888888888888888888888888888888888888888888888888888888888',
          ),
        );
      },
      seed: () => PeopleListsState(
        status: PeopleListsStatus.ready,
        ownerPubkey: _ownerA,
        lists: [
          _buildList(
            id: 'list-1',
            name: 'Friends',
            pubkeys: const [_memberAlice],
          ),
        ],
        listIdsByPubkey: const {
          _memberAlice: {'list-1'},
        },
      ),
      errors: () => [isA<StateError>()],
      act: (bloc) async {
        // First mutation fails → failure status.
        bloc.add(
          const PeopleListsPubkeyAddRequested(
            listId: 'list-1',
            pubkey: _memberBob,
          ),
        );
        await _flush();
        // Subsequent successful mutation should reset status back to ready.
        bloc.add(
          const PeopleListsPubkeyRemoveRequested(
            listId: 'list-1',
            pubkey: _memberAlice,
          ),
        );
        await _flush();
      },
      verify: (bloc) {
        expect(bloc.state.status, equals(PeopleListsStatus.ready));
        expect(bloc.state.pendingMutations, isEmpty);
      },
    );

    blocTest<PeopleListsBloc, PeopleListsState>(
      'close cancels owner and repository subscriptions',
      build: buildBloc,
      act: (bloc) async {
        bloc.add(const PeopleListsStarted());
        await _flush();
        ownerPubkeyController.add(_ownerA);
        await _flush();
        await bloc.close();
        // Post-close events must not be observed by the closed bloc; if
        // subscriptions leaked, adding events here would throw because
        // the bloc's internal event controller is closed.
        ownerPubkeyController.add(_ownerB);
        ownerAListsController.add(const []);
        await _flush();
      },
      verify: (bloc) {
        expect(ownerPubkeyController.hasListener, isFalse);
        expect(ownerAListsController.hasListener, isFalse);
      },
    );

    test('owner change cancels previous repository subscription', () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);

      bloc.add(const PeopleListsStarted());
      await _flush();

      ownerPubkeyController.add(_ownerA);
      for (var i = 0; i < 5; i++) {
        await _flush();
      }
      expect(
        ownerAListsController.hasListener,
        isTrue,
        reason: 'owner A stream should have been subscribed',
      );

      ownerPubkeyController.add(_ownerB);
      for (var i = 0; i < 5; i++) {
        await _flush();
      }

      expect(ownerAListsController.hasListener, isFalse);
      expect(ownerBListsController.hasListener, isTrue);
    });
  });
}
