// ABOUTME: Widget tests for AddPeopleToListScreen full-screen picker.
// ABOUTME: Covers selection, disabled-already-member rows, and batch-add dispatch.

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/features/people_lists/bloc/people_lists_bloc.dart';
import 'package:openvine/features/people_lists/view/add_people_to_list_screen.dart';
import 'package:openvine/features/people_lists/view/widgets/person_pickable_row.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';

class _MockPeopleListsBloc extends MockBloc<PeopleListsEvent, PeopleListsState>
    implements PeopleListsBloc {}

// Full-length Nostr pubkeys — never truncate.
const String _ownerPubkey =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const String _candidateA =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const String _candidateB =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
const String _candidateC =
    'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';

final DateTime _frozenNow = DateTime.utc(2026, 4, 20, 12);

UserList _buildList({
  required String id,
  required String name,
  List<String> pubkeys = const [],
  bool isEditable = true,
}) {
  return UserList(
    id: id,
    name: name,
    pubkeys: pubkeys,
    createdAt: _frozenNow,
    updatedAt: _frozenNow,
    isEditable: isEditable,
  );
}

PeopleListsState _stateWith({required List<UserList> lists}) {
  final reverseIndex = <String, Set<String>>{};
  for (final list in lists) {
    for (final pk in list.pubkeys) {
      (reverseIndex[pk] ??= <String>{}).add(list.id);
    }
  }
  return PeopleListsState(
    status: PeopleListsStatus.ready,
    ownerPubkey: _ownerPubkey,
    lists: lists,
    listIdsByPubkey: reverseIndex,
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(
      const PeopleListsPubkeyAddRequested(
        listId: 'fallback',
        pubkey:
            '0000000000000000000000000000000000000000000000000000000000000000',
      ),
    );
  });

  group(AddPeopleToListScreen, () {
    late _MockPeopleListsBloc bloc;

    setUp(() {
      bloc = _MockPeopleListsBloc();
    });

    tearDown(() async {
      await bloc.close();
    });

    Widget buildSubject({
      required String listId,
      List<String> candidatePubkeys = const [],
    }) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<PeopleListsBloc>.value(
          value: bloc,
          child: AddPeopleToListScreen(
            listId: listId,
            candidatePubkeys: candidatePubkeys,
          ),
        ),
      );
    }

    test('exposes route name and path constants', () {
      expect(
        AddPeopleToListScreen.routeName,
        equals('people-list-add-people'),
      );
      expect(
        AddPeopleToListScreen.path,
        equals('/people-lists/:listId/add-people'),
      );
    });

    testWidgets(
      'renders a row for each candidate pubkey',
      (tester) async {
        final list = _buildList(id: 'list-1', name: 'Close Friends');
        when(() => bloc.state).thenReturn(_stateWith(lists: [list]));

        await tester.pumpWidget(
          buildSubject(
            listId: list.id,
            candidatePubkeys: const [_candidateA, _candidateB, _candidateC],
          ),
        );

        expect(find.byType(PersonPickableRow), findsNWidgets(3));
      },
    );

    testWidgets(
      'disables rows for candidates that are already members of the list',
      (tester) async {
        final list = _buildList(
          id: 'list-1',
          name: 'Close Friends',
          pubkeys: [_candidateA],
        );
        when(() => bloc.state).thenReturn(_stateWith(lists: [list]));

        await tester.pumpWidget(
          buildSubject(
            listId: list.id,
            candidatePubkeys: const [_candidateA, _candidateB],
          ),
        );

        final rows = tester
            .widgetList<PersonPickableRow>(find.byType(PersonPickableRow))
            .toList();
        // First candidate is already a member → disabled + pre-selected.
        expect(rows[0].enabled, isFalse);
        expect(rows[0].isSelected, isTrue);
        // Second candidate is selectable.
        expect(rows[1].enabled, isTrue);
        expect(rows[1].isSelected, isFalse);
      },
    );

    testWidgets(
      'Add button is disabled while no candidates are selected',
      (tester) async {
        final list = _buildList(id: 'list-1', name: 'Close Friends');
        when(() => bloc.state).thenReturn(_stateWith(lists: [list]));

        await tester.pumpWidget(
          buildSubject(
            listId: list.id,
            candidatePubkeys: const [_candidateA],
          ),
        );

        final addButton = tester.widget<DivineButton>(
          find.widgetWithText(DivineButton, 'Add'),
        );
        expect(addButton.onPressed, isNull);
      },
    );

    testWidgets(
      'tapping a candidate row selects it and enables the Add button',
      (tester) async {
        final list = _buildList(id: 'list-1', name: 'Close Friends');
        when(() => bloc.state).thenReturn(_stateWith(lists: [list]));

        await tester.pumpWidget(
          buildSubject(
            listId: list.id,
            candidatePubkeys: const [_candidateA, _candidateB],
          ),
        );

        await tester.tap(find.byType(PersonPickableRow).first);
        await tester.pump();

        // Button label includes the count once a selection is made.
        expect(find.widgetWithText(DivineButton, 'Add 1'), findsOneWidget);
        final addButton = tester.widget<DivineButton>(
          find.widgetWithText(DivineButton, 'Add 1'),
        );
        expect(addButton.onPressed, isNotNull);
      },
    );

    testWidgets(
      'tapping Add dispatches $PeopleListsPubkeyAddRequested for each '
      'selected pubkey with full pubkeys',
      (tester) async {
        final list = _buildList(id: 'list-42', name: 'Close Friends');
        when(() => bloc.state).thenReturn(_stateWith(lists: [list]));

        await tester.pumpWidget(
          buildSubject(
            listId: list.id,
            candidatePubkeys: const [_candidateA, _candidateB, _candidateC],
          ),
        );

        // Select candidates A and C.
        await tester.tap(find.byType(PersonPickableRow).at(0));
        await tester.pump();
        await tester.tap(find.byType(PersonPickableRow).at(2));
        await tester.pump();

        await tester.tap(find.widgetWithText(DivineButton, 'Add 2'));
        await tester.pump();

        verify(
          () => bloc.add(
            const PeopleListsPubkeyAddRequested(
              listId: 'list-42',
              pubkey: _candidateA,
            ),
          ),
        ).called(1);
        verify(
          () => bloc.add(
            const PeopleListsPubkeyAddRequested(
              listId: 'list-42',
              pubkey: _candidateC,
            ),
          ),
        ).called(1);
        verifyNever(
          () => bloc.add(
            const PeopleListsPubkeyAddRequested(
              listId: 'list-42',
              pubkey: _candidateB,
            ),
          ),
        );
      },
    );

    testWidgets(
      'renders fallback scaffold when the list is missing from bloc state',
      (tester) async {
        when(() => bloc.state).thenReturn(_stateWith(lists: const []));

        await tester.pumpWidget(
          buildSubject(
            listId: 'missing-id',
            candidatePubkeys: const [_candidateA],
          ),
        );

        expect(find.textContaining('List not found'), findsOneWidget);
        // Candidate rows are not shown when the list is missing.
        expect(find.byType(PersonPickableRow), findsNothing);
      },
    );
  });

  group('GoRouter /people-lists/:listId/add-people', () {
    testWidgets(
      'route opens the full-screen picker using handwritten $GoRoute',
      (tester) async {
        final bloc = _MockPeopleListsBloc();
        addTearDown(() async => bloc.close());
        final list = _buildList(id: 'routed-list', name: 'Routed');
        when(() => bloc.state).thenReturn(_stateWith(lists: [list]));

        final router = GoRouter(
          initialLocation:
              '/people-lists/${Uri.encodeComponent(list.id)}/add-people',
          routes: [
            GoRoute(
              path: AddPeopleToListScreen.path,
              name: AddPeopleToListScreen.routeName,
              builder: (context, state) {
                final listId = state.pathParameters['listId'];
                if (listId == null || listId.isEmpty) {
                  return const Scaffold(
                    body: Center(child: Text('Invalid list')),
                  );
                }
                return AddPeopleToListScreen(listId: listId);
              },
            ),
          ],
        );

        await tester.pumpWidget(
          BlocProvider<PeopleListsBloc>.value(
            value: bloc,
            child: MaterialApp.router(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              routerConfig: router,
            ),
          ),
        );

        await tester.pump();

        expect(find.byType(AddPeopleToListScreen), findsOneWidget);
      },
    );
  });
}
