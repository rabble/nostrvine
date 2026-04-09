import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/user_search/user_search_bloc.dart';
import 'package:openvine/screens/search_results/widgets/people_section.dart';
import 'package:openvine/screens/search_results/widgets/search_section_empty_state.dart';
import 'package:openvine/screens/search_results/widgets/search_section_error_state.dart';
import 'package:openvine/screens/search_results/widgets/section_header.dart';

class _MockUserSearchBloc extends MockBloc<UserSearchEvent, UserSearchState>
    implements UserSearchBloc {}

void main() {
  group(PeopleSection, () {
    late _MockUserSearchBloc mockBloc;

    final testProfile = UserProfile(
      pubkey:
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      name: 'Test User',
      rawData: const <String, dynamic>{},
      createdAt: DateTime(2024),
      eventId: 'event1',
    );

    setUp(() {
      mockBloc = _MockUserSearchBloc();
    });

    tearDown(() {
      mockBloc.close();
    });

    Widget buildSubject({bool showAll = false}) {
      return MaterialApp(
        home: Scaffold(
          body: BlocProvider<UserSearchBloc>.value(
            value: mockBloc,
            child: CustomScrollView(
              slivers: [PeopleSection(showAll: showAll)],
            ),
          ),
        ),
      );
    }

    group('showAll: false (All tab preview)', () {
      testWidgets(
        'hides entirely when success with empty results',
        (tester) async {
          when(() => mockBloc.state).thenReturn(
            const UserSearchState(
              status: UserSearchStatus.success,
              query: 'test',
            ),
          );

          await tester.pumpWidget(buildSubject());

          expect(find.byType(SectionHeader), findsNothing);
          expect(find.byType(SearchSectionEmptyState), findsNothing);
        },
      );

      testWidgets(
        'renders header and content when success with results',
        (tester) async {
          when(() => mockBloc.state).thenReturn(
            UserSearchState(
              status: UserSearchStatus.success,
              query: 'test',
              results: [testProfile],
            ),
          );

          await tester.pumpWidget(buildSubject());

          expect(find.byType(SectionHeader), findsOneWidget);
          expect(find.text('People'), findsOneWidget);
        },
      );

      testWidgets(
        'renders $SearchSectionErrorState on failure',
        (tester) async {
          when(() => mockBloc.state).thenReturn(
            const UserSearchState(
              status: UserSearchStatus.failure,
              query: 'test',
            ),
          );

          await tester.pumpWidget(buildSubject());

          expect(find.byType(SearchSectionErrorState), findsOneWidget);
        },
      );
    });

    group('showAll: true (dedicated tab)', () {
      testWidgets(
        'renders $SearchSectionEmptyState when success with empty results',
        (tester) async {
          when(() => mockBloc.state).thenReturn(
            const UserSearchState(
              status: UserSearchStatus.success,
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
            const UserSearchState(
              status: UserSearchStatus.failure,
              query: 'test',
            ),
          );

          await tester.pumpWidget(buildSubject(showAll: true));

          expect(find.byType(SearchSectionErrorState), findsOneWidget);
        },
      );
    });

    testWidgets(
      'retry dispatches $UserSearchQueryChanged with current query',
      (tester) async {
        when(() => mockBloc.state).thenReturn(
          const UserSearchState(
            status: UserSearchStatus.failure,
            query: 'retry-test',
          ),
        );

        await tester.pumpWidget(buildSubject());
        await tester.tap(find.text('Try again'));
        await tester.pumpAndSettle();

        verify(
          () => mockBloc.add(const UserSearchQueryChanged('retry-test')),
        ).called(1);
      },
    );
  });
}
