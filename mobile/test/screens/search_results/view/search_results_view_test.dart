import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/hashtag_search/hashtag_search_bloc.dart';
import 'package:openvine/blocs/list_search/list_search_bloc.dart';
import 'package:openvine/blocs/search_results_filter/search_results_filter.dart';
import 'package:openvine/blocs/user_search/user_search_bloc.dart';
import 'package:openvine/blocs/video_search/video_search_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/screens/search_results/view/search_results_view.dart';
import 'package:openvine/screens/search_results/widgets/widgets.dart';

class _MockSearchResultsFilterCubit extends MockCubit<SearchResultsFilter>
    implements SearchResultsFilterCubit {}

class _MockVideoSearchBloc extends MockBloc<VideoSearchEvent, VideoSearchState>
    implements VideoSearchBloc {}

class _MockUserSearchBloc extends MockBloc<UserSearchEvent, UserSearchState>
    implements UserSearchBloc {}

class _MockHashtagSearchBloc
    extends MockBloc<HashtagSearchEvent, HashtagSearchState>
    implements HashtagSearchBloc {}

class _MockListSearchBloc extends MockBloc<ListSearchEvent, ListSearchState>
    implements ListSearchBloc {}

void main() {
  group(SearchResultsView, () {
    late _MockSearchResultsFilterCubit mockFilterCubit;
    late _MockVideoSearchBloc mockVideoBloc;
    late _MockUserSearchBloc mockUserBloc;
    late _MockHashtagSearchBloc mockHashtagBloc;
    late _MockListSearchBloc mockListBloc;

    setUp(() {
      mockFilterCubit = _MockSearchResultsFilterCubit();
      mockVideoBloc = _MockVideoSearchBloc();
      mockUserBloc = _MockUserSearchBloc();
      mockHashtagBloc = _MockHashtagSearchBloc();
      mockListBloc = _MockListSearchBloc();

      // Default to a non-idle video state so the filter switch is exercised.
      // Individual idle-state tests override this to `initial`.
      when(() => mockVideoBloc.state).thenReturn(
        const VideoSearchState(
          status: VideoSearchStatus.success,
          query: 'test',
        ),
      );
      when(() => mockUserBloc.state).thenReturn(const UserSearchState());
      when(() => mockHashtagBloc.state).thenReturn(const HashtagSearchState());
      when(() => mockListBloc.state).thenReturn(const ListSearchState());
    });

    tearDown(() {
      mockFilterCubit.close();
      mockVideoBloc.close();
      mockUserBloc.close();
      mockHashtagBloc.close();
      mockListBloc.close();
    });

    Widget buildSubject() {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MultiBlocProvider(
          providers: [
            BlocProvider<SearchResultsFilterCubit>.value(
              value: mockFilterCubit,
            ),
            BlocProvider<VideoSearchBloc>.value(value: mockVideoBloc),
            BlocProvider<UserSearchBloc>.value(value: mockUserBloc),
            BlocProvider<HashtagSearchBloc>.value(value: mockHashtagBloc),
            BlocProvider<ListSearchBloc>.value(value: mockListBloc),
          ],
          child: const Scaffold(body: SearchResultsView()),
        ),
      );
    }

    // Each of these tests exercises filter routing only. Sections render
    // zero-extent content for the mocked BLoC states, so the finders use
    // `skipOffstage: false` to assert widget presence in the tree rather
    // than visible rendering.
    testWidgets('renders all sections when filter is all', (tester) async {
      when(() => mockFilterCubit.state).thenReturn(SearchResultsFilter.all);
      await tester.pumpWidget(buildSubject());

      expect(
        find.byType(PeopleSection, skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.byType(ListsSection, skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.byType(TagsSection, skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.byType(VideosSection, skipOffstage: false),
        findsOneWidget,
      );
    });

    testWidgets('renders only $PeopleSection when filter is people', (
      tester,
    ) async {
      when(() => mockFilterCubit.state).thenReturn(SearchResultsFilter.people);
      await tester.pumpWidget(buildSubject());

      expect(
        find.byType(PeopleSection, skipOffstage: false),
        findsOneWidget,
      );
      expect(find.byType(TagsSection, skipOffstage: false), findsNothing);
      expect(find.byType(ListsSection, skipOffstage: false), findsNothing);
      expect(find.byType(VideosSection, skipOffstage: false), findsNothing);
    });

    testWidgets('renders only $TagsSection when filter is tags', (
      tester,
    ) async {
      when(() => mockFilterCubit.state).thenReturn(SearchResultsFilter.tags);
      await tester.pumpWidget(buildSubject());

      expect(find.byType(PeopleSection, skipOffstage: false), findsNothing);
      expect(find.byType(TagsSection, skipOffstage: false), findsOneWidget);
      expect(find.byType(ListsSection, skipOffstage: false), findsNothing);
      expect(find.byType(VideosSection, skipOffstage: false), findsNothing);
    });

    testWidgets('renders only $VideosSection when filter is videos', (
      tester,
    ) async {
      when(() => mockFilterCubit.state).thenReturn(SearchResultsFilter.videos);
      await tester.pumpWidget(buildSubject());

      expect(find.byType(PeopleSection, skipOffstage: false), findsNothing);
      expect(find.byType(TagsSection, skipOffstage: false), findsNothing);
      expect(find.byType(ListsSection, skipOffstage: false), findsNothing);
      expect(
        find.byType(VideosSection, skipOffstage: false),
        findsOneWidget,
      );
    });

    testWidgets('renders only $ListsSection when filter is lists', (
      tester,
    ) async {
      when(() => mockFilterCubit.state).thenReturn(SearchResultsFilter.lists);
      await tester.pumpWidget(buildSubject());

      expect(find.byType(PeopleSection, skipOffstage: false), findsNothing);
      expect(find.byType(TagsSection, skipOffstage: false), findsNothing);
      expect(
        find.byType(ListsSection, skipOffstage: false),
        findsOneWidget,
      );
      expect(find.byType(VideosSection, skipOffstage: false), findsNothing);
    });

    testWidgets('renders $ColoredBox with surface background', (tester) async {
      when(() => mockFilterCubit.state).thenReturn(SearchResultsFilter.all);
      await tester.pumpWidget(buildSubject());

      expect(
        find.byWidgetPredicate(
          (w) => w is ColoredBox && w.color == VineTheme.surfaceBackground,
        ),
        findsOneWidget,
      );
    });

    group('idle state', () {
      setUp(() {
        when(() => mockVideoBloc.state).thenReturn(const VideoSearchState());
      });

      testWidgets(
        'renders $SearchSectionInitialState when video search is idle',
        (tester) async {
          when(() => mockFilterCubit.state).thenReturn(SearchResultsFilter.all);
          await tester.pumpWidget(buildSubject());

          expect(find.byType(SearchSectionInitialState), findsOneWidget);
          expect(find.text('Enter a search query'), findsOneWidget);
          expect(find.text('Discover something interesting'), findsOneWidget);
        },
      );

      testWidgets(
        'hides all sections when idle regardless of selected filter',
        (tester) async {
          when(
            () => mockFilterCubit.state,
          ).thenReturn(SearchResultsFilter.videos);
          await tester.pumpWidget(buildSubject());

          expect(find.byType(VideosSection), findsNothing);
          expect(find.byType(PeopleSection), findsNothing);
          expect(find.byType(TagsSection), findsNothing);
          expect(find.byType(ListsSection), findsNothing);
          expect(find.byType(SearchSectionInitialState), findsOneWidget);
        },
      );
    });
  });
}
