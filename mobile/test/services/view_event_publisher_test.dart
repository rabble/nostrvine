// ABOUTME: Unit tests for ViewEventPublisher (Kind 22236 ephemeral view events)
// ABOUTME: Tests self-view publishing, addressable tags, auth checks, and tag
// ABOUTME: construction

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/models/view_event_drop_reason.dart';
import 'package:openvine/models/view_traffic_source.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/view_event_publisher.dart';

import '../test_data/video_test_data.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockAuthService extends Mock implements AuthService {}

class _FakeEvent extends Fake implements Event {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeEvent());
  });

  group(ViewEventPublisher, () {
    late _MockNostrClient mockNostr;
    late _MockAuthService mockAuth;
    late ViewEventPublisher publisher;

    const viewerPubkey =
        'viewer_pubkey_abcdef1234567890abcdef1234567890abcdef1234567890abcdef12345678';
    const creatorPubkey =
        'creator_pubkey_abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234';

    setUp(() {
      mockNostr = _MockNostrClient();
      mockAuth = _MockAuthService();

      when(() => mockAuth.isAuthenticated).thenReturn(true);
      when(() => mockAuth.currentPublicKeyHex).thenReturn(viewerPubkey);
      when(() => mockNostr.connectedRelays).thenReturn([]);

      when(
        () => mockAuth.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer(
        (_) async => Event.fromJson({
          'id': 'view_event_id',
          'pubkey': viewerPubkey,
          'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'kind': viewEventKind,
          'tags': [],
          'content': '',
          'sig': 'test_sig',
        }),
      );

      when(() => mockNostr.publishEvent(any())).thenAnswer((invocation) async {
        return PublishSuccess(
          event: invocation.positionalArguments[0] as Event,
        );
      });

      publisher = ViewEventPublisher(
        nostrService: mockNostr,
        authService: mockAuth,
      );
    });

    group('publishViewEvent', () {
      test('returns false when not authenticated', () async {
        when(() => mockAuth.isAuthenticated).thenReturn(false);

        final result = await publisher.publishViewEvent(
          video: createTestVideoEvent(pubkey: creatorPubkey),
          startSeconds: 0,
          endSeconds: 5,
        );

        expect(result, isFalse);
        verifyNever(() => mockNostr.publishEvent(any()));
      });

      test('returns false when end < start (inverted range)', () async {
        final result = await publisher.publishViewEvent(
          video: createTestVideoEvent(pubkey: creatorPubkey),
          startSeconds: 5,
          endSeconds: 3,
        );

        expect(result, isFalse);
        verifyNever(() => mockNostr.publishEvent(any()));
      });

      test(
        'view = playback start: zero-duration segment is valid',
        () async {
          final result = await publisher.publishViewEvent(
            video: createTestVideoEvent(pubkey: creatorPubkey),
            startSeconds: 0,
            endSeconds: 0,
          );

          expect(result, isTrue);
          verify(() => mockNostr.publishEvent(any())).called(1);
        },
      );

      test('publishes self-views with video reference tags', () async {
        final result = await publisher.publishViewEvent(
          video: createTestVideoEvent(
            id: 'self_view_event_id',
            pubkey: viewerPubkey,
            vineId: 'self_view_vine_id',
          ),
          startSeconds: 0,
          endSeconds: 5,
          source: ViewTrafficSource.profile,
        );

        expect(result, isTrue);
        final captured = verify(
          () => mockAuth.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: captureAny(named: 'tags'),
          ),
        ).captured;
        verify(() => mockNostr.publishEvent(any())).called(1);

        final tags = captured[0] as List<List<String>>;
        expect(
          tags.firstWhere((t) => t[0] == 'a')[1],
          equals('34236:$viewerPubkey:self_view_vine_id'),
        );
        expect(
          tags.firstWhere((t) => t[0] == 'e')[1],
          equals('self_view_event_id'),
        );
        expect(tags.firstWhere((t) => t[0] == 'viewed'), ['viewed', '0', '5']);
        expect(tags.firstWhere((t) => t[0] == 'source'), ['source', 'profile']);
      });

      test('returns false when video has no real d tag', () async {
        final result = await publisher.publishViewEvent(
          video: createTestVideoEvent(
            id: 'event_id_without_d',
            pubkey: creatorPubkey,
            vineId: 'legacy_vine_id',
            clearAddressableDTag: true,
          ),
          startSeconds: 0,
          endSeconds: 5,
        );

        expect(result, isFalse);
        verifyNever(
          () => mockAuth.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        );
        verifyNever(() => mockNostr.publishEvent(any()));
      });

      test('publishes event successfully', () async {
        final result = await publisher.publishViewEvent(
          video: createTestVideoEvent(pubkey: creatorPubkey),
          startSeconds: 0,
          endSeconds: 5,
          source: ViewTrafficSource.discoveryNew,
        );

        expect(result, isTrue);
        verify(() => mockNostr.publishEvent(any())).called(1);
      });

      test('includes correct tags with vineId', () async {
        final video = createTestVideoEvent(
          id: 'event_id_abc',
          pubkey: creatorPubkey,
          vineId: 'vine_d_tag',
        );

        await publisher.publishViewEvent(
          video: video,
          startSeconds: 0,
          endSeconds: 10,
          source: ViewTrafficSource.home,
        );

        final captured = verify(
          () => mockAuth.createAndSignEvent(
            kind: captureAny(named: 'kind'),
            content: captureAny(named: 'content'),
            tags: captureAny(named: 'tags'),
          ),
        ).captured;

        final kind = captured[0] as int;
        final tags = captured[2] as List<List<String>>;

        expect(kind, equals(viewEventKind));

        // Check a tag uses vineId as d-tag
        final aTag = tags.firstWhere((t) => t[0] == 'a');
        expect(aTag[1], equals('34236:$creatorPubkey:vine_d_tag'));

        // Check e tag uses event ID
        final eTag = tags.firstWhere((t) => t[0] == 'e');
        expect(eTag[1], equals('event_id_abc'));

        // Check viewed segment
        final viewedTag = tags.firstWhere((t) => t[0] == 'viewed');
        expect(viewedTag[1], equals('0'));
        expect(viewedTag[2], equals('10'));

        // Check source
        final sourceTag = tags.firstWhere((t) => t[0] == 'source');
        expect(sourceTag[1], equals('home'));

        // Client attribution is added centrally during signing/publish.
        expect(tags.where((t) => t[0] == 'client'), isEmpty);
      });

      test(
        'does not fall back to event ID when the real d tag is absent',
        () async {
          final video = createTestVideoEvent(
            id: 'event_id_fallback',
            pubkey: creatorPubkey,
            clearAddressableDTag: true,
          );

          final result = await publisher.publishViewEvent(
            video: video,
            startSeconds: 0,
            endSeconds: 5,
          );

          expect(result, isFalse);
          verifyNever(
            () => mockAuth.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
            ),
          );
        },
      );

      test('returns false when createAndSignEvent returns null', () async {
        when(
          () => mockAuth.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((_) async => null);

        final result = await publisher.publishViewEvent(
          video: createTestVideoEvent(pubkey: creatorPubkey),
          startSeconds: 0,
          endSeconds: 5,
        );

        expect(result, isFalse);
        verifyNever(() => mockNostr.publishEvent(any()));
      });

      test(
        'reports thrown signing errors as unexpected structural drops',
        () async {
          final drops =
              <({ViewEventDropReason reason, String videoId, String method})>[];
          publisher = ViewEventPublisher(
            nostrService: mockNostr,
            authService: mockAuth,
            onDrop:
                (reason, {required String videoId, required String method}) {
                  drops.add((reason: reason, videoId: videoId, method: method));
                },
          );
          when(
            () => mockAuth.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
            ),
          ).thenThrow(StateError('signer unavailable'));

          final result = await publisher.publishViewEvent(
            video: createTestVideoEvent(
              id: 'throwing_sign_video',
              pubkey: creatorPubkey,
              vineId: 'throwing_sign_d_tag',
            ),
            startSeconds: 0,
            endSeconds: 5,
          );

          expect(result, isFalse);
          expect(drops, [
            (
              reason: ViewEventDropReason.unexpectedError,
              videoId: 'throwing_sign_video',
              method: 'publishViewEvent',
            ),
          ]);
          verifyNever(() => mockNostr.publishEvent(any()));
        },
      );

      test(
        'returns false when publishEvent does not return PublishSuccess',
        () async {
          when(
            () => mockNostr.publishEvent(any()),
          ).thenAnswer((_) async => const PublishFailed());

          final result = await publisher.publishViewEvent(
            video: createTestVideoEvent(pubkey: creatorPubkey),
            startSeconds: 0,
            endSeconds: 5,
          );

          expect(result, isFalse);
        },
      );

      test('uses connected relay as relay hint when available', () async {
        when(
          () => mockNostr.connectedRelays,
        ).thenReturn(['wss://my-relay.example.com']);

        await publisher.publishViewEvent(
          video: createTestVideoEvent(pubkey: creatorPubkey),
          startSeconds: 0,
          endSeconds: 5,
        );

        final captured = verify(
          () => mockAuth.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: captureAny(named: 'tags'),
          ),
        ).captured;

        final tags = captured[0] as List<List<String>>;
        final aTag = tags.firstWhere((t) => t[0] == 'a');
        expect(aTag[2], equals('wss://my-relay.example.com'));
      });

      test('maps all traffic sources correctly', () async {
        const expectedStrings = {
          ViewTrafficSource.home: 'home',
          ViewTrafficSource.discoveryNew: 'discovery:new',
          ViewTrafficSource.discoveryClassic: 'discovery:classic',
          ViewTrafficSource.discoveryForYou: 'discovery:foryou',
          ViewTrafficSource.discoveryPopular: 'discovery:popular',
          ViewTrafficSource.discoveryFeatured: 'discovery:featured',
          ViewTrafficSource.profile: 'profile',
          ViewTrafficSource.share: 'share',
          ViewTrafficSource.search: 'search',
          ViewTrafficSource.unknown: 'unknown',
        };

        for (final source in ViewTrafficSource.values) {
          reset(mockAuth);
          reset(mockNostr);

          when(() => mockAuth.isAuthenticated).thenReturn(true);
          when(() => mockAuth.currentPublicKeyHex).thenReturn(viewerPubkey);
          when(() => mockNostr.connectedRelays).thenReturn([]);
          when(
            () => mockAuth.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
            ),
          ).thenAnswer(
            (_) async => Event.fromJson({
              'id': 'view_event_id',
              'pubkey': viewerPubkey,
              'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
              'kind': viewEventKind,
              'tags': [],
              'content': '',
              'sig': 'test_sig',
            }),
          );
          when(() => mockNostr.publishEvent(any())).thenAnswer((
            invocation,
          ) async {
            return PublishSuccess(
              event: invocation.positionalArguments[0] as Event,
            );
          });

          await publisher.publishViewEvent(
            video: createTestVideoEvent(pubkey: creatorPubkey),
            startSeconds: 0,
            endSeconds: 5,
            source: source,
          );

          final captured = verify(
            () => mockAuth.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: captureAny(named: 'tags'),
            ),
          ).captured;

          final tags = captured[0] as List<List<String>>;
          final sourceTag = tags.firstWhere((t) => t[0] == 'source');
          expect(sourceTag[1], equals(expectedStrings[source]));
        }
      });
      test(
        'includes loops tag when loopCount > 0 (fractional supported)',
        () async {
          final video = createTestVideoEvent(
            id: 'looped_video_id',
            pubkey: creatorPubkey,
            vineId: 'looped_vine_id',
          );

          await publisher.publishViewEvent(
            video: video,
            startSeconds: 0,
            endSeconds: 30,
            source: ViewTrafficSource.home,
            loopCount: 2.4,
          );

          final captured = verify(
            () => mockAuth.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: captureAny(named: 'tags'),
            ),
          ).captured;

          final tags = captured[0] as List<List<String>>;
          final loopsTag = tags.firstWhere((t) => t[0] == 'loops');
          expect(double.parse(loopsTag[1]), closeTo(2.4, 0.0001));
        },
      );

      test(
        'a partial pass reaches the tag as a fraction, not rounded',
        () async {
          final video = createTestVideoEvent(
            id: 'partial_pass_video_id',
            pubkey: creatorPubkey,
            vineId: 'partial_pass_vine_id',
          );

          // The median signed view event is 0.75 of a pass. Rounding or
          // flooring anywhere on the publish path turns that into 1 or 0, so
          // the value has to survive verbatim.
          await publisher.publishViewEvent(
            video: video,
            startSeconds: 0,
            endSeconds: 5,
            source: ViewTrafficSource.home,
            loopCount: 0.75,
          );

          final captured = verify(
            () => mockAuth.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: captureAny(named: 'tags'),
            ),
          ).captured;

          final tags = captured[0] as List<List<String>>;
          final loopsTag = tags.firstWhere((t) => t[0] == 'loops');
          expect(double.parse(loopsTag[1]), closeTo(0.75, 0.0001));
        },
      );

      test('omits loops tag when loopCount is 0', () async {
        final video = createTestVideoEvent(
          id: 'no_loop_video_id',
          pubkey: creatorPubkey,
        );

        await publisher.publishViewEvent(
          video: video,
          startSeconds: 0,
          endSeconds: 10,
          loopCount: 0.0,
        );

        final captured = verify(
          () => mockAuth.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: captureAny(named: 'tags'),
          ),
        ).captured;

        final tags = captured[0] as List<List<String>>;
        final loopsTags = tags.where((t) => t[0] == 'loops').toList();
        expect(loopsTags, isEmpty);
      });

      test('omits loops tag when loopCount is null', () async {
        final video = createTestVideoEvent(
          id: 'null_loop_video_id',
          pubkey: creatorPubkey,
        );

        await publisher.publishViewEvent(
          video: video,
          startSeconds: 0,
          endSeconds: 10,
        );

        final captured = verify(
          () => mockAuth.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: captureAny(named: 'tags'),
          ),
        ).captured;

        final tags = captured[0] as List<List<String>>;
        final loopsTags = tags.where((t) => t[0] == 'loops').toList();
        expect(loopsTags, isEmpty);
      });
    });

    group('publishViewEventWithSegments', () {
      test('publishes self-views with segments', () async {
        final result = await publisher.publishViewEventWithSegments(
          video: createTestVideoEvent(
            id: 'self_view_segments_event_id',
            pubkey: viewerPubkey,
            vineId: 'self_view_segments_vine_id',
          ),
          segments: [(0, 5), (10, 15)],
          source: ViewTrafficSource.discoveryForYou,
        );

        expect(result, isTrue);
        final captured = verify(
          () => mockAuth.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: captureAny(named: 'tags'),
          ),
        ).captured;
        verify(() => mockNostr.publishEvent(any())).called(1);

        final tags = captured[0] as List<List<String>>;
        expect(
          tags.firstWhere((t) => t[0] == 'a')[1],
          equals('34236:$viewerPubkey:self_view_segments_vine_id'),
        );
        expect(
          tags.firstWhere((t) => t[0] == 'e')[1],
          equals('self_view_segments_event_id'),
        );
        expect(tags.where((t) => t[0] == 'viewed'), [
          ['viewed', '0', '5'],
          ['viewed', '10', '15'],
        ]);
        expect(tags.firstWhere((t) => t[0] == 'source'), [
          'source',
          'discovery:foryou',
        ]);
      });

      test('returns false when all segments are inverted', () async {
        final result = await publisher.publishViewEventWithSegments(
          video: createTestVideoEvent(pubkey: creatorPubkey),
          segments: [(5, 3), (10, 9)],
        );

        expect(result, isFalse);
        verifyNever(() => mockNostr.publishEvent(any()));
      });

      test('returns false for segments when video has no real d tag', () async {
        final result = await publisher.publishViewEventWithSegments(
          video: createTestVideoEvent(
            id: 'event_id_without_d',
            pubkey: creatorPubkey,
            vineId: 'legacy_vine_id',
            clearAddressableDTag: true,
          ),
          segments: [(0, 5), (10, 15)],
        );

        expect(result, isFalse);
        verifyNever(
          () => mockAuth.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        );
        verifyNever(() => mockNostr.publishEvent(any()));
      });

      test(
        'view = playback start: zero-length segment (5,5) is valid view',
        () async {
          await publisher.publishViewEventWithSegments(
            video: createTestVideoEvent(pubkey: creatorPubkey),
            segments: [(0, 5), (5, 5), (10, 15)],
          );

          final captured = verify(
            () => mockAuth.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: captureAny(named: 'tags'),
            ),
          ).captured;

          final tags = captured[0] as List<List<String>>;
          final viewedTags = tags.where((t) => t[0] == 'viewed').toList();
          // All three are valid views per playback-start spec.
          expect(viewedTags, hasLength(3));
        },
      );

      test('publishes multiple viewed tags', () async {
        final result = await publisher.publishViewEventWithSegments(
          video: createTestVideoEvent(pubkey: creatorPubkey),
          segments: [(0, 5), (10, 20)],
          source: ViewTrafficSource.profile,
        );

        expect(result, isTrue);

        final captured = verify(
          () => mockAuth.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: captureAny(named: 'tags'),
          ),
        ).captured;

        final tags = captured[0] as List<List<String>>;
        final viewedTags = tags.where((t) => t[0] == 'viewed').toList();
        expect(viewedTags, hasLength(2));
        expect(viewedTags[0][1], equals('0'));
        expect(viewedTags[0][2], equals('5'));
        expect(viewedTags[1][1], equals('10'));
        expect(viewedTags[1][2], equals('20'));
      });
    });
  });
}
