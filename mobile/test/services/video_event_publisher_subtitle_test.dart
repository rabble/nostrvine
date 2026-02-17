// ABOUTME: Tests for VideoEventPublisher.republishWithSubtitles method.
// ABOUTME: Verifies correct tag construction and event publishing.

import 'package:collection/collection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' hide NIP71VideoKinds;
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/constants/nip71_migration.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/upload_manager.dart';
import 'package:openvine/services/video_event_publisher.dart';
import 'package:openvine/services/video_event_service.dart';

class _MockUploadManager extends Mock implements UploadManager {}

class _MockNostrClient extends Mock implements NostrClient {}

class _MockAuthService extends Mock implements AuthService {}

class _MockVideoEventService extends Mock implements VideoEventService {}

// Fake fallback values for mocktail any() matchers
class _FakeEvent extends Fake implements Event {}

class _FakeVideoEvent extends Fake implements VideoEvent {}

const _deepEquals = DeepCollectionEquality();

/// Checks whether [tags] contains a tag that deeply equals [expected].
bool _containsTag(List<List<String>> tags, List<String> expected) {
  return tags.any((t) => _deepEquals.equals(t, expected));
}

void main() {
  late _MockUploadManager mockUploadManager;
  late _MockNostrClient mockNostrClient;
  late _MockAuthService mockAuthService;
  late _MockVideoEventService mockVideoEventService;
  late VideoEventPublisher publisher;

  setUpAll(() {
    registerFallbackValue(_FakeEvent());
    registerFallbackValue(_FakeVideoEvent());
  });

  setUp(() {
    mockUploadManager = _MockUploadManager();
    mockNostrClient = _MockNostrClient();
    mockAuthService = _MockAuthService();
    mockVideoEventService = _MockVideoEventService();

    publisher = VideoEventPublisher(
      uploadManager: mockUploadManager,
      nostrService: mockNostrClient,
      authService: mockAuthService,
      videoEventService: mockVideoEventService,
    );

    // Stub NostrClient properties used by _publishEventToNostr
    when(() => mockNostrClient.isInitialized).thenReturn(true);
    when(() => mockNostrClient.configuredRelayCount).thenReturn(1);
    when(() => mockNostrClient.connectedRelayCount).thenReturn(1);
    when(
      () => mockNostrClient.configuredRelays,
    ).thenReturn(['wss://relay.divine.video']);
    when(
      () => mockNostrClient.connectedRelays,
    ).thenReturn(['wss://relay.divine.video']);
  });

  group('republishWithSubtitles', () {
    final testPubkey = 'a' * 64;
    final existingTags = <List<String>>[
      ['d', 'test-vine-id'],
      ['imeta', 'url https://cdn.example.com/video.mp4', 'm video/mp4'],
      ['title', 'Test Video'],
      ['t', 'test'],
      ['client', 'diVine'],
    ];

    final existingEvent = VideoEvent(
      id: 'b' * 64,
      pubkey: testPubkey,
      createdAt: 1700000000,
      content: 'Test video description',
      timestamp: DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000),
      title: 'Test Video',
      vineId: 'test-vine-id',
      nostrEventTags: existingTags,
    );

    final textTrackRef = '34236:$testPubkey:subtitle-event-id';

    Event createSignedEvent(List<List<String>> tags) {
      return Event(
        testPubkey,
        NIP71VideoKinds.getPreferredAddressableKind(),
        tags,
        existingEvent.content,
        createdAt: 1700000001,
      );
    }

    test(
      'creates event with original tags plus text-track tag and publishes',
      () async {
        late List<List<String>> capturedTags;

        when(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((invocation) async {
          capturedTags = invocation.namedArguments[#tags] as List<List<String>>;
          return createSignedEvent(capturedTags);
        });

        when(
          () => mockNostrClient.publishEvent(any()),
        ).thenAnswer((_) async => _FakeEvent());

        when(() => mockVideoEventService.addVideoEvent(any())).thenReturn(null);

        final result = await publisher.republishWithSubtitles(
          existingEvent: existingEvent,
          textTrackRef: textTrackRef,
        );

        expect(result, isTrue);

        // Verify createAndSignEvent was called with correct kind
        verify(
          () => mockAuthService.createAndSignEvent(
            kind: NIP71VideoKinds.getPreferredAddressableKind(),
            content: existingEvent.content,
            tags: any(named: 'tags'),
          ),
        ).called(1);

        // Verify all original tags are preserved
        for (final tag in existingTags) {
          expect(
            _containsTag(capturedTags, tag),
            isTrue,
            reason: 'Missing original tag: $tag',
          );
        }

        // Verify text-track tag was added
        expect(
          _containsTag(capturedTags, [
            'text-track',
            textTrackRef,
            'wss://relay.divine.video',
            'captions',
            'en',
          ]),
          isTrue,
          reason: 'Missing text-track tag',
        );
      },
    );

    test('preserves all original tags from the event', () async {
      late List<List<String>> capturedTags;

      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((invocation) async {
        capturedTags = invocation.namedArguments[#tags] as List<List<String>>;
        return createSignedEvent(capturedTags);
      });

      when(
        () => mockNostrClient.publishEvent(any()),
      ).thenAnswer((_) async => _FakeEvent());

      when(() => mockVideoEventService.addVideoEvent(any())).thenReturn(null);

      await publisher.republishWithSubtitles(
        existingEvent: existingEvent,
        textTrackRef: textTrackRef,
      );

      // Every original tag should be present
      for (final tag in existingTags) {
        expect(
          _containsTag(capturedTags, tag),
          isTrue,
          reason: 'Missing original tag: $tag',
        );
      }
    });

    test('uses correct kind 34236', () async {
      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((_) async => createSignedEvent(existingTags));

      when(
        () => mockNostrClient.publishEvent(any()),
      ).thenAnswer((_) async => _FakeEvent());

      when(() => mockVideoEventService.addVideoEvent(any())).thenReturn(null);

      await publisher.republishWithSubtitles(
        existingEvent: existingEvent,
        textTrackRef: textTrackRef,
      );

      verify(
        () => mockAuthService.createAndSignEvent(
          kind: 34236,
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).called(1);
    });

    test('publishes signed event to relays', () async {
      final signedEvent = createSignedEvent(existingTags);

      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((_) async => signedEvent);

      when(
        () => mockNostrClient.publishEvent(any()),
      ).thenAnswer((_) async => _FakeEvent());

      when(() => mockVideoEventService.addVideoEvent(any())).thenReturn(null);

      await publisher.republishWithSubtitles(
        existingEvent: existingEvent,
        textTrackRef: textTrackRef,
      );

      verify(() => mockNostrClient.publishEvent(any())).called(1);
    });

    test('returns false when signing fails', () async {
      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((_) async => null);

      final result = await publisher.republishWithSubtitles(
        existingEvent: existingEvent,
        textTrackRef: textTrackRef,
      );

      expect(result, isFalse);
      verifyNever(() => mockNostrClient.publishEvent(any()));
    });

    test('does not duplicate text-track tag if one already exists', () async {
      final existingTextTrackTag = [
        'text-track',
        'old-ref',
        'wss://relay.divine.video',
        'captions',
        'en',
      ];
      final tagsWithTextTrack = <List<String>>[
        ...existingTags,
        existingTextTrackTag,
      ];

      final eventWithTextTrack = VideoEvent(
        id: 'c' * 64,
        pubkey: testPubkey,
        createdAt: 1700000000,
        content: 'Test video description',
        timestamp: DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000),
        title: 'Test Video',
        vineId: 'test-vine-id',
        nostrEventTags: tagsWithTextTrack,
        textTrackRef: 'old-ref',
      );

      late List<List<String>> capturedTags;

      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((invocation) async {
        capturedTags = invocation.namedArguments[#tags] as List<List<String>>;
        return createSignedEvent(capturedTags);
      });

      when(
        () => mockNostrClient.publishEvent(any()),
      ).thenAnswer((_) async => _FakeEvent());

      when(() => mockVideoEventService.addVideoEvent(any())).thenReturn(null);

      await publisher.republishWithSubtitles(
        existingEvent: eventWithTextTrack,
        textTrackRef: textTrackRef,
      );

      // Count text-track tags - should be exactly 1
      final textTrackTags = capturedTags
          .where((t) => t.first == 'text-track')
          .toList();
      expect(
        textTrackTags,
        hasLength(1),
        reason: 'Should have exactly one text-track tag',
      );

      // The new text-track tag should replace the old one
      expect(textTrackTags.first[1], equals(textTrackRef));
    });

    test('uses custom language parameter', () async {
      late List<List<String>> capturedTags;

      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((invocation) async {
        capturedTags = invocation.namedArguments[#tags] as List<List<String>>;
        return createSignedEvent(capturedTags);
      });

      when(
        () => mockNostrClient.publishEvent(any()),
      ).thenAnswer((_) async => _FakeEvent());

      when(() => mockVideoEventService.addVideoEvent(any())).thenReturn(null);

      await publisher.republishWithSubtitles(
        existingEvent: existingEvent,
        textTrackRef: textTrackRef,
        textTrackLang: 'es',
      );

      expect(
        _containsTag(capturedTags, [
          'text-track',
          textTrackRef,
          'wss://relay.divine.video',
          'captions',
          'es',
        ]),
        isTrue,
        reason: 'Missing text-track tag with language es',
      );
    });

    test('optimistically updates local cache', () async {
      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((_) async => createSignedEvent(existingTags));

      when(
        () => mockNostrClient.publishEvent(any()),
      ).thenAnswer((_) async => _FakeEvent());

      when(() => mockVideoEventService.addVideoEvent(any())).thenReturn(null);

      await publisher.republishWithSubtitles(
        existingEvent: existingEvent,
        textTrackRef: textTrackRef,
      );

      verify(() => mockVideoEventService.addVideoEvent(any())).called(1);
    });
  });
}
