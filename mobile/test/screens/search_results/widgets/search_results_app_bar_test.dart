import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/hashtag_search/hashtag_search_bloc.dart';
import 'package:openvine/blocs/list_search/list_search_bloc.dart';
import 'package:openvine/blocs/search_results_filter/search_results_filter.dart';
import 'package:openvine/blocs/user_search/user_search_bloc.dart';
import 'package:openvine/blocs/video_search/video_search_bloc.dart';
import 'package:openvine/screens/search_results/widgets/search_filter_pill.dart';
import 'package:openvine/screens/search_results/widgets/search_results_app_bar.dart';

import '../../../helpers/test_provider_overrides.dart';

class _MockSearchResultsFilterCubit extends MockCubit<SearchResultsFilter>
    implements SearchResultsFilterCubit {}

class _MockUserSearchBloc extends MockBloc<UserSearchEvent, UserSearchState>
    implements UserSearchBloc {}

class _MockVideoSearchBloc extends MockBloc<VideoSearchEvent, VideoSearchState>
    implements VideoSearchBloc {}

class _MockHashtagSearchBloc
    extends MockBloc<HashtagSearchEvent, HashtagSearchState>
    implements HashtagSearchBloc {}

class _MockListSearchBloc extends MockBloc<ListSearchEvent, ListSearchState>
    implements ListSearchBloc {}

void main() {
  group(SearchResultsAppBar, () {
    late _MockSearchResultsFilterCubit mockFilterCubit;
    late _MockUserSearchBloc mockUserSearchBloc;
    late _MockVideoSearchBloc mockVideoSearchBloc;
    late _MockHashtagSearchBloc mockHashtagSearchBloc;
    late _MockListSearchBloc mockListSearchBloc;

    setUp(() {
      mockFilterCubit = _MockSearchResultsFilterCubit();
      mockUserSearchBloc = _MockUserSearchBloc();
      mockVideoSearchBloc = _MockVideoSearchBloc();
      mockHashtagSearchBloc = _MockHashtagSearchBloc();
      mockListSearchBloc = _MockListSearchBloc();

      when(() => mockFilterCubit.state).thenReturn(SearchResultsFilter.all);
      when(() => mockUserSearchBloc.state).thenReturn(const UserSearchState());
      when(
        () => mockVideoSearchBloc.state,
      ).thenReturn(const VideoSearchState());
      when(
        () => mockHashtagSearchBloc.state,
      ).thenReturn(const HashtagSearchState());
      when(() => mockListSearchBloc.state).thenReturn(const ListSearchState());
    });

    Widget createTestWidget({
      String initialQuery = 'test',
      bool requestFocusOnMount = false,
    }) {
      return testMaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider<SearchResultsFilterCubit>.value(
              value: mockFilterCubit,
            ),
            BlocProvider<UserSearchBloc>.value(value: mockUserSearchBloc),
            BlocProvider<VideoSearchBloc>.value(value: mockVideoSearchBloc),
            BlocProvider<HashtagSearchBloc>.value(value: mockHashtagSearchBloc),
            BlocProvider<ListSearchBloc>.value(value: mockListSearchBloc),
          ],
          child: Scaffold(
            body: SearchResultsAppBar(
              initialQuery: initialQuery,
              requestFocusOnMount: requestFocusOnMount,
            ),
          ),
        ),
        mockAuthService: createMockAuthService(),
      );
    }

    testWidgets('renders $SearchFilterPill', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      expect(find.byType(SearchFilterPill), findsOneWidget);
    });

    testWidgets('renders search bar with initial query', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      expect(find.text('test'), findsOneWidget);
    });

    testWidgets(
      'keeps keyboard dismissed for a prefilled query by default',
      (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        final textField = tester.widget<TextField>(find.byType(TextField));

        expect(textField.focusNode?.hasFocus, isFalse);
      },
    );

    testWidgets(
      'requests focus for a prefilled query when the route opts in',
      (tester) async {
        await tester.pumpWidget(createTestWidget(requestFocusOnMount: true));
        await tester.pump();

        final textField = tester.widget<TextField>(find.byType(TextField));

        expect(textField.focusNode?.hasFocus, isTrue);
      },
    );

    testWidgets('still focuses the empty query state', (tester) async {
      await tester.pumpWidget(
        createTestWidget(initialQuery: ''),
      );
      await tester.pump();

      final textField = tester.widget<TextField>(find.byType(TextField));

      expect(textField.focusNode?.hasFocus, isTrue);
    });
  });
}
