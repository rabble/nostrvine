// ABOUTME: Widget tests for AddToPeopleListsSheet.
// ABOUTME: Covers list filtering, empty state, and toggle dispatching.

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/features/people_lists/bloc/people_lists_bloc.dart';
import 'package:openvine/features/people_lists/models/people_list_entry_point.dart';
import 'package:openvine/features/people_lists/view/add_to_people_lists_sheet.dart';
import 'package:openvine/features/people_lists/view/create_people_list_page.dart';
import 'package:openvine/features/people_lists/view/widgets/people_list_row.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';

class _MockPeopleListsBloc extends MockBloc<PeopleListsEvent, PeopleListsState>
    implements PeopleListsBloc {}

// Full-length Nostr pubkeys — never truncate.
const String _ownerPubkey =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const String _targetPubkey =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

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
      const PeopleListsPubkeyToggleRequested(
        listId: 'fallback',
        pubkey:
            '0000000000000000000000000000000000000000000000000000000000000000',
      ),
    );
  });

  group(AddToPeopleListsSheet, () {
    late _MockPeopleListsBloc bloc;

    setUp(() {
      bloc = _MockPeopleListsBloc();
    });

    tearDown(() async {
      await bloc.close();
    });

    Widget buildSubject({
      required String pubkey,
      PeopleListEntryPoint entryPoint = PeopleListEntryPoint.shareMenu,
    }) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BlocProvider<PeopleListsBloc>.value(
            value: bloc,
            child: AddToPeopleListsSheet(
              pubkey: pubkey,
              entryPoint: entryPoint,
            ),
          ),
        ),
      );
    }

    group('renders', () {
      testWidgets(
        'shows only editable lists and filters read-only lists out',
        (tester) async {
          final editable = _buildList(id: 'list-1', name: 'Close Friends');
          final readOnly = _buildList(
            id: 'list-2',
            name: 'Divine Team',
            isEditable: false,
          );
          when(() => bloc.state).thenReturn(
            _stateWith(lists: [editable, readOnly]),
          );

          await tester.pumpWidget(
            buildSubject(pubkey: _targetPubkey),
          );

          expect(find.text('Close Friends'), findsOneWidget);
          expect(find.text('Divine Team'), findsNothing);
          expect(find.byType(PeopleListRow), findsOneWidget);
        },
      );

      testWidgets(
        'selected row is checked when target pubkey is already in the list',
        (tester) async {
          final memberList = _buildList(
            id: 'list-1',
            name: 'Close Friends',
            pubkeys: [_targetPubkey],
          );
          final nonMemberList = _buildList(id: 'list-2', name: 'Work');
          when(() => bloc.state).thenReturn(
            _stateWith(lists: [memberList, nonMemberList]),
          );

          await tester.pumpWidget(
            buildSubject(pubkey: _targetPubkey),
          );

          final checkboxes = tester
              .widgetList<DivineSpriteCheckbox>(
                find.byType(DivineSpriteCheckbox),
              )
              .toList();
          expect(checkboxes, hasLength(2));
          // Sheet renders lists in the bloc's declared order; first list
          // contains the target pubkey so its checkbox is selected.
          expect(
            checkboxes[0].state,
            equals(DivineCheckboxState.selected),
          );
          expect(
            checkboxes[1].state,
            equals(DivineCheckboxState.unselected),
          );
        },
      );
    });

    group('interactions', () {
      testWidgets(
        'tapping a row dispatches $PeopleListsPubkeyToggleRequested with '
        'the target list id and full pubkey',
        (tester) async {
          final list = _buildList(id: 'list-42', name: 'Close Friends');
          when(() => bloc.state).thenReturn(_stateWith(lists: [list]));

          await tester.pumpWidget(
            buildSubject(pubkey: _targetPubkey),
          );

          await tester.tap(find.byType(PeopleListRow));
          await tester.pump();

          verify(
            () => bloc.add(
              const PeopleListsPubkeyToggleRequested(
                listId: 'list-42',
                pubkey: _targetPubkey,
              ),
            ),
          ).called(1);
        },
      );
    });

    group('empty state', () {
      testWidgets(
        'offers a Create list action when there are no editable lists',
        (tester) async {
          when(() => bloc.state).thenReturn(_stateWith(lists: const []));

          await tester.pumpWidget(
            buildSubject(pubkey: _targetPubkey),
          );

          expect(find.text('No lists yet'), findsOneWidget);
          expect(find.byType(DivineButton), findsOneWidget);
          final button = tester.widget<DivineButton>(
            find.byType(DivineButton),
          );
          expect(button.label, equals('Create list'));
          expect(button.onPressed, isNotNull);
        },
      );

      testWidgets(
        'ignores read-only lists when deciding whether the empty state is '
        'shown',
        (tester) async {
          final readOnly = _buildList(
            id: 'list-2',
            name: 'Divine Team',
            isEditable: false,
          );
          when(() => bloc.state).thenReturn(_stateWith(lists: [readOnly]));

          await tester.pumpWidget(
            buildSubject(pubkey: _targetPubkey),
          );

          expect(find.text('No lists yet'), findsOneWidget);
          expect(find.byType(DivineButton), findsOneWidget);
        },
      );

      testWidgets(
        'Create list empty-state button navigates to /people-lists/new '
        'with the untruncated target pubkey as a query param, and pops '
        'the sheet',
        (tester) async {
          when(() => bloc.state).thenReturn(_stateWith(lists: const []));

          // Build a GoRouter with two routes: a launcher that opens the
          // sheet, and the create page itself. The sheet must capture the
          // router before popping so the push still navigates after pop.
          final router = GoRouter(
            initialLocation: '/launcher',
            routes: [
              GoRoute(
                path: '/launcher',
                builder: (context, state) => Scaffold(
                  body: Builder(
                    builder: (innerContext) => ElevatedButton(
                      onPressed: () => AddToPeopleListsSheet.show(
                        innerContext,
                        pubkey: _targetPubkey,
                        entryPoint: PeopleListEntryPoint.shareMenu,
                      ),
                      child: const Text('open'),
                    ),
                  ),
                ),
              ),
              GoRoute(
                path: CreatePeopleListPage.path,
                name: CreatePeopleListPage.routeName,
                builder: (context, state) => CreatePeopleListPage(
                  initialPubkey: state.uri.queryParameters['initialPubkey'],
                ),
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

          await tester.tap(find.text('open'));
          await tester.pumpAndSettle();

          // The empty-state Create button lives in the modal sheet.
          await tester.tap(find.widgetWithText(DivineButton, 'Create list'));
          await tester.pumpAndSettle();

          // Sheet popped.
          expect(find.byType(AddToPeopleListsSheet), findsNothing);
          // Create page opened with the pubkey threaded through.
          expect(find.byType(CreatePeopleListPage), findsOneWidget);
          final page = tester.widget<CreatePeopleListPage>(
            find.byType(CreatePeopleListPage),
          );
          // Full untruncated pubkey — the URL-level contract is that
          // the query param carries the exact hex pubkey so the route
          // is reloadable from the URL alone.
          expect(page.initialPubkey, equals(_targetPubkey));
        },
      );
    });

    group('theming', () {
      testWidgets('renders inside $VineBottomSheet when shown as a modal', (
        tester,
      ) async {
        final list = _buildList(id: 'list-1', name: 'Close Friends');
        when(() => bloc.state).thenReturn(_stateWith(lists: [list]));

        // BlocProvider must sit above the navigator so the bloc is
        // reachable from the modal route. Wrapping the MaterialApp does
        // this because MaterialApp builds the root Navigator below it.
        await tester.pumpWidget(
          BlocProvider<PeopleListsBloc>.value(
            value: bloc,
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: Builder(
                  builder: (context) {
                    return ElevatedButton(
                      onPressed: () => AddToPeopleListsSheet.show(
                        context,
                        pubkey: _targetPubkey,
                        entryPoint: PeopleListEntryPoint.shareMenu,
                      ),
                      child: const Text('open'),
                    );
                  },
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        expect(find.byType(VineBottomSheet), findsOneWidget);
        expect(find.byType(AddToPeopleListsSheet), findsOneWidget);
      });
    });
  });
}
