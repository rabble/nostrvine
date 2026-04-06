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

          // People filter shows only PeopleSection (with header hidden).
          expect(find.byType(PeopleSection), findsOneWidget);
          expect(find.byType(TagsSection), findsNothing);
          expect(find.byType(VideosSection), findsNothing);
        },
      );

      testWidgets(
        'returns to All mode when filter pill is tapped',
        (tester) async {
          await tester.pumpWidget(createTestWidget());
          await tester.pump();

          // Switch to People mode first.
          await tester.tap(find.text('People'));
          await tester.pump();

          expect(find.byType(TagsSection), findsNothing);

          // Tap the filter pill (shows "People" label) to open the sheet,
          // then select "All" to return.
          await tester.tap(find.byType(SearchFilterPill));
          await tester.pumpAndSettle();

          await tester.tap(find.text('All'));
          await tester.pumpAndSettle();

          expect(find.byType(PeopleSection), findsOneWidget);
          expect(find.byType(TagsSection), findsOneWidget);
          expect(find.byType(VideosSection), findsOneWidget);
        },
      );
    });
  });
}
