// ABOUTME: Unit tests for ViewEventPublisher (Kind 22236 ephemeral view events)
// ABOUTME: Tests self-view exclusion, vineId fallback, auth checks, and tag
// ABOUTME: construction

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
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
        return invocation.positionalArguments[0] as Event;
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

      test('returns false when end <= start', () async {
        final result = await publisher.publishViewEvent(
          video: createTestVideoEvent(pubkey: creatorPubkey),
          startSeconds: 5,
          endSeconds: 5,
        );

        expect(result, isFalse);
        verifyNever(() => mockNostr.publishEvent(any()));
      });

      test('returns false when watch time less than 1 second', () async {
        final result = await publisher.publishViewEvent(
          video: createTestVideoEvent(pubkey: creatorPubkey),
          startSeconds: 0,
          endSeconds: 0,
        );

        expect(result, isFalse);
        verifyNever(() => mockNostr.publishEvent(any()));
      });

      test('returns false for self-views', () async {
        final result = await publisher.publishViewEvent(
          video: createTestVideoEvent(pubkey: viewerPubkey),
          startSeconds: 0,
          endSeconds: 5,
        );

        expect(result, isFalse);
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

        // Check client
        final clientTag = tags.firstWhere((t) => t[0] == 'client');
        expect(clientTag[1], contains('divine-mobile'));
      });

      test('falls back to event ID when vineId is null', () async {
        final video = createTestVideoEvent(
          id: 'event_id_fallback',
          pubkey: creatorPubkey,
        );

        await publisher.publishViewEvent(
          video: video,
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
        // When vineId is null, should fall back to event ID
        expect(aTag[1], equals('34236:$creatorPubkey:event_id_fallback'));
      });

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

      test('returns false when publishEvent returns null', () async {
        when(() => mockNostr.publishEvent(any())).thenAnswer((_) async => null);

        final result = await publisher.publishViewEvent(
          video: createTestVideoEvent(pubkey: creatorPubkey),
          startSeconds: 0,
          endSeconds: 5,
        );

        expect(result, isFalse);
      });

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
            return invocation.positionalArguments[0] as Event;
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
      test('includes loops tag when loopCount > 0', () async {
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
          loopCount: 5,
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
        expect(loopsTag[1], equals('5'));
      });

      test('omits loops tag when loopCount is 0', () async {
        final video = createTestVideoEvent(
          id: 'no_loop_video_id',
          pubkey: creatorPubkey,
        );

        await publisher.publishViewEvent(
          video: video,
          startSeconds: 0,
          endSeconds: 10,
          loopCount: 0,
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
      test('returns false for self-views', () async {
        final result = await publisher.publishViewEventWithSegments(
          video: createTestVideoEvent(pubkey: viewerPubkey),
          segments: [(0, 5), (10, 15)],
        );

        expect(result, isFalse);
        verifyNever(() => mockNostr.publishEvent(any()));
      });

      test('returns false when all segments are invalid', () async {
        final result = await publisher.publishViewEventWithSegments(
          video: createTestVideoEvent(pubkey: creatorPubkey),
          segments: [(5, 5), (10, 9)],
        );

        expect(result, isFalse);
        verifyNever(() => mockNostr.publishEvent(any()));
      });

      test('filters out invalid segments', () async {
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
        // Should only have 2 valid segments (0-5 and 10-15), not 5-5
        expect(viewedTags, hasLength(2));
      });

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
