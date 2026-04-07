import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/hashtag_search/hashtag_search_bloc.dart';
import 'package:openvine/blocs/search_results_filter/search_results_filter.dart';
import 'package:openvine/blocs/user_search/user_search_bloc.dart';
import 'package:openvine/blocs/video_search/video_search_bloc.dart';
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

void main() {
  group(SearchResultsView, () {
    late _MockSearchResultsFilterCubit mockFilterCubit;
    late _MockVideoSearchBloc mockVideoBloc;
    late _MockUserSearchBloc mockUserBloc;
    late _MockHashtagSearchBloc mockHashtagBloc;

    setUp(() {
      mockFilterCubit = _MockSearchResultsFilterCubit();
      mockVideoBloc = _MockVideoSearchBloc();
      mockUserBloc = _MockUserSearchBloc();
      mockHashtagBloc = _MockHashtagSearchBloc();

      when(() => mockVideoBloc.state).thenReturn(const VideoSearchState());
      when(() => mockUserBloc.state).thenReturn(const UserSearchState());
      when(() => mockHashtagBloc.state).thenReturn(const HashtagSearchState());
    });

    tearDown(() {
      mockFilterCubit.close();
      mockVideoBloc.close();
      mockUserBloc.close();
      mockHashtagBloc.close();
    });

    Widget buildSubject() {
      return MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider<SearchResultsFilterCubit>.value(
              value: mockFilterCubit,
            ),
            BlocProvider<VideoSearchBloc>.value(value: mockVideoBloc),
            BlocProvider<UserSearchBloc>.value(value: mockUserBloc),
            BlocProvider<HashtagSearchBloc>.value(value: mockHashtagBloc),
          ],
          child: const Scaffold(body: SearchResultsView()),
        ),
      );
    }

    testWidgets('renders all sections when filter is all', (tester) async {
      when(() => mockFilterCubit.state).thenReturn(SearchResultsFilter.all);
      await tester.pumpWidget(buildSubject());

      expect(find.byType(PeopleSection), findsOneWidget);
      expect(find.byType(TagsSection), findsOneWidget);
      expect(find.byType(VideosSection), findsOneWidget);
    });

    testWidgets('renders only $PeopleSection when filter is people', (
      tester,
    ) async {
      when(() => mockFilterCubit.state).thenReturn(SearchResultsFilter.people);
      await tester.pumpWidget(buildSubject());

      expect(find.byType(PeopleSection), findsOneWidget);
      expect(find.byType(TagsSection), findsNothing);
      expect(find.byType(VideosSection), findsNothing);
    });

    testWidgets('renders only $TagsSection when filter is tags', (
      tester,
    ) async {
      when(() => mockFilterCubit.state).thenReturn(SearchResultsFilter.tags);
      await tester.pumpWidget(buildSubject());

      expect(find.byType(PeopleSection), findsNothing);
      expect(find.byType(TagsSection), findsOneWidget);
      expect(find.byType(VideosSection), findsNothing);
    });

    testWidgets('renders only $VideosSection when filter is videos', (
      tester,
    ) async {
      when(() => mockFilterCubit.state).thenReturn(SearchResultsFilter.videos);
      await tester.pumpWidget(buildSubject());

      expect(find.byType(PeopleSection), findsNothing);
      expect(find.byType(TagsSection), findsNothing);
      expect(find.byType(VideosSection), findsOneWidget);
    });

    testWidgets('renders $ColoredBox with background color', (tester) async {
      when(() => mockFilterCubit.state).thenReturn(SearchResultsFilter.all);
      await tester.pumpWidget(buildSubject());

      expect(
        find.byWidgetPredicate(
          (w) => w is ColoredBox && w.color == VineTheme.backgroundColor,
        ),
        findsOneWidget,
      );
    });
  });
}
