// ABOUTME: Tests for SearchScreenPure widget
// ABOUTME: Verifies tab count formatting consistency and search behavior

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hashtag_repository/hashtag_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/route_feed_providers.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/pure/search_screen_pure.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:videos_repository/videos_repository.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockProfileRepository extends Mock implements ProfileRepository {}

class _MockHashtagRepository extends Mock implements HashtagRepository {}

class _MockVideosRepository extends Mock implements VideosRepository {}

class _FakeVideoEventService extends ChangeNotifier
    implements VideoEventService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  List<VideoEvent> filterVideoList(List<VideoEvent> videos) => videos;

  @override
  bool shouldHideVideo(VideoEvent video) => false;
}

void main() {
  group(SearchScreenPure, () {
    late _MockProfileRepository mockProfileRepository;
    late _MockHashtagRepository mockHashtagRepository;
    late _MockVideosRepository mockVideosRepository;
    late _FakeVideoEventService fakeVideoEventService;

    setUp(() {
      mockProfileRepository = _MockProfileRepository();
      mockHashtagRepository = _MockHashtagRepository();
      mockVideosRepository = _MockVideosRepository();
      fakeVideoEventService = _FakeVideoEventService();

      when(
        () => mockProfileRepository.searchUsersProgressive(
          query: any(named: 'query'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
          sortBy: any(named: 'sortBy'),
          hasVideos: any(named: 'hasVideos'),
        ),
      ).thenAnswer((_) => Stream.value(<UserProfile>[]));

      when(
        () => mockProfileRepository.searchUsers(
          query: any(named: 'query'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
          sortBy: any(named: 'sortBy'),
          hasVideos: any(named: 'hasVideos'),
        ),
      ).thenAnswer((_) async => <UserProfile>[]);

      when(
        () => mockHashtagRepository.searchHashtags(
          query: any(named: 'query'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => []);

      when(
        () => mockHashtagRepository.countHashtagsLocally(
          query: any(named: 'query'),
        ),
      ).thenReturn(0);

      when(
        () =>
            mockProfileRepository.countUsersLocally(query: any(named: 'query')),
      ).thenAnswer((_) async => 0);

      // Single stream stub for searchVideos
      when(
        () => mockVideosRepository.searchVideos(
          query: any(named: 'query'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) => Stream.value([]));

      when(
        () =>
            mockVideosRepository.countVideosLocally(query: any(named: 'query')),
      ).thenAnswer((_) async => 0);
    });

    Widget createTestWidget({List<VideoEvent>? searchResults}) {
      if (searchResults != null) {
        when(
          () => mockVideosRepository.searchVideos(
            query: any(named: 'query'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) => Stream.value(searchResults));
      }

      return ProviderScope(
        overrides: [
          ...getStandardTestOverrides(mockAuthService: createMockAuthService()),
          profileRepositoryProvider.overrideWithValue(mockProfileRepository),
          videosRepositoryProvider.overrideWithValue(mockVideosRepository),
          videoEventServiceProvider.overrideWithValue(fakeVideoEventService),
          hashtagRepositoryProvider.overrideWithValue(mockHashtagRepository),
          pageContextProvider.overrideWith((ref) {
            return Stream.value(const RouteContext(type: RouteType.search));
          }),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
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
        return ProviderScope(
          overrides: [
            ...getStandardTestOverrides(
              mockAuthService: createMockAuthService(),
            ),
            profileRepositoryProvider.overrideWithValue(mockProfileRepository),
            videosRepositoryProvider.overrideWithValue(mockVideosRepository),
            videoEventServiceProvider.overrideWithValue(fakeVideoEventService),
            hashtagRepositoryProvider.overrideWithValue(mockHashtagRepository),
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
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: ThemeData.dark(),
            home: const Scaffold(body: SearchScreenPure(embedded: true)),
          ),
        );
      }

      testWidgets('shows loading indicator when videoIndex is set but '
          'no videos', (tester) async {
        await tester.pumpWidget(createFeedModeWidget(videoIndex: 0));
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('No videos available'), findsNothing);
      });

      testWidgets('hides tabs when in feed mode', (tester) async {
        await tester.pumpWidget(createFeedModeWidget(videoIndex: 0));
        await tester.pump();

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

        when(
          () => mockVideosRepository.searchVideos(query: 'flutter'),
        ).thenAnswer((_) => Stream.value(testVideos));

        when(
          () => mockHashtagRepository.searchHashtags(query: 'flutter'),
        ).thenAnswer((_) async => ['flutter']);

        await tester.pumpWidget(createTestWidget(searchResults: testVideos));

        final textField = find.byType(TextField);
        await tester.enterText(textField, 'flutter');

        // Wait for debounce (300ms) + BLoC debounce (300ms) +
        // processing
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
