import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/list_search/list_search_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/screens/search_results/widgets/lists_section.dart';
import 'package:openvine/screens/search_results/widgets/search_section_empty_state.dart';
import 'package:openvine/screens/search_results/widgets/search_section_error_state.dart';
import 'package:openvine/screens/search_results/widgets/section_header.dart';
import 'package:openvine/widgets/people_list_search_card.dart';
import 'package:people_lists_repository/people_lists_repository.dart';

class _MockListSearchBloc extends MockBloc<ListSearchEvent, ListSearchState>
    implements ListSearchBloc {}

// Full-length 64-char Nostr pubkeys — never truncate.
const String _ownerA =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const String _authorOne =
    '1111111111111111111111111111111111111111111111111111111111111111';
const String _memberOne =
    '2222222222222222222222222222222222222222222222222222222222222222';
const String _memberTwo =
    '3333333333333333333333333333333333333333333333333333333333333333';

void main() {
  group(ListsSection, () {
    late _MockListSearchBloc mockBloc;

    final now = DateTime(2024, 6, 15);
    final testList = CuratedList(
      id: 'cl1',
      name: 'Top Videos',
      pubkey: _authorOne,
      videoEventIds: const ['vid1'],
      createdAt: now,
      updatedAt: now,
    );

    final testUserList = UserList(
      id: 'friends',
      name: 'Friends',
      pubkeys: const [_memberOne, _memberTwo],
      createdAt: now,
      updatedAt: now,
    );

    final testPeopleResult = PeopleListSearchResult(
      ownerPubkey: _ownerA,
      list: testUserList,
    );

    setUp(() {
      mockBloc = _MockListSearchBloc();
    });

    tearDown(() {
      mockBloc.close();
    });

    Widget buildSubject({bool showAll = false}) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BlocProvider<ListSearchBloc>.value(
            value: mockBloc,
            child: CustomScrollView(slivers: [ListsSection(showAll: showAll)]),
          ),
        ),
      );
    }

    group('showAll: false (All tab preview)', () {
      testWidgets('hides entirely when success with empty results', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          const ListSearchState(
            status: ListSearchStatus.success,
            query: 'test',
          ),
        );

        await tester.pumpWidget(buildSubject());

        expect(find.byType(SectionHeader), findsNothing);
        expect(find.byType(SearchSectionEmptyState), findsNothing);
      });

      testWidgets('renders header and content when success with results', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          ListSearchState(
            status: ListSearchStatus.success,
            query: 'test',
            videoResults: [testList],
          ),
        );

        await tester.pumpWidget(buildSubject());

        expect(find.byType(SectionHeader), findsOneWidget);
        expect(find.text('Lists'), findsOneWidget);
      });

      testWidgets('renders $SearchSectionErrorState on failure', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          const ListSearchState(
            status: ListSearchStatus.failure,
            query: 'test',
          ),
        );

        await tester.pumpWidget(buildSubject());

        expect(find.byType(SearchSectionErrorState), findsOneWidget);
      });
    });

    group('showAll: true (dedicated tab)', () {
      testWidgets(
        'renders $SearchSectionEmptyState when success with empty results',
        (tester) async {
          when(() => mockBloc.state).thenReturn(
            const ListSearchState(
              status: ListSearchStatus.success,
              query: 'test',
            ),
          );

          await tester.pumpWidget(buildSubject(showAll: true));

          expect(find.byType(SearchSectionEmptyState), findsOneWidget);
        },
      );

      testWidgets(
        'renders $SearchSectionErrorState on failure',
        (tester) async {
          when(() => mockBloc.state).thenReturn(
            const ListSearchState(
              status: ListSearchStatus.failure,
              query: 'test',
            ),
          );

          await tester.pumpWidget(buildSubject(showAll: true));

          expect(find.byType(SearchSectionErrorState), findsOneWidget);
        },
      );

      testWidgets(
        'renders $PeopleListSearchCard for each people result',
        (tester) async {
          tester.view.physicalSize = const Size(400, 800);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);

          when(() => mockBloc.state).thenReturn(
            ListSearchState(
              status: ListSearchStatus.success,
              query: 'friends',
              peopleResults: [testPeopleResult],
            ),
          );

          await tester.pumpWidget(buildSubject(showAll: true));

          expect(find.byType(PeopleListSearchCard), findsWidgets);
        },
      );

      testWidgets(
        'tapping a public people-list card does not push a people-lists route',
        (tester) async {
          tester.view.physicalSize = const Size(400, 800);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);

          when(() => mockBloc.state).thenReturn(
            ListSearchState(
              status: ListSearchStatus.success,
              query: 'friends',
              peopleResults: [testPeopleResult],
            ),
          );

          final pushedLocations = <String>[];
          await tester.pumpWidget(
            MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: BlocProvider<ListSearchBloc>.value(
                  value: mockBloc,
                  child: const CustomScrollView(
                    slivers: [ListsSection(showAll: true)],
                  ),
                ),
              ),
              onGenerateRoute: (settings) {
                pushedLocations.add(settings.name ?? '');
                return MaterialPageRoute<void>(
                  builder: (_) => const SizedBox.shrink(),
                  settings: settings,
                );
              },
            ),
          );

          // Invoke onTap directly: layout-level avatar rendering is not the
          // subject under test here.
          final card = tester
              .widgetList<PeopleListSearchCard>(
                find.byType(PeopleListSearchCard),
              )
              .first;
          card.onTap();
          await tester.pump();

          expect(
            pushedLocations.where((l) => l.startsWith('/people-lists/')),
            isEmpty,
          );
        },
      );
    });

    testWidgets('retry dispatches $ListSearchQueryChanged with current query', (
      tester,
    ) async {
      when(() => mockBloc.state).thenReturn(
        const ListSearchState(
          status: ListSearchStatus.failure,
          query: 'retry-test',
        ),
      );

      await tester.pumpWidget(buildSubject());
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      verify(
        () => mockBloc.add(const ListSearchQueryChanged('retry-test')),
      ).called(1);
    });
  });
}
