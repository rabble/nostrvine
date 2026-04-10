import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/hashtag_search/hashtag_search_bloc.dart';
import 'package:openvine/screens/search_results/widgets/search_section_empty_state.dart';
import 'package:openvine/screens/search_results/widgets/search_section_error_state.dart';
import 'package:openvine/screens/search_results/widgets/section_header.dart';
import 'package:openvine/screens/search_results/widgets/tags_section.dart';

class _MockHashtagSearchBloc
    extends MockBloc<HashtagSearchEvent, HashtagSearchState>
    implements HashtagSearchBloc {}

void main() {
  group(TagsSection, () {
    late _MockHashtagSearchBloc mockBloc;

    setUp(() {
      mockBloc = _MockHashtagSearchBloc();
    });

    tearDown(() {
      mockBloc.close();
    });

    Widget buildSubject({bool showAll = false}) {
      return MaterialApp(
        home: Scaffold(
          body: BlocProvider<HashtagSearchBloc>.value(
            value: mockBloc,
            child: CustomScrollView(
              slivers: [TagsSection(showAll: showAll)],
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
            const HashtagSearchState(
              status: HashtagSearchStatus.success,
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
            const HashtagSearchState(
              status: HashtagSearchStatus.success,
              query: 'test',
              results: ['flutter', 'dart'],
            ),
          );

          await tester.pumpWidget(buildSubject());

          expect(find.byType(SectionHeader), findsOneWidget);
          expect(find.text('Tags'), findsOneWidget);
        },
      );

      testWidgets(
        'renders $SearchSectionErrorState on failure',
        (tester) async {
          when(() => mockBloc.state).thenReturn(
            const HashtagSearchState(
              status: HashtagSearchStatus.failure,
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
            const HashtagSearchState(
              status: HashtagSearchStatus.success,
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
            const HashtagSearchState(
              status: HashtagSearchStatus.failure,
              query: 'test',
            ),
          );

          await tester.pumpWidget(buildSubject(showAll: true));

          expect(find.byType(SearchSectionErrorState), findsOneWidget);
        },
      );
    });

    testWidgets(
      'retry dispatches $HashtagSearchQueryChanged with current query',
      (tester) async {
        when(() => mockBloc.state).thenReturn(
          const HashtagSearchState(
            status: HashtagSearchStatus.failure,
            query: 'retry-test',
          ),
        );

        await tester.pumpWidget(buildSubject());
        await tester.tap(find.text('Try again'));
        await tester.pumpAndSettle();

        verify(
          () => mockBloc.add(const HashtagSearchQueryChanged('retry-test')),
        ).called(1);
      },
    );
  });
}
