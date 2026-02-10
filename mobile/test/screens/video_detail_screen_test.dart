// ABOUTME: Widget tests for VideoDetailScreen deep link video display
// ABOUTME: Verifies correct video is shown and error/blocked states handled

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/screens/video_detail_screen.dart';
import 'package:openvine/services/content_blocklist_service.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:pooled_video_player/pooled_video_player.dart';

import '../helpers/test_provider_overrides.dart';
import '../test_data/video_test_data.dart';

class _MockVideoEventService extends Mock implements VideoEventService {}

class _MockNostrClient extends Mock implements NostrClient {}

class _MockContentBlocklistService extends Mock
    implements ContentBlocklistService {}

void main() {
  group(VideoDetailScreen, () {
    late _MockVideoEventService mockVideoEventService;
    late _MockContentBlocklistService mockBlocklistService;
    late _MockNostrClient mockNostrClient;

    setUp(() async {
      await PlayerPool.init();

      mockVideoEventService = _MockVideoEventService();
      mockNostrClient = _MockNostrClient();
      mockBlocklistService = _MockContentBlocklistService();

      // Default: no authors blocked
      when(
        () => mockBlocklistService.shouldFilterFromFeeds(any()),
      ).thenReturn(false);
    });

    tearDown(() async {
      await PlayerPool.reset();
    });

    Widget buildSubject({String videoId = 'test_video_id'}) {
      return testMaterialApp(
        mockNostrService: mockNostrClient,
        additionalOverrides: [
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
          contentBlocklistServiceProvider.overrideWithValue(
            mockBlocklistService,
          ),
        ],
        home: VideoDetailScreen(videoId: videoId),
      );
    }

    group('loading state', () {
      testWidgets('renders $CircularProgressIndicator while fetching video', (
        tester,
      ) async {
        // Cache miss, Nostr fetch stays pending
        when(() => mockVideoEventService.getVideoById(any())).thenReturn(null);
        final completer = Completer<Event?>();
        when(
          () => mockNostrClient.fetchEventById(any()),
        ).thenAnswer((_) => completer.future);

        await tester.pumpWidget(buildSubject());

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });
    });

    group('video found in cache', () {
      testWidgets(
        'renders $PooledFullscreenVideoFeedScreen with cached video',
        (tester) async {
          final video = createTestVideoEvent(
            id: 'test_video_id',
            pubkey: 'test_pubkey',
            title: 'Deep Link Video',
            videoUrl: 'https://example.com/video.mp4',
          );

          when(
            () => mockVideoEventService.getVideoById('test_video_id'),
          ).thenReturn(video);

          await tester.pumpWidget(buildSubject());
          await tester.pump();

          expect(find.byType(PooledFullscreenVideoFeedScreen), findsOneWidget);
        },
      );
    });

    group('video not found', () {
      testWidgets('renders error when video not found in cache or Nostr', (
        tester,
      ) async {
        when(() => mockVideoEventService.getVideoById(any())).thenReturn(null);
        when(
          () => mockNostrClient.fetchEventById(any()),
        ).thenAnswer((_) async => null);

        await tester.pumpWidget(buildSubject());
        await tester.pump();

        expect(find.text('Video not found'), findsOneWidget);
        expect(find.byIcon(Icons.error_outline), findsOneWidget);
      });
    });

    group('fetch error', () {
      testWidgets('renders error message when Nostr fetch fails', (
        tester,
      ) async {
        when(() => mockVideoEventService.getVideoById(any())).thenReturn(null);
        when(
          () => mockNostrClient.fetchEventById(any()),
        ).thenAnswer((_) => Future<Event?>.error(Exception('Network error')));

        await tester.pumpWidget(buildSubject());
        await tester.pump();

        expect(find.textContaining('Failed to load video'), findsOneWidget);
        expect(find.byIcon(Icons.error_outline), findsOneWidget);
      });
    });

    group('blocked author', () {
      testWidgets('renders blocked message for filtered author', (
        tester,
      ) async {
        final video = createTestVideoEvent(
          id: 'blocked_video_id',
          pubkey: 'blocked_pubkey',
          title: 'Blocked Video',
          videoUrl: 'https://example.com/blocked.mp4',
        );

        when(
          () => mockVideoEventService.getVideoById('blocked_video_id'),
        ).thenReturn(video);
        when(
          () => mockBlocklistService.shouldFilterFromFeeds('blocked_pubkey'),
        ).thenReturn(true);

        await tester.pumpWidget(buildSubject(videoId: 'blocked_video_id'));
        await tester.pump();

        expect(find.text('This account is not available'), findsOneWidget);
        expect(find.byType(PooledFullscreenVideoFeedScreen), findsNothing);
      });

      testWidgets('renders back button for blocked author', (tester) async {
        final video = createTestVideoEvent(
          id: 'blocked_video_id',
          pubkey: 'blocked_pubkey',
          title: 'Blocked Video',
          videoUrl: 'https://example.com/blocked.mp4',
        );

        when(
          () => mockVideoEventService.getVideoById('blocked_video_id'),
        ).thenReturn(video);
        when(
          () => mockBlocklistService.shouldFilterFromFeeds('blocked_pubkey'),
        ).thenReturn(true);

        await tester.pumpWidget(buildSubject(videoId: 'blocked_video_id'));
        await tester.pump();

        expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      });
    });
  });
}
