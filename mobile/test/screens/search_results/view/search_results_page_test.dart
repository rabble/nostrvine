import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hashtag_repository/hashtag_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/search_results/view/search_results_page.dart';
import 'package:openvine/screens/search_results/widgets/widgets.dart';
import 'package:openvine/widgets/user_search_view.dart';
import 'package:videos_repository/videos_repository.dart';

import '../../../helpers/test_provider_overrides.dart';

class _MockVideosRepository extends Mock implements VideosRepository {}

class _MockHashtagRepository extends Mock implements HashtagRepository {}

void main() {
  group(SearchResultsPage, () {
    late MockProfileRepository mockProfileRepository;
    late _MockVideosRepository mockVideosRepository;
    late _MockHashtagRepository mockHashtagRepository;

    setUp(() {
      mockProfileRepository = createMockProfileRepository();
      mockVideosRepository = _MockVideosRepository();
      mockHashtagRepository = _MockHashtagRepository();
    });

    Widget createTestWidget() {
      return testMaterialApp(
        home: const SearchResultsPage(),
        mockProfileRepository: mockProfileRepository,
        additionalOverrides: [
          videosRepositoryProvider.overrideWithValue(mockVideosRepository),
          hashtagRepositoryProvider.overrideWithValue(mockHashtagRepository),
        ],
      );
    }

    group('filter round-trip', () {
      testWidgets(
        'shows all sections and "All" chip in default mode',
        (tester) async {
          await tester.pumpWidget(createTestWidget());
          await tester.pump();

          expect(find.byType(PeopleSection), findsOneWidget);
          expect(find.byType(TagsSection), findsOneWidget);
          expect(find.byType(VideosSection), findsOneWidget);
          expect(find.text('All'), findsOneWidget);
        },
      );

      testWidgets(
        'switches to People mode when See all is tapped',
        (tester) async {
          await tester.pumpWidget(createTestWidget());
          await tester.pump();

          // Tap the People section header to trigger "See all".
          await tester.tap(find.text('People'));
          await tester.pump();

          expect(find.byType(UserSearchView), findsOneWidget);
          expect(find.byType(PeopleSection), findsNothing);
          expect(find.byType(TagsSection), findsNothing);
          expect(find.byType(VideosSection), findsNothing);
          expect(find.text('People'), findsOneWidget);
        },
      );

      testWidgets(
        'returns to All mode when People chip is tapped',
        (tester) async {
          await tester.pumpWidget(createTestWidget());
          await tester.pump();

          // Switch to People mode first.
          await tester.tap(find.text('People'));
          await tester.pump();

          expect(find.byType(UserSearchView), findsOneWidget);

          // Tap the "People" filter chip to return to All.
          await tester.tap(find.text('People'));
          await tester.pump();

          expect(find.byType(PeopleSection), findsOneWidget);
          expect(find.byType(TagsSection), findsOneWidget);
          expect(find.byType(VideosSection), findsOneWidget);
          expect(find.text('All'), findsOneWidget);
        },
      );
    });
  });
}
