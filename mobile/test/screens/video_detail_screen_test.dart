// ABOUTME: Widget tests for VideoDetailScreen deep link video display
// ABOUTME: Verifies correct video is shown and error/blocked states handled

import 'dart:async';

import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/video_detail_screen.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:videos_repository/videos_repository.dart';

import '../helpers/test_provider_overrides.dart';
import '../test_data/video_test_data.dart';

class _MockVideoEventService extends Mock implements VideoEventService {}

class _MockFollowRepository extends Mock implements FollowRepository {}

class _MockNostrClient extends Mock implements NostrClient {}

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

class _MockVideosRepository extends Mock implements VideosRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(createTestVideoEvent(id: 'fallback_video'));
  });

  group(VideoDetailScreen, () {
    late _MockVideoEventService mockVideoEventService;
    late _MockContentBlocklistRepository mockBlocklistRepository;
    late _MockNostrClient mockNostrClient;
    late _MockFollowRepository mockFollowRepository;
    late _MockVideosRepository mockVideosRepository;
    late StreamController<Map<String, RelayConnectionStatus>>
    relayStatusController;

    setUp(() {
      mockVideoEventService = _MockVideoEventService();
      mockNostrClient = _MockNostrClient();
      mockBlocklistRepository = _MockContentBlocklistRepository();
      mockFollowRepository = _MockFollowRepository();
      mockVideosRepository = _MockVideosRepository();
      relayStatusController =
          StreamController<Map<String, RelayConnectionStatus>>.broadcast();

      when(() => mockFollowRepository.followingPubkeys).thenReturn([]);

      when(() => mockNostrClient.configuredRelays).thenReturn(<String>[]);
      when(() => mockNostrClient.publicKey).thenReturn('');
      when(() => mockNostrClient.isInitialized).thenReturn(true);
      when(() => mockNostrClient.hasKeys).thenReturn(false);
      when(() => mockNostrClient.connectedRelayCount).thenReturn(1);
      when(
        () => mockNostrClient.relayStatusStream,
      ).thenAnswer((_) => relayStatusController.stream);
      when(
        () => mockNostrClient.subscribe(any()),
      ).thenAnswer((_) => const Stream<Event>.empty());
      when(
        () => mockNostrClient.queryEvents(any()),
      ).thenAnswer((_) async => <Event>[]);

      // Default: no authors blocked
      when(
        () => mockBlocklistRepository.shouldFilterFromFeeds(any()),
      ).thenReturn(false);
      when(() => mockBlocklistRepository.hasMutedUs(any())).thenReturn(false);
      when(() => mockBlocklistRepository.hasBlockedUs(any())).thenReturn(false);
      when(
        () => mockVideoEventService.shouldHideVideo(any()),
      ).thenReturn(false);
    });

    tearDown(() async {
      await relayStatusController.close();
    });

    Widget buildSubject({String videoId = 'test_video_id'}) {
      return testMaterialApp(
        mockNostrService: mockNostrClient,
        additionalOverrides: [
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
          contentBlocklistRepositoryProvider.overrideWithValue(
            mockBlocklistRepository,
          ),
          followRepositoryProvider.overrideWithValue(mockFollowRepository),
          videosRepositoryProvider.overrideWithValue(mockVideosRepository),
        ],
        home: VideoDetailScreen(
          videoId: videoId,
          videoFeedBuilder: (_) =>
              const SizedBox(key: Key('video-feed-placeholder')),
        ),
      );
    }

    group('loading state', () {
      testWidgets('renders $CircularProgressIndicator while fetching video', (
        tester,
      ) async {
        // fetchVideoWithStatsForRouteId stays pending
        final completer = Completer<VideoEvent?>();
        when(
          () => mockVideosRepository.fetchVideoWithStatsForRouteId(any()),
        ).thenAnswer((_) => completer.future);

        await tester.pumpWidget(buildSubject());

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });
    });

    group('video found', () {
      testWidgets(
        'renders player once fetchVideoWithStatsForRouteId resolves',
        (tester) async {
          final video = createTestVideoEvent(
            id: 'test_video_id',
            pubkey: 'test_pubkey',
            title: 'Deep Link Video',
          );

          when(
            () => mockVideosRepository.fetchVideoWithStatsForRouteId(
              'test_video_id',
            ),
          ).thenAnswer((_) async => video);

          await tester.pumpWidget(buildSubject());
          await tester.pump();

          expect(
            find.byKey(const Key('video-feed-placeholder')),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'stats are hydrated before player renders (regression #3768)',
        (tester) async {
          // Simulate a video returned with loop counts already populated
          // by fetchVideoWithStatsForRouteId — this is the contract we pin.
          final videoWithStats =
              createTestVideoEvent(
                id: 'test_video_id',
                pubkey: 'test_pubkey',
                title: 'Notif Video',
              ).copyWith(
                originalLoops: 99,
                rawTags: const {'loops': '99', 'views': '1234'},
              );

          VideoEvent? capturedVideo;
          when(
            () => mockVideosRepository.fetchVideoWithStatsForRouteId(
              'test_video_id',
            ),
          ).thenAnswer((_) async => videoWithStats);

          await tester.pumpWidget(
            testMaterialApp(
              mockNostrService: mockNostrClient,
              additionalOverrides: [
                videoEventServiceProvider.overrideWithValue(
                  mockVideoEventService,
                ),
                contentBlocklistRepositoryProvider.overrideWithValue(
                  mockBlocklistRepository,
                ),
                followRepositoryProvider.overrideWithValue(
                  mockFollowRepository,
                ),
                videosRepositoryProvider.overrideWithValue(
                  mockVideosRepository,
                ),
              ],
              home: VideoDetailScreen(
                videoId: 'test_video_id',
                videoFeedBuilder: (video) {
                  capturedVideo = video;
                  return const SizedBox(key: Key('video-feed-placeholder'));
                },
              ),
            ),
          );
          await tester.pump();

          expect(
            find.byKey(const Key('video-feed-placeholder')),
            findsOneWidget,
          );
          // The video passed to the builder must already have hydrated stats.
          expect(capturedVideo?.originalLoops, equals(99));
          expect(capturedVideo?.rawTags['loops'], equals('99'));
        },
      );

      testWidgets('reloads when the route videoId changes', (tester) async {
        final firstVideo = createTestVideoEvent(
          id: 'first_video_id',
          pubkey: 'first_pubkey',
          title: 'First Video',
        );
        final secondVideo = createTestVideoEvent(
          id: 'second_video_id',
          pubkey: 'second_pubkey',
          title: 'Second Video',
        );

        when(
          () => mockVideosRepository.fetchVideoWithStatsForRouteId(
            'first_video_id',
          ),
        ).thenAnswer((_) async => firstVideo);
        when(
          () => mockVideosRepository.fetchVideoWithStatsForRouteId(
            'second_video_id',
          ),
        ).thenAnswer((_) async => secondVideo);

        VideoEvent? capturedVideo;

        await tester.pumpWidget(
          testMaterialApp(
            mockNostrService: mockNostrClient,
            additionalOverrides: [
              videoEventServiceProvider.overrideWithValue(
                mockVideoEventService,
              ),
              contentBlocklistRepositoryProvider.overrideWithValue(
                mockBlocklistRepository,
              ),
              followRepositoryProvider.overrideWithValue(
                mockFollowRepository,
              ),
              videosRepositoryProvider.overrideWithValue(
                mockVideosRepository,
              ),
            ],
            home: VideoDetailScreen(
              videoId: 'first_video_id',
              videoFeedBuilder: (video) {
                capturedVideo = video;
                return const SizedBox(key: Key('video-feed-placeholder'));
              },
            ),
          ),
        );
        await tester.pump();

        expect(capturedVideo?.id, equals('first_video_id'));

        await tester.pumpWidget(
          testMaterialApp(
            mockNostrService: mockNostrClient,
            additionalOverrides: [
              videoEventServiceProvider.overrideWithValue(
                mockVideoEventService,
              ),
              contentBlocklistRepositoryProvider.overrideWithValue(
                mockBlocklistRepository,
              ),
              followRepositoryProvider.overrideWithValue(
                mockFollowRepository,
              ),
              videosRepositoryProvider.overrideWithValue(
                mockVideosRepository,
              ),
            ],
            home: VideoDetailScreen(
              videoId: 'second_video_id',
              videoFeedBuilder: (video) {
                capturedVideo = video;
                return const SizedBox(key: Key('video-feed-placeholder'));
              },
            ),
          ),
        );
        await tester.pump();

        expect(capturedVideo?.id, equals('second_video_id'));
      });
    });

    group('video not found', () {
      testWidgets(
        'renders error when fetchVideoWithStatsForRouteId returns null',
        (tester) async {
          when(
            () => mockVideosRepository.fetchVideoWithStatsForRouteId(any()),
          ).thenAnswer((_) async => null);

          await tester.pumpWidget(buildSubject());
          await tester.pump();

          expect(find.text('Video not found'), findsOneWidget);
          expect(find.byIcon(Icons.error_outline), findsOneWidget);
          expect(find.bySemanticsLabel('Close video player'), findsOneWidget);
        },
      );

      testWidgets(
        'retries once when relays become ready after cold-start miss',
        (tester) async {
          var connectedRelayCount = 0;
          var isInitialized = false;
          when(() => mockNostrClient.isInitialized).thenAnswer(
            (_) => isInitialized,
          );
          when(() => mockNostrClient.connectedRelayCount).thenAnswer(
            (_) => connectedRelayCount,
          );

          final video = createTestVideoEvent(
            id: 'cold_start_video',
            pubkey: 'test_pubkey',
            title: 'Cold Start Video',
          );

          when(
            () => mockVideosRepository.fetchVideoWithStatsForRouteId(
              'cold_start_video',
            ),
          ).thenAnswer((_) async {
            if (!isInitialized || connectedRelayCount == 0) {
              return null;
            }
            return video;
          });

          await tester.pumpWidget(buildSubject(videoId: 'cold_start_video'));
          await tester.pump();

          expect(find.byType(CircularProgressIndicator), findsOneWidget);
          expect(find.text('Video not found'), findsNothing);

          isInitialized = true;
          connectedRelayCount = 1;
          relayStatusController.add({
            'wss://relay.divine.video': RelayConnectionStatus.connected(
              'wss://relay.divine.video',
            ),
          });

          await tester.pump();
          await tester.pump();

          expect(
            find.byKey(const Key('video-feed-placeholder')),
            findsOneWidget,
          );
        },
      );
    });

    group('fetch error', () {
      testWidgets(
        'renders error message when fetchVideoWithStatsForRouteId throws',
        (tester) async {
          when(
            () => mockVideosRepository.fetchVideoWithStatsForRouteId(any()),
          ).thenAnswer((_) => Future.error(Exception('Network error')));

          await tester.pumpWidget(buildSubject());
          await tester.pump();

          expect(find.textContaining('Failed to load video'), findsOneWidget);
          expect(find.byIcon(Icons.error_outline), findsOneWidget);
          expect(find.bySemanticsLabel('Close video player'), findsOneWidget);
        },
      );
    });

    group('explicit route block filtering', () {
      testWidgets('renders player for author filtered only from feeds', (
        tester,
      ) async {
        final video = createTestVideoEvent(
          id: 'blocked_video_id',
          pubkey: 'blocked_pubkey',
          title: 'Blocked Video',
          videoUrl: 'https://example.com/blocked.mp4',
        );

        when(
          () => mockVideosRepository.fetchVideoWithStatsForRouteId(
            'blocked_video_id',
          ),
        ).thenAnswer((_) async => video);
        when(
          () => mockBlocklistRepository.shouldFilterFromFeeds('blocked_pubkey'),
        ).thenReturn(true);

        await tester.pumpWidget(buildSubject(videoId: 'blocked_video_id'));
        await tester.pump();

        expect(find.text('This account is not available'), findsNothing);
        expect(find.byKey(const Key('video-feed-placeholder')), findsOneWidget);
      });

      testWidgets('renders player when author has blocked us', (
        tester,
      ) async {
        final video = createTestVideoEvent(
          id: 'blocked_video_id',
          pubkey: 'blocked_pubkey',
          title: 'Blocked Video',
          videoUrl: 'https://example.com/blocked.mp4',
        );

        when(
          () => mockVideosRepository.fetchVideoWithStatsForRouteId(
            'blocked_video_id',
          ),
        ).thenAnswer((_) async => video);
        when(
          () => mockBlocklistRepository.hasBlockedUs('blocked_pubkey'),
        ).thenReturn(true);

        await tester.pumpWidget(buildSubject(videoId: 'blocked_video_id'));
        await tester.pump();

        expect(find.text('This account is not available'), findsNothing);
        expect(find.byKey(const Key('video-feed-placeholder')), findsOneWidget);
      });

      testWidgets('renders exit button when video is hidden after load', (
        tester,
      ) async {
        final video = createTestVideoEvent(
          id: 'hidden_video_id',
          pubkey: 'hidden_pubkey',
          title: 'Hidden Video',
        );

        when(
          () => mockVideosRepository.fetchVideoWithStatsForRouteId(
            'hidden_video_id',
          ),
        ).thenAnswer((_) async => video);
        when(
          () => mockVideoEventService.shouldHideVideo(video),
        ).thenReturn(true);

        await tester.pumpWidget(buildSubject(videoId: 'hidden_video_id'));
        await tester.pump();

        expect(find.text('Video not found'), findsOneWidget);
        expect(find.bySemanticsLabel('Close video player'), findsOneWidget);
      });
    });
  });
}
