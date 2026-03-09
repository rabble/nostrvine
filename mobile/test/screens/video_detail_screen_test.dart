// ABOUTME: Widget tests for VideoDetailScreen deep link video display
// ABOUTME: Verifies correct video is shown and error/blocked states handled

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/video_detail_screen.dart';
import 'package:openvine/services/content_blocklist_service.dart';
import 'package:openvine/services/video_event_service.dart';

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
    late MockUserProfileService mockUserProfileService;

    setUp(() {
      mockVideoEventService = _MockVideoEventService();
      mockNostrClient = _MockNostrClient();
      mockBlocklistService = _MockContentBlocklistService();
      mockUserProfileService = createMockUserProfileService();

      // Stub configuredRelays (needed by analyticsApiService provider)
      when(() => mockNostrClient.configuredRelays).thenReturn(<String>[]);
      when(() => mockNostrClient.publicKey).thenReturn('');
      when(() => mockNostrClient.isInitialized).thenReturn(true);
      when(() => mockNostrClient.hasKeys).thenReturn(false);
      when(() => mockNostrClient.connectedRelayCount).thenReturn(1);
      when(() => mockNostrClient.subscribe(any())).thenAnswer(
        (_) => const Stream<Event>.empty(),
      );
      when(
        () => mockNostrClient.queryEvents(any()),
      ).thenAnswer((_) async => <Event>[]);

      // Default: no authors blocked
      when(
        () => mockBlocklistService.shouldFilterFromFeeds(any()),
      ).thenReturn(false);
    });

    Widget buildSubject({String videoId = 'test_video_id'}) {
      return testMaterialApp(
        mockNostrService: mockNostrClient,
        additionalOverrides: [
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
          contentBlocklistServiceProvider.overrideWithValue(
            mockBlocklistService,
          ),
          followRepositoryProvider.overrideWithValue(null),
        ],
        mockUserProfileService: mockUserProfileService,
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
        'renders placeholder feed with cached video',
        (tester) async {
          final video = createTestVideoEvent(
            id: 'test_video_id',
            pubkey: 'test_pubkey',
            title: 'Deep Link Video',
          );

          when(
            () => mockVideoEventService.getVideoById('test_video_id'),
          ).thenReturn(video);

          await tester.pumpWidget(buildSubject());
          await tester.pump();

          expect(
            find.byKey(const Key('video-feed-placeholder')),
            findsOneWidget,
          );
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
        expect(find.byKey(const Key('video-feed-placeholder')), findsNothing);
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

        expect(find.byType(DiVineAppBarIconButton), findsOneWidget);
      });
    });
  });
}
