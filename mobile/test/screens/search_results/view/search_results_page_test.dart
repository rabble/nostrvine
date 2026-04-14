import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hashtag_repository/hashtag_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/search_results/view/search_results_page.dart';
import 'package:openvine/screens/search_results/widgets/widgets.dart';
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

          final scrollable = find.descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          );

          expect(find.byType(PeopleSection), findsOneWidget);
          expect(find.text('All'), findsOneWidget);

          await tester.scrollUntilVisible(
            find.byType(TagsSection),
            200,
            scrollable: scrollable,
          );
          expect(find.byType(TagsSection), findsOneWidget);

          await tester.scrollUntilVisible(
            find.byType(VideosSection),
            200,
            scrollable: scrollable,
          );
          expect(find.byType(VideosSection), findsOneWidget);
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

          // People filter shows only PeopleSection (with header hidden).
          expect(find.byType(PeopleSection), findsOneWidget);
          expect(find.byType(TagsSection), findsNothing);
          expect(find.byType(VideosSection), findsNothing);
        },
      );

      testWidgets(
        'filter pill shows correct label after switching to People',
        (tester) async {
          await tester.pumpWidget(createTestWidget());
          await tester.pump();

          // Default label is "All".
          expect(
            find.descendant(
              of: find.byType(SearchFilterPill),
              matching: find.text('All'),
            ),
            findsOneWidget,
          );

          // Switch to People mode.
          await tester.tap(find.text('People'));
          await tester.pump();

          // Pill now shows "People".
          expect(
            find.descendant(
              of: find.byType(SearchFilterPill),
              matching: find.text('People'),
            ),
            findsOneWidget,
          );
        },
      );
    });
  });
}
