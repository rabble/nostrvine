// ABOUTME: Tests for SearchScreenPure widget
// ABOUTME: Verifies tab count formatting consistency and search behavior

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mockito/mockito.dart' as mockito;
import 'package:models/models.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/pure/search_screen_pure.dart';
import 'package:openvine/services/content_blocklist_service.dart';
import 'package:openvine/services/hashtag_service.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:profile_repository/profile_repository.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockProfileRepository extends Mock implements ProfileRepository {}

class _MockContentBlocklistService extends Mock
    implements ContentBlocklistService {}

class _MockHashtagService extends Mock implements HashtagService {}

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
    late _MockHashtagService mockHashtagService;

    setUp(() {
      mockProfileRepository = _MockProfileRepository();
      mockBlocklistService = _MockContentBlocklistService();
      fakeVideoEventService = _FakeVideoEventService();
      mockHashtagService = _MockHashtagService();

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

      // Default HashtagService stubs
      when(() => mockHashtagService.refreshHashtagStats()).thenReturn(null);
      when(() => mockHashtagService.searchHashtags(any())).thenReturn([]);
    });

    Widget createTestWidget({List<VideoEvent>? videos}) {
      final videoService = videos != null
          ? _FakeVideoEventService(videos: videos)
          : fakeVideoEventService;

      // Create mock with getDisplayName stubbed (mockito mock)
      final mockUserProfileService = createMockUserProfileService();
      mockito
          .when(mockUserProfileService.getDisplayName(mockito.any))
          .thenReturn('');

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
          hashtagServiceProvider.overrideWithValue(mockHashtagService),
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
            pubkey: '${'a' * 64}',
            content: 'Test video about flutter',
            title: 'Flutter Tutorial',
            videoUrl: 'https://example.com/video1.mp4',
            createdAt: timestamp,
            timestamp: now,
            hashtags: ['flutter'],
          ),
        ];

        // Stub HashtagService to return 'flutter' for this query
        when(
          () => mockHashtagService.searchHashtags('flutter'),
        ).thenReturn(['flutter']);

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
