// ABOUTME: Unit tests for VideoLinkPreviewCubit.
// ABOUTME: Tests cache hit, relay fetch, d-tag fallback, and not-found paths.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/screens/inbox/conversation/widgets/video_link_preview_cubit.dart';
import 'package:openvine/services/video_event_service.dart';

class _MockVideoEventService extends Mock implements VideoEventService {}

class _MockNostrClient extends Mock implements NostrClient {}

void main() {
  setUpAll(() {
    registerFallbackValue(<Filter>[]);
  });

  group(VideoLinkPreviewCubit, () {
    late _MockVideoEventService mockVideoEventService;
    late _MockNostrClient mockNostrClient;

    final testVideo = VideoEvent(
      id:
          '0123456789abcdef0123456789abcdef'
          '0123456789abcdef0123456789abcdef',
      pubkey:
          'abcdef0123456789abcdef0123456789'
          'abcdef0123456789abcdef0123456789',
      createdAt: 1757385263,
      content: 'Test',
      timestamp: DateTime.fromMillisecondsSinceEpoch(1757385263 * 1000),
      title: 'My Cool Video',
    );

    setUp(() {
      mockVideoEventService = _MockVideoEventService();
      mockNostrClient = _MockNostrClient();

      // Default stubs: nothing in cache, nothing from relay.
      when(() => mockVideoEventService.getVideoById(any())).thenReturn(null);
      when(
        () => mockVideoEventService.getVideoEventByVineId(any()),
      ).thenReturn(null);
      when(
        () => mockNostrClient.fetchEventById(any()),
      ).thenAnswer((_) async => null);
      when(
        () => mockNostrClient.queryEvents(any()),
      ).thenAnswer((_) async => <Event>[]);
    });

    VideoLinkPreviewCubit createCubit({String stableId = 'test-id'}) =>
        VideoLinkPreviewCubit(
          videoStableId: stableId,
          videoEventService: mockVideoEventService,
          nostrClient: mockNostrClient,
        );

    group('cache hit', () {
      blocTest<VideoLinkPreviewCubit, VideoLinkPreviewState>(
        'emits $VideoLinkPreviewResolved when found by event ID',
        setUp: () {
          when(
            () => mockVideoEventService.getVideoById('test-id'),
          ).thenReturn(testVideo);
        },
        build: createCubit,
        expect: () => [
          isA<VideoLinkPreviewResolved>().having(
            (s) => s.video.id,
            'video.id',
            testVideo.id,
          ),
        ],
        verify: (_) {
          verifyNever(() => mockNostrClient.fetchEventById(any()));
        },
      );

      blocTest<VideoLinkPreviewCubit, VideoLinkPreviewState>(
        'emits $VideoLinkPreviewResolved when found by vine ID (d-tag)',
        setUp: () {
          when(
            () => mockVideoEventService.getVideoEventByVineId('vine-tag'),
          ).thenReturn(testVideo);
        },
        build: () => createCubit(stableId: 'vine-tag'),
        expect: () => [
          isA<VideoLinkPreviewResolved>().having(
            (s) => s.video.id,
            'video.id',
            testVideo.id,
          ),
        ],
        verify: (_) {
          verifyNever(() => mockNostrClient.fetchEventById(any()));
        },
      );
    });

    group('relay fetch', () {
      blocTest<VideoLinkPreviewCubit, VideoLinkPreviewState>(
        'emits $VideoLinkPreviewResolved when relay returns event by ID',
        setUp: () {
          when(() => mockNostrClient.fetchEventById('test-id')).thenAnswer(
            (_) async => Event.fromJson({
              'id': testVideo.id,
              'pubkey': testVideo.pubkey,
              'created_at': testVideo.createdAt,
              'kind': 34236,
              'tags': <List<String>>[],
              'content': '',
              'sig': '0' * 128,
            }),
          );
        },
        build: createCubit,
        expect: () => [isA<VideoLinkPreviewResolved>()],
      );

      blocTest<VideoLinkPreviewCubit, VideoLinkPreviewState>(
        'emits $VideoLinkPreviewResolved when relay returns event by d-tag',
        setUp: () {
          when(() => mockNostrClient.queryEvents(any())).thenAnswer(
            (_) async => [
              Event.fromJson({
                'id': testVideo.id,
                'pubkey': testVideo.pubkey,
                'created_at': testVideo.createdAt,
                'kind': 34236,
                'tags': <List<String>>[],
                'content': '',
                'sig': '0' * 128,
              }),
            ],
          );
        },
        build: createCubit,
        expect: () => [isA<VideoLinkPreviewResolved>()],
      );

      blocTest<VideoLinkPreviewCubit, VideoLinkPreviewState>(
        'queries invite d-tag with creator and kind when provided',
        build: () => VideoLinkPreviewCubit(
          videoStableId: 'skate-loop',
          authorPubkey: testVideo.pubkey,
          videoKind: 34235,
          videoEventService: mockVideoEventService,
          nostrClient: mockNostrClient,
        ),
        expect: () => [isA<VideoLinkPreviewNotFound>()],
        verify: (_) {
          final captured =
              verify(
                    () => mockNostrClient.queryEvents(captureAny()),
                  ).captured.single
                  as List<Filter>;
          final filter = captured.single;
          expect(filter.kinds, [34235]);
          expect(filter.authors, [testVideo.pubkey]);
          expect(filter.d, ['skate-loop']);
        },
      );
    });

    group('not found', () {
      blocTest<VideoLinkPreviewCubit, VideoLinkPreviewState>(
        'emits $VideoLinkPreviewNotFound when cache and relay return nothing',
        build: createCubit,
        expect: () => [isA<VideoLinkPreviewNotFound>()],
      );

      blocTest<VideoLinkPreviewCubit, VideoLinkPreviewState>(
        'emits $VideoLinkPreviewNotFound when relay fetch throws',
        setUp: () {
          when(
            () => mockNostrClient.fetchEventById(any()),
          ).thenThrow(Exception('network error'));
        },
        build: createCubit,
        expect: () => [isA<VideoLinkPreviewNotFound>()],
      );
    });

    group('close during in-flight resolve', () {
      test('does not emit or throw when closed mid relay fetch', () async {
        final completer = Completer<Event?>();
        when(
          () => mockNostrClient.fetchEventById(any()),
        ).thenAnswer((_) => completer.future);

        final cubit = createCubit();
        // Let _resolve run past the cache miss to the awaited fetch.
        await pumpEventQueue();
        expect(cubit.state, isA<VideoLinkPreviewLoading>());

        // Close while the relay fetch is still in flight.
        await cubit.close();

        // Completing drives the post-await not-found path; without the
        // isClosed guard this emits on the closed cubit and throws StateError.
        completer.complete(null);
        await pumpEventQueue();

        expect(cubit.state, isA<VideoLinkPreviewLoading>());
      });
    });
  });
}
