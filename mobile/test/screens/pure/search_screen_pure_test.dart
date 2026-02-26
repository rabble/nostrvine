// ABOUTME: Tests for SearchScreenPure widget
// ABOUTME: Verifies tab count formatting consistency and search behavior

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hashtag_repository/hashtag_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/route_feed_providers.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/pure/search_screen_pure.dart';
import 'package:openvine/services/content_blocklist_service.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:profile_repository/profile_repository.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockProfileRepository extends Mock implements ProfileRepository {}

class _MockContentBlocklistService extends Mock
    implements ContentBlocklistService {}

class _MockHashtagRepository extends Mock implements HashtagRepository {}

class _FakeVideoEventService extends ChangeNotifier
    implements VideoEventService {
  _FakeVideoEventService({this.videos = const []});

  final List<VideoEvent> videos;

  @override
  List<VideoEvent> get discoveryVideos => videos;

  @override
  List<VideoEvent> get searchResults => [];

  @override
  Future<void> searchVideos(
    String query, {
    List<String>? authors,
    DateTime? since,
    DateTime? until,
    int? limit,
  }) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group(SearchScreenPure, () {
    late _MockProfileRepository mockProfileRepository;
    late _MockContentBlocklistService mockBlocklistService;
    late _FakeVideoEventService fakeVideoEventService;
    late _MockHashtagRepository mockHashtagRepository;

    setUp(() {
      mockProfileRepository = _MockProfileRepository();
      mockBlocklistService = _MockContentBlocklistService();
      fakeVideoEventService = _FakeVideoEventService();
      mockHashtagRepository = _MockHashtagRepository();

      when(
        () => mockBlocklistService.shouldFilterFromFeeds(any()),
      ).thenReturn(false);
      when(
        () => mockProfileRepository.searchUsers(
          query: any(named: 'query'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
          sortBy: any(named: 'sortBy'),
          hasVideos: any(named: 'hasVideos'),
        ),
      ).thenAnswer((_) async => <UserProfile>[]);

      // Default HashtagRepository stub
      when(
        () => mockHashtagRepository.searchHashtags(
          query: any(named: 'query'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => []);
    });

    Widget createTestWidget({List<VideoEvent>? videos}) {
      final videoService = videos != null
          ? _FakeVideoEventService(videos: videos)
          : fakeVideoEventService;

      // Create mock with getDisplayName stubbed
      final mockUserProfileService = createMockUserProfileService();
      when(() => mockUserProfileService.getDisplayName(any())).thenReturn('');

      return ProviderScope(
        overrides: [
          ...getStandardTestOverrides(
            mockAuthService: createMockAuthService(),
            mockUserProfileService: mockUserProfileService,
          ),
          profileRepositoryProvider.overrideWithValue(mockProfileRepository),
          videoEventServiceProvider.overrideWithValue(videoService),
          contentBlocklistServiceProvider.overrideWithValue(
            mockBlocklistService,
          ),
          hashtagRepositoryProvider.overrideWithValue(mockHashtagRepository),
          pageContextProvider.overrideWith((ref) {
            return Stream.value(const RouteContext(type: RouteType.search));
          }),
        ],
        child: MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(body: SearchScreenPure(embedded: true)),
        ),
      );
    }

    group('Feed mode', () {
      Widget createFeedModeWidget({
        required int videoIndex,
        List<VideoEvent>? searchVideos,
      }) {
        final mockUserProfileService = createMockUserProfileService();
        when(() => mockUserProfileService.getDisplayName(any())).thenReturn('');

        return ProviderScope(
          overrides: [
            ...getStandardTestOverrides(
              mockAuthService: createMockAuthService(),
              mockUserProfileService: mockUserProfileService,
            ),
            profileRepositoryProvider.overrideWithValue(mockProfileRepository),
            videoEventServiceProvider.overrideWithValue(fakeVideoEventService),
            contentBlocklistServiceProvider.overrideWithValue(
              mockBlocklistService,
            ),
            pageContextProvider.overrideWith((ref) {
              return Stream.value(
                RouteContext(
                  type: RouteType.search,
                  searchTerm: 'test',
                  videoIndex: videoIndex,
                ),
              );
            }),
            searchScreenVideosProvider.overrideWith((ref) => searchVideos),
          ],
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: const Scaffold(body: SearchScreenPure(embedded: true)),
          ),
        );
      }

      testWidgets(
        'shows "No videos available" when videoIndex is set but no videos',
        (tester) async {
          await tester.pumpWidget(createFeedModeWidget(videoIndex: 0));
          await tester.pumpAndSettle();

          expect(find.text('No videos available'), findsOneWidget);
          expect(find.text('Videos (0)'), findsNothing);
        },
      );

      testWidgets('hides tabs when in feed mode', (tester) async {
        await tester.pumpWidget(createFeedModeWidget(videoIndex: 0));
        await tester.pumpAndSettle();

        expect(find.byType(TabBar), findsNothing);
        expect(find.byType(TextField), findsNothing);
      });
    });

    group('Tab count', () {
      testWidgets('all tabs show count in parentheses format even when empty', (
        tester,
      ) async {
        await tester.pumpWidget(createTestWidget());

        expect(find.text('Videos (0)'), findsOneWidget);
        expect(find.text('Users (0)'), findsOneWidget);
        expect(find.text('Hashtags (0)'), findsOneWidget);
      });

      testWidgets('tabs show correct non-zero counts after search', (
        tester,
      ) async {
        final now = DateTime.now();
        final timestamp = now.millisecondsSinceEpoch ~/ 1000;

        final testVideos = [
          VideoEvent(
            id: 'video1',
            pubkey: 'a' * 64,
            content: 'Test video about flutter',
            title: 'Flutter Tutorial',
            videoUrl: 'https://example.com/video1.mp4',
            createdAt: timestamp,
            timestamp: now,
            hashtags: const ['flutter'],
          ),
        ];

        // Stub HashtagRepository to return 'flutter' for this query
        when(
          () => mockHashtagRepository.searchHashtags(query: 'flutter'),
        ).thenAnswer((_) async => ['flutter']);

        await tester.pumpWidget(createTestWidget(videos: testVideos));

        final textField = find.byType(TextField);
        await tester.enterText(textField, 'flutter');

        // Wait for debounce (300ms) + BLoC debounce (300ms) + processing
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump();

        expect(find.text('Videos (1)'), findsOneWidget);
        expect(find.text('Hashtags (1)'), findsOneWidget);
        expect(find.text('Users (0)'), findsOneWidget);
      });
    });
  });
}
