// ABOUTME: Tests for NIP-09 content deletion service
// ABOUTME: Verifies kind 5 event creation, relay OK confirmation, and
// ABOUTME: local history bookkeeping.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/client_utils/keys.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/relay/publish_outcome.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/content_deletion_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockAuthService extends Mock implements AuthService {}

class _FakeEvent extends Fake implements Event {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeEvent());
    registerFallbackValue(const Duration(seconds: 1));
  });

  group(ContentDeletionService, () {
    late _MockNostrClient mockNostrService;
    late _MockAuthService mockAuthService;
    late ContentDeletionService service;
    late SharedPreferences prefs;
    late String testPublicKey;

    Event createTestEvent({
      required String pubkey,
      required int kind,
      required List<List<String>> tags,
      required String content,
    }) {
      final event = Event(
        pubkey,
        kind,
        tags,
        content,
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      event.id = 'test_event_${DateTime.now().millisecondsSinceEpoch}';
      event.sig = 'test_signature';
      return event;
    }

    PublishOutcome accepted(String eventId) => PublishOutcome(
      eventId: eventId,
      acceptedBy: const ['wss://relay.test'],
      rejectedBy: const {},
      noResponseFrom: const [],
    );

    PublishOutcome rejected(String eventId) => PublishOutcome(
      eventId: eventId,
      acceptedBy: const [],
      rejectedBy: const {'wss://relay.test': 'blocked: policy'},
      noResponseFrom: const [],
    );

    PublishOutcome timedOut(String eventId) => PublishOutcome(
      eventId: eventId,
      acceptedBy: const [],
      rejectedBy: const {},
      noResponseFrom: const ['wss://relay.test'],
    );

    setUp(() async {
      final testPrivateKey = generatePrivateKey();
      testPublicKey = getPublicKey(testPrivateKey);

      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();

      mockNostrService = _MockNostrClient();
      mockAuthService = _MockAuthService();

      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(() => mockAuthService.currentPublicKeyHex).thenReturn(testPublicKey);
      when(() => mockNostrService.isInitialized).thenReturn(true);

      service = ContentDeletionService(
        nostrService: mockNostrService,
        authService: mockAuthService,
        prefs: prefs,
      );

      await service.initialize();
    });

    VideoEvent createTestVideoEvent(String pubkey) {
      final event = Event(
        pubkey,
        34236,
        [
          ['title', 'Test Video'],
          ['url', 'https://example.com/video.mp4'],
        ],
        'Test video content',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      event.id = 'test_event_id_${DateTime.now().millisecondsSinceEpoch}';
      event.sig = 'test_signature';
      return VideoEvent.fromNostrEvent(event);
    }

    group('deleteContent', () {
      test(
        'creates a NIP-09 kind 5 delete event and saves it to history when at '
        'least one relay confirms',
        () async {
          final video = createTestVideoEvent(testPublicKey);
          final deleteEvent = createTestEvent(
            pubkey: testPublicKey,
            kind: 5,
            tags: [
              ['e', video.id],
              ['k', '34236'],
            ],
            content: 'CONTENT DELETION',
          );

          when(
            () => mockAuthService.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
            ),
          ).thenAnswer((_) async => deleteEvent);

          when(
            () => mockNostrService.publishEventAwaitOk(
              any(),
              timeout: any(named: 'timeout'),
            ),
          ).thenAnswer((_) async => accepted(deleteEvent.id));

          final result = await service.deleteContent(
            video: video,
            reason: 'Personal choice',
          );

          expect(result.success, isTrue);
          expect(result.deleteEventId, equals(deleteEvent.id));
          expect(service.hasBeenDeleted(video.id), isTrue);

          verify(
            () => mockAuthService.createAndSignEvent(
              kind: 5,
              content: any(named: 'content'),
              tags: any(named: 'tags'),
            ),
          ).called(1);
        },
      );

      test(
        'fails with relayRejected and does NOT save locally when every relay '
        'rejects the publish',
        () async {
          final video = createTestVideoEvent(testPublicKey);
          final deleteEvent = createTestEvent(
            pubkey: testPublicKey,
            kind: 5,
            tags: [
              ['e', video.id],
              ['k', '34236'],
            ],
            content: 'CONTENT DELETION',
          );

          when(
            () => mockAuthService.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
            ),
          ).thenAnswer((_) async => deleteEvent);

          when(
            () => mockNostrService.publishEventAwaitOk(
              any(),
              timeout: any(named: 'timeout'),
            ),
          ).thenAnswer((_) async => rejected(deleteEvent.id));

          final result = await service.deleteContent(
            video: video,
            reason: 'Personal choice',
          );

          expect(result.success, isFalse);
          expect(result.failureKind, equals(DeleteFailureKind.relayRejected));
          expect(result.error, contains('blocked: policy'));
          expect(service.hasBeenDeleted(video.id), isFalse);
          expect(service.deletionHistory, isEmpty);
        },
      );

      test('fails with relayRejected and does NOT save locally when no relay '
          'answers before timeout', () async {
        final video = createTestVideoEvent(testPublicKey);
        final deleteEvent = createTestEvent(
          pubkey: testPublicKey,
          kind: 5,
          tags: [
            ['e', video.id],
            ['k', '34236'],
          ],
          content: 'CONTENT DELETION',
        );

        when(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((_) async => deleteEvent);

        when(
          () => mockNostrService.publishEventAwaitOk(
            any(),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer((_) async => timedOut(deleteEvent.id));

        final result = await service.deleteContent(
          video: video,
          reason: 'Personal choice',
        );

        expect(result.success, isFalse);
        expect(result.failureKind, equals(DeleteFailureKind.relayRejected));
        expect(service.hasBeenDeleted(video.id), isFalse);
        expect(service.deletionHistory, isEmpty);
      });

      test(
        'includes the k tag with the original video kind per NIP-09',
        () async {
          final video = createTestVideoEvent(testPublicKey);
          final deleteEvent = createTestEvent(
            pubkey: testPublicKey,
            kind: 5,
            tags: [
              ['e', video.id],
              ['k', '34236'],
            ],
            content: 'CONTENT DELETION',
          );

          when(
            () => mockAuthService.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
            ),
          ).thenAnswer((_) async => deleteEvent);

          when(
            () => mockNostrService.publishEventAwaitOk(
              any(),
              timeout: any(named: 'timeout'),
            ),
          ).thenAnswer((_) async => accepted(deleteEvent.id));

          await service.deleteContent(video: video, reason: 'Personal choice');

          final captured = verify(
            () => mockAuthService.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: captureAny(named: 'tags'),
            ),
          ).captured;

          final tags = captured.first as List<List<String>>;
          final kTag = tags.firstWhere(
            (tag) => tag.isNotEmpty && tag[0] == 'k',
            orElse: () => <String>[],
          );

          expect(kTag, isNotEmpty);
          expect(kTag[1], equals('34236'));
        },
      );

      test('refuses with notOwner when deleting another user content before '
          'publishing', () async {
        final otherUserPubkey = getPublicKey(generatePrivateKey());
        final video = createTestVideoEvent(otherUserPubkey);

        final result = await service.deleteContent(
          video: video,
          reason: 'Personal choice',
        );

        expect(result.success, isFalse);
        expect(result.failureKind, equals(DeleteFailureKind.notOwner));

        verifyNever(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        );
        verifyNever(
          () => mockNostrService.publishEventAwaitOk(
            any(),
            timeout: any(named: 'timeout'),
          ),
        );
      });

      test(
        'fails with notInitialized when the service has not been initialized',
        () async {
          final uninitializedService = ContentDeletionService(
            nostrService: mockNostrService,
            authService: mockAuthService,
            prefs: prefs,
          );

          final video = createTestVideoEvent(testPublicKey);

          final result = await uninitializedService.deleteContent(
            video: video,
            reason: 'Test reason',
          );

          expect(result.success, isFalse);
          expect(result.failureKind, equals(DeleteFailureKind.notInitialized));
        },
      );
    });

    group('quickDelete', () {
      test('maps enum reason to the expected reason text', () async {
        final video = createTestVideoEvent(testPublicKey);
        final deleteEvent = createTestEvent(
          pubkey: testPublicKey,
          kind: 5,
          tags: [
            ['e', video.id],
            ['k', '34236'],
          ],
          content: 'CONTENT DELETION',
        );

        when(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((_) async => deleteEvent);

        when(
          () => mockNostrService.publishEventAwaitOk(
            any(),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer((_) async => accepted(deleteEvent.id));

        final result = await service.quickDelete(
          video: video,
          reason: DeleteReason.privacy,
        );

        expect(result.success, isTrue);
        final deletion = service.getDeletionForEvent(video.id);
        expect(deletion, isNotNull);
        expect(deletion!.reason, contains('Privacy concerns'));
      });
    });

    group('hasBeenDeleted', () {
      test('returns false for an id that was never deleted', () {
        expect(service.hasBeenDeleted('non_existent_event_id'), isFalse);
      });
    });

    group('getDeletionForEvent', () {
      test('returns null for an id that was never deleted', () {
        expect(service.getDeletionForEvent('non_existent_event_id'), isNull);
      });
    });
  });
}
