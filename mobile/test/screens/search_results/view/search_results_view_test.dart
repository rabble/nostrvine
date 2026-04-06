import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/hashtag_search/hashtag_search_bloc.dart';
import 'package:openvine/blocs/user_search/user_search_bloc.dart';
import 'package:openvine/blocs/video_search/video_search_bloc.dart';
import 'package:openvine/screens/search_results/view/search_results_view.dart';
import 'package:openvine/screens/search_results/widgets/widgets.dart';
import 'package:openvine/widgets/hashtag_search_view.dart';
import 'package:openvine/widgets/user_search_view.dart';

import '../../../helpers/test_provider_overrides.dart';

class _MockUserSearchBloc extends MockBloc<UserSearchEvent, UserSearchState>
    implements UserSearchBloc {}

class _MockVideoSearchBloc extends MockBloc<VideoSearchEvent, VideoSearchState>
    implements VideoSearchBloc {}

class _MockHashtagSearchBloc
    extends MockBloc<HashtagSearchEvent, HashtagSearchState>
    implements HashtagSearchBloc {}

void main() {
  group(SearchResultsView, () {
    late _MockUserSearchBloc mockUserSearchBloc;
    late _MockVideoSearchBloc mockVideoSearchBloc;
    late _MockHashtagSearchBloc mockHashtagSearchBloc;

    setUp(() {
      mockUserSearchBloc = _MockUserSearchBloc();
      mockVideoSearchBloc = _MockVideoSearchBloc();
      mockHashtagSearchBloc = _MockHashtagSearchBloc();

      when(() => mockUserSearchBloc.state).thenReturn(const UserSearchState());
      when(
        () => mockVideoSearchBloc.state,
      ).thenReturn(const VideoSearchState());
      when(
        () => mockHashtagSearchBloc.state,
      ).thenReturn(const HashtagSearchState());
    });

    Widget createTestWidget({
      SearchResultsFilter filter = SearchResultsFilter.all,
      ValueChanged<SearchResultsFilter>? onFilterChanged,
    }) {
      return testMaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider<UserSearchBloc>.value(value: mockUserSearchBloc),
            BlocProvider<VideoSearchBloc>.value(value: mockVideoSearchBloc),
            BlocProvider<HashtagSearchBloc>.value(
              value: mockHashtagSearchBloc,
            ),
          ],
          child: Scaffold(
            body: SearchResultsView(
              filter: filter,
              onFilterChanged: onFilterChanged ?? (_) {},
            ),
          ),
        ),
        mockAuthService: createMockAuthService(),
      );
    }

    group('all filter', () {
      testWidgets('renders $PeopleSection', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        expect(find.byType(PeopleSection), findsOneWidget);
      });

      testWidgets('renders $TagsSection', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        expect(find.byType(TagsSection), findsOneWidget);
      });

      testWidgets('renders $VideosSection', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        expect(find.byType(VideosSection), findsOneWidget);
      });

      testWidgets(
        'calls onFilterChanged with people when See all is tapped',
        (tester) async {
          SearchResultsFilter? changedFilter;

          await tester.pumpWidget(
            createTestWidget(onFilterChanged: (f) => changedFilter = f),
          );
          await tester.pump();

          // The SectionHeader renders a caret-right icon when onTap is set.
          // Tap the People section header to trigger "See all".
          await tester.tap(find.text('People'));
          await tester.pump();

          expect(changedFilter, equals(SearchResultsFilter.people));
        },
      );

      testWidgets(
        'calls onFilterChanged with tags when Tags See all is tapped',
        (tester) async {
          SearchResultsFilter? changedFilter;

          await tester.pumpWidget(
            createTestWidget(onFilterChanged: (f) => changedFilter = f),
          );
          await tester.pump();

          await tester.tap(find.text('Tags'));
          await tester.pump();

          expect(changedFilter, equals(SearchResultsFilter.tags));
        },
      );
    });

    group('people filter', () {
      testWidgets('renders $UserSearchView', (tester) async {
        await tester.pumpWidget(
          createTestWidget(filter: SearchResultsFilter.people),
        );
        await tester.pump();

        expect(find.byType(UserSearchView), findsOneWidget);
      });

      testWidgets('does not render $PeopleSection', (tester) async {
        await tester.pumpWidget(
          createTestWidget(filter: SearchResultsFilter.people),
        );
        await tester.pump();

        expect(find.byType(PeopleSection), findsNothing);
      });

      testWidgets('does not render $TagsSection', (tester) async {
        await tester.pumpWidget(
          createTestWidget(filter: SearchResultsFilter.people),
        );
        await tester.pump();

        expect(find.byType(TagsSection), findsNothing);
      });

      testWidgets('does not render $VideosSection', (tester) async {
        await tester.pumpWidget(
          createTestWidget(filter: SearchResultsFilter.people),
        );
        await tester.pump();

        expect(find.byType(VideosSection), findsNothing);
      });
    });

    group('tags filter', () {
      testWidgets('renders $HashtagSearchView', (tester) async {
        await tester.pumpWidget(
          createTestWidget(filter: SearchResultsFilter.tags),
        );
        await tester.pump();

        expect(find.byType(HashtagSearchView), findsOneWidget);
      });

      testWidgets('does not render $PeopleSection', (tester) async {
        await tester.pumpWidget(
          createTestWidget(filter: SearchResultsFilter.tags),
        );
        await tester.pump();

        expect(find.byType(PeopleSection), findsNothing);
      });

      testWidgets('does not render $TagsSection', (tester) async {
        await tester.pumpWidget(
          createTestWidget(filter: SearchResultsFilter.tags),
        );
        await tester.pump();

        expect(find.byType(TagsSection), findsNothing);
      });

      testWidgets('does not render $VideosSection', (tester) async {
        await tester.pumpWidget(
          createTestWidget(filter: SearchResultsFilter.tags),
        );
        await tester.pump();

        expect(find.byType(VideosSection), findsNothing);
      });
    });

    group('videos filter', () {
      testWidgets('renders $VideoSearchView', (tester) async {
        await tester.pumpWidget(
          createTestWidget(filter: SearchResultsFilter.videos),
        );
        await tester.pump();

        expect(find.byType(VideoSearchView), findsOneWidget);
      });

      testWidgets('does not render $PeopleSection', (tester) async {
        await tester.pumpWidget(
          createTestWidget(filter: SearchResultsFilter.videos),
        );
        await tester.pump();

        expect(find.byType(PeopleSection), findsNothing);
      });

      testWidgets('does not render $VideosSection', (tester) async {
        await tester.pumpWidget(
          createTestWidget(filter: SearchResultsFilter.videos),
        );
        await tester.pump();

        expect(find.byType(VideosSection), findsNothing);
      });
    });

    group('all filter — see all videos', () {
      testWidgets(
        'calls onFilterChanged with videos when Videos header is tapped',
        (tester) async {
          SearchResultsFilter? changedFilter;

          await tester.pumpWidget(
            createTestWidget(onFilterChanged: (f) => changedFilter = f),
          );
          await tester.pump();

          await tester.tap(find.text('Videos'));
          await tester.pump();

          expect(changedFilter, equals(SearchResultsFilter.videos));
        },
      );
    });
  });
}
