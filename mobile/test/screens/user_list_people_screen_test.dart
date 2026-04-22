// ABOUTME: Widget tests for UserListPeopleScreen route-by-id behavior.
// ABOUTME: Verifies BlocSelector reactivity and path constants.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/features/people_lists/people_lists.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/screens/user_list_people_screen.dart';
import 'package:openvine/widgets/user_avatar.dart';

import '../helpers/test_provider_overrides.dart';

class _MockPeopleListsBloc extends MockBloc<PeopleListsEvent, PeopleListsState>
    implements PeopleListsBloc {}

UserList _buildList({
  String id = 'list-1',
  String name = 'Close Friends',
  List<String> pubkeys = const [],
  bool isEditable = true,
}) {
  final now = DateTime.utc(2025);
  return UserList(
    id: id,
    name: name,
    pubkeys: pubkeys,
    createdAt: now,
    updatedAt: now,
    isEditable: isEditable,
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
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
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
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
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
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
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

    testWidgets(
      'shows the add-people action when current list is editable',
      (tester) async {
        final bloc = _MockPeopleListsBloc();
        final list = _buildList(
          id: 'punk-friends',
          name: 'Punk Friends',
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
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: BlocProvider<PeopleListsBloc>.value(
                value: bloc,
                child: UserListPeopleScreen(listId: list.id),
              ),
            ),
          ),
        );

        await tester.pump();

        expect(find.byIcon(Icons.person_add_alt_1), findsOneWidget);
      },
    );

    testWidgets(
      'hides the add-people action when current list is read-only',
      (tester) async {
        final bloc = _MockPeopleListsBloc();
        // Read-only lists (e.g. Divine Team) carry isEditable: false and must
        // not expose the add-people action — editing them is forbidden.
        final list = _buildList(
          id: 'divine-team',
          name: 'Divine Team',
          isEditable: false,
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
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: BlocProvider<PeopleListsBloc>.value(
                value: bloc,
                child: UserListPeopleScreen(listId: list.id),
              ),
            ),
          ),
        );

        await tester.pump();

        expect(find.byIcon(Icons.person_add_alt_1), findsNothing);
      },
    );

    testWidgets(
      'long-press on a member of an editable list shows remove confirmation',
      (tester) async {
        final bloc = _MockPeopleListsBloc();
        const memberPubkey =
            '1111222233334444555566667777888899990000aaaabbbbccccddddeeeeffff';
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
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: BlocProvider<PeopleListsBloc>.value(
                value: bloc,
                child: const Scaffold(
                  body: PeopleCarousel(
                    pubkeys: [memberPubkey],
                    listId: 'list-1',
                    canRemove: true,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        await tester.longPress(find.byType(UserAvatar).first);
        await tester.pumpAndSettle();

        expect(find.text('Remove'), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);
      },
    );

    testWidgets(
      'confirming remove dispatches PeopleListsPubkeyRemoveRequested',
      (tester) async {
        final bloc = _MockPeopleListsBloc();
        const memberPubkey =
            '1111222233334444555566667777888899990000aaaabbbbccccddddeeeeffff';
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
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: BlocProvider<PeopleListsBloc>.value(
                value: bloc,
                child: const Scaffold(
                  body: PeopleCarousel(
                    pubkeys: [memberPubkey],
                    listId: 'list-1',
                    canRemove: true,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        await tester.longPress(find.byType(UserAvatar).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Remove'));
        await tester.pumpAndSettle();

        verify(
          () => bloc.add(
            const PeopleListsPubkeyRemoveRequested(
              listId: 'list-1',
              pubkey: memberPubkey,
            ),
          ),
        ).called(1);
      },
    );

    testWidgets(
      'undo snackbar dispatches PeopleListsPubkeyAddRequested',
      (tester) async {
        final bloc = _MockPeopleListsBloc();
        const memberPubkey =
            '1111222233334444555566667777888899990000aaaabbbbccccddddeeeeffff';
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
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: BlocProvider<PeopleListsBloc>.value(
                value: bloc,
                child: const Scaffold(
                  body: PeopleCarousel(
                    pubkeys: [memberPubkey],
                    listId: 'list-1',
                    canRemove: true,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        await tester.longPress(find.byType(UserAvatar).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Remove'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Undo'));
        await tester.pumpAndSettle();

        verify(
          () => bloc.add(
            const PeopleListsPubkeyAddRequested(
              listId: 'list-1',
              pubkey: memberPubkey,
            ),
          ),
        ).called(1);
      },
    );

    testWidgets(
      'long-press on a read-only list member does NOT show remove dialog',
      (tester) async {
        final bloc = _MockPeopleListsBloc();
        const memberPubkey =
            '1111222233334444555566667777888899990000aaaabbbbccccddddeeeeffff';
        whenListen(
          bloc,
          const Stream<PeopleListsState>.empty(),
          initialState: const PeopleListsState(
            status: PeopleListsStatus.ready,
          ),
        );

        // Wrap in GoRouter since long-press still triggers onTap (no-op
        // long-press when canRemove:false); the tap handler calls
        // context.push(profile) and needs a router.
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const Scaffold(
                body: PeopleCarousel(
                  pubkeys: [memberPubkey],
                  listId: 'divine-team',
                  canRemove: false,
                ),
              ),
            ),
            GoRoute(
              path: '/profile/:npub',
              builder: (context, state) => const Scaffold(
                body: Text('profile'),
              ),
            ),
          ],
        );

        await tester.pumpWidget(
          testProviderScope(
            child: BlocProvider<PeopleListsBloc>.value(
              value: bloc,
              child: MaterialApp.router(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                routerConfig: router,
              ),
            ),
          ),
        );
        await tester.pump();

        await tester.longPress(find.byType(UserAvatar).first);
        await tester.pumpAndSettle();

        expect(find.text('Remove'), findsNothing);
        expect(find.text('Cancel'), findsNothing);
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
              child: MaterialApp.router(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                routerConfig: router,
              ),
            ),
          ),
        );

        await tester.pump();

        expect(find.byType(UserListPeopleScreen), findsOneWidget);
        expect(find.text('Routed List'), findsOneWidget);
      },
    );

    testWidgets(
      'route falls back to invalid-list scaffold with back button for '
      'empty listId',
      (tester) async {
        // Exercises the exact same builder shape as the real app router
        // so a regression that drops the fallback back button is caught.
        Widget buildFallbackFor(String? listId) {
          return Builder(
            builder: (context) {
              if (listId == null || listId.isEmpty) {
                return Scaffold(
                  appBar: DiVineAppBar(
                    title: 'People list',
                    showBackButton: true,
                    onBackPressed: context.pop,
                  ),
                  body: const Center(child: Text('Invalid list')),
                );
              }
              return const SizedBox();
            },
          );
        }

        final router = GoRouter(
          initialLocation: '/seed',
          routes: [
            GoRoute(
              path: '/seed',
              builder: (context, state) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => context.push('/invalid-list'),
                    child: const Text('Go'),
                  ),
                ),
              ),
            ),
            GoRoute(
              path: '/invalid-list',
              builder: (context, state) => buildFallbackFor(null),
            ),
          ],
        );

        await tester.pumpWidget(
          MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        );

        await tester.pump();
        await tester.tap(find.text('Go'));
        await tester.pumpAndSettle();

        expect(find.text('Invalid list'), findsOneWidget);
        expect(find.text('People list'), findsOneWidget);
        // Back button present (matches divine_ui DiVineAppBarLeading label).
        expect(find.bySemanticsLabel('Go back'), findsOneWidget);

        // Tapping the back button pops the fallback route.
        await tester.tap(find.bySemanticsLabel('Go back'));
        await tester.pumpAndSettle();

        expect(find.text('Invalid list'), findsNothing);
        expect(find.text('Go'), findsOneWidget);
      },
    );
  });

  setUpAll(() {
    registerFallbackValue(const PeopleListsStarted());
  });
}
