import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/hashtag_search/hashtag_search_bloc.dart';
import 'package:openvine/blocs/user_search/user_search_bloc.dart';
import 'package:openvine/blocs/video_search/video_search_bloc.dart';
import 'package:openvine/screens/search_results/widgets/search_results_app_bar.dart';

import '../../../helpers/test_provider_overrides.dart';

class _MockUserSearchBloc extends MockBloc<UserSearchEvent, UserSearchState>
    implements UserSearchBloc {}

class _MockVideoSearchBloc extends MockBloc<VideoSearchEvent, VideoSearchState>
    implements VideoSearchBloc {}

class _MockHashtagSearchBloc
    extends MockBloc<HashtagSearchEvent, HashtagSearchState>
    implements HashtagSearchBloc {}

void main() {
  group(SearchResultsAppBar, () {
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
      String? filterLabel,
      VoidCallback? onFilterTap,
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
            body: SearchResultsAppBar(
              initialQuery: 'test',
              filterLabel: filterLabel,
              onFilterTap: onFilterTap,
            ),
          ),
        ),
        mockAuthService: createMockAuthService(),
      );
    }

    group('filter chip', () {
      testWidgets('renders filter label when provided', (tester) async {
        await tester.pumpWidget(createTestWidget(filterLabel: 'People'));
        await tester.pump();

        expect(find.text('People'), findsOneWidget);
      });

      testWidgets('does not render filter chip when label is null', (
        tester,
      ) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        expect(find.text('All'), findsNothing);
        expect(find.text('People'), findsNothing);
      });

      testWidgets('calls onFilterTap when chip is tapped', (tester) async {
        var tapped = false;

        await tester.pumpWidget(
          createTestWidget(
            filterLabel: 'People',
            onFilterTap: () => tapped = true,
          ),
        );
        await tester.pump();

        await tester.tap(find.text('People'));
        await tester.pump();

        expect(tapped, isTrue);
      });
    });
  });
}
