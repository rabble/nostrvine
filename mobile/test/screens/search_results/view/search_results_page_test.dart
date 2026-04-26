@Tags(['skip_very_good_optimization'])
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

    testWidgets('shows the empty-query idle placeholder in default mode', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      // No query has been entered yet, so the page renders the shared
      // idle placeholder instead of the individual result sections.
      expect(find.byType(SearchSectionInitialState), findsOneWidget);
      expect(find.byType(PeopleSection, skipOffstage: false), findsNothing);
      expect(find.byType(TagsSection, skipOffstage: false), findsNothing);
      expect(find.byType(ListsSection, skipOffstage: false), findsNothing);
      expect(find.byType(VideosSection, skipOffstage: false), findsNothing);

      // Filter pill defaults to "All".
      expect(
        find.descendant(
          of: find.byType(SearchFilterPill),
          matching: find.text('All'),
        ),
        findsOneWidget,
      );
    });
  });
}
