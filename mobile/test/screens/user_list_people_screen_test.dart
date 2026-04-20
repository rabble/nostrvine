// ABOUTME: Widget tests for UserListPeopleScreen route-by-id behavior.
// ABOUTME: Verifies BlocSelector reactivity and path constants.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/features/people_lists/people_lists.dart';
import 'package:openvine/screens/user_list_people_screen.dart';

import '../helpers/test_provider_overrides.dart';

class _MockPeopleListsBloc extends MockBloc<PeopleListsEvent, PeopleListsState>
    implements PeopleListsBloc {}

UserList _buildList({
  String id = 'list-1',
  String name = 'Close Friends',
  List<String> pubkeys = const [],
}) {
  final now = DateTime.utc(2025);
  return UserList(
    id: id,
    name: name,
    pubkeys: pubkeys,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group(UserListPeopleScreen, () {
    test('exposes route name and path constants', () {
      expect(UserListPeopleScreen.routeName, equals('people-list-members'));
      expect(UserListPeopleScreen.path, equals('/people-lists/:listId'));
    });

    testWidgets(
      'constructor accepts listId and selects matching list from bloc',
      (tester) async {
        final bloc = _MockPeopleListsBloc();
        final list = _buildList(
          name: 'Selected List',
        );
        whenListen(
          bloc,
          const Stream<PeopleListsState>.empty(),
          initialState: PeopleListsState(
            status: PeopleListsStatus.ready,
            ownerPubkey:
                'f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0',
            lists: [list],
          ),
        );

        await tester.pumpWidget(
          testProviderScope(
            child: MaterialApp(
              home: BlocProvider<PeopleListsBloc>.value(
                value: bloc,
                child: UserListPeopleScreen(listId: list.id),
              ),
            ),
          ),
        );

        await tester.pump();

        expect(find.text('Selected List'), findsOneWidget);
      },
    );

    testWidgets(
      'reacts to bloc emitting updated list without rebuilding the route',
      (tester) async {
        final bloc = _MockPeopleListsBloc();
        final initialList = _buildList(name: 'Old Name');
        final updatedList = _buildList(name: 'New Name');
        final controller = StreamController<PeopleListsState>.broadcast();
        addTearDown(controller.close);

        const ownerPubkey =
            'aa11bb22cc33dd44ee55ff66aa11bb22cc33dd44ee55ff66aa11bb22cc33dd44';

        whenListen(
          bloc,
          controller.stream,
          initialState: PeopleListsState(
            status: PeopleListsStatus.ready,
            ownerPubkey: ownerPubkey,
            lists: [initialList],
          ),
        );

        await tester.pumpWidget(
          testProviderScope(
            child: MaterialApp(
              home: BlocProvider<PeopleListsBloc>.value(
                value: bloc,
                child: UserListPeopleScreen(listId: initialList.id),
              ),
            ),
          ),
        );

        await tester.pump();
        expect(find.text('Old Name'), findsOneWidget);

        // Emit the updated state — the open screen must re-select and
        // show the new name without the route being rebuilt.
        controller.add(
          PeopleListsState(
            status: PeopleListsStatus.ready,
            ownerPubkey: ownerPubkey,
            lists: [updatedList],
          ),
        );
        // Allow the broadcast microtask to propagate to BlocSelector.
        await tester.pump(Duration.zero);
        await tester.pump();

        expect(find.text('New Name'), findsOneWidget);
        expect(find.text('Old Name'), findsNothing);
      },
    );

    testWidgets(
      'renders not-found state when listId is missing from bloc state',
      (tester) async {
        final bloc = _MockPeopleListsBloc();
        whenListen(
          bloc,
          const Stream<PeopleListsState>.empty(),
          initialState: const PeopleListsState(
            status: PeopleListsStatus.ready,
          ),
        );

        await tester.pumpWidget(
          testProviderScope(
            child: MaterialApp(
              home: BlocProvider<PeopleListsBloc>.value(
                value: bloc,
                child: const UserListPeopleScreen(listId: 'missing-id'),
              ),
            ),
          ),
        );

        await tester.pump();

        expect(find.textContaining('List not found'), findsOneWidget);
      },
    );
  });

  group('GoRouter /people-lists/:listId', () {
    testWidgets(
      'route uses handwritten GoRoute and resolves listId path param',
      (tester) async {
        final bloc = _MockPeopleListsBloc();
        final list = _buildList(id: 'routed-list', name: 'Routed List');
        whenListen(
          bloc,
          const Stream<PeopleListsState>.empty(),
          initialState: PeopleListsState(
            status: PeopleListsStatus.ready,
            ownerPubkey:
                'bb11cc22dd33ee44ff55aa66bb11cc22dd33ee44ff55aa66bb11cc22dd33ee44',
            lists: [list],
          ),
        );

        final router = GoRouter(
          initialLocation: '/people-lists/${Uri.encodeComponent(list.id)}',
          routes: [
            GoRoute(
              path: UserListPeopleScreen.path,
              name: UserListPeopleScreen.routeName,
              builder: (context, state) {
                final listId = state.pathParameters['listId'];
                if (listId == null || listId.isEmpty) {
                  return const Scaffold(
                    body: Center(child: Text('Invalid list')),
                  );
                }
                return UserListPeopleScreen(listId: listId);
              },
            ),
          ],
        );

        await tester.pumpWidget(
          testProviderScope(
            child: BlocProvider<PeopleListsBloc>.value(
              value: bloc,
              child: MaterialApp.router(routerConfig: router),
            ),
          ),
        );

        await tester.pump();

        expect(find.byType(UserListPeopleScreen), findsOneWidget);
        expect(find.text('Routed List'), findsOneWidget);
      },
    );

    testWidgets(
      'route falls back to invalid-list scaffold for empty listId',
      (tester) async {
        final bloc = _MockPeopleListsBloc();
        whenListen(
          bloc,
          const Stream<PeopleListsState>.empty(),
          initialState: const PeopleListsState(),
        );

        final router = GoRouter(
          initialLocation: '/people-lists/',
          routes: [
            // Matches empty listId by design — builder guards.
            GoRoute(
              path: '/people-lists/:listId',
              builder: (context, state) {
                final listId = state.pathParameters['listId'] ?? '';
                if (listId.isEmpty) {
                  return const Scaffold(
                    body: Center(child: Text('Invalid list')),
                  );
                }
                return UserListPeopleScreen(listId: listId);
              },
            ),
          ],
          errorBuilder: (context, state) => const Scaffold(
            body: Center(child: Text('Invalid list')),
          ),
        );

        await tester.pumpWidget(
          testProviderScope(
            child: BlocProvider<PeopleListsBloc>.value(
              value: bloc,
              child: MaterialApp.router(routerConfig: router),
            ),
          ),
        );

        await tester.pump();

        expect(find.text('Invalid list'), findsOneWidget);
        expect(find.byType(UserListPeopleScreen), findsNothing);
      },
    );
  });

  setUpAll(() {
    registerFallbackValue(const PeopleListsStarted());
  });
}
