// ABOUTME: Tests for CurationService Nostr publishing functionality (kind 30005)
// ABOUTME: Verifies curation sets are correctly published to Nostr relays with
// ABOUTME: retry logic

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likes_repository/likes_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/curation_service.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/services/video_event_service.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockVideoEventService extends Mock implements VideoEventService {}

class _MockLikesRepository extends Mock implements LikesRepository {}

class _MockAuthService extends Mock implements AuthService {}

const _testPubkey =
    'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2';

/// Checks whether [tags] contains a tag matching [expected] by value equality.
bool _containsTag(List<dynamic> tags, List<String> expected) {
  return tags.any(
    (tag) =>
        tag is List &&
        tag.length == expected.length &&
        listEquals(tag.cast<String>(), expected),
  );
}

/// Creates a test Event with a valid 64-char hex pubkey.
Event _testEvent({
  int kind = 30005,
  List<List<String>> tags = const [],
  String content = '',
}) {
  return Event(_testPubkey, kind, tags, content);
}

void main() {
  setUpAll(() {
    registerFallbackValue(<Filter>[]);
    registerFallbackValue(_testEvent());
    registerFallbackValue(<String>[]);
    registerFallbackValue(<List<String>>[]);
  });

  group('CurationService Publishing', () {
    late CurationService curationService;
    late _MockNostrClient mockNostrService;
    late _MockVideoEventService mockVideoEventService;
    late _MockLikesRepository mockLikesRepository;
    late _MockAuthService mockAuthService;

    setUp(() {
      mockNostrService = _MockNostrClient();
      mockVideoEventService = _MockVideoEventService();
      mockLikesRepository = _MockLikesRepository();
      mockAuthService = _MockAuthService();

      // Mock authenticated user with a valid 64-char hex pubkey
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(() => mockAuthService.currentPublicKeyHex).thenReturn(_testPubkey);

      // Mock NostrClient
      when(
        () => mockNostrService.connectedRelays,
      ).thenReturn(['wss://relay1.example.com']);
      when(
        () => mockNostrService.subscribe(any()),
      ).thenAnswer((_) => const Stream.empty());

      // Mock empty video events initially
      when(() => mockVideoEventService.discoveryVideos).thenReturn([]);

      // Mock getLikeCounts to return empty counts
      when(
        () => mockLikesRepository.getLikeCounts(any()),
      ).thenAnswer((_) async => {});

      // Mock createAndSignEvent to return a properly signed event
      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((invocation) async {
        final kind = invocation.namedArguments[#kind] as int;
        final content = invocation.namedArguments[#content] as String;
        final tags = invocation.namedArguments[#tags] as List<List<String>>;

        return Event(_testPubkey, kind, tags, content);
      });

      curationService = CurationService(
        nostrService: mockNostrService,
        videoEventService: mockVideoEventService,
        likesRepository: mockLikesRepository,
        authService: mockAuthService,
      );
    });

    group('buildCurationEvent', () {
      test('should create kind 30005 event with correct structure', () async {
        final event = await curationService.buildCurationEvent(
          id: 'test_curation_1',
          title: 'Test Curation',
          videoIds: ['video1', 'video2', 'video3'],
          description: 'A test curation set',
          imageUrl: 'https://example.com/image.jpg',
        );

        expect(event, isNotNull);
        expect(event!.kind, equals(30005));
        expect(_containsTag(event.tags, ['d', 'test_curation_1']), isTrue);
        expect(_containsTag(event.tags, ['title', 'Test Curation']), isTrue);
        expect(
          _containsTag(event.tags, ['description', 'A test curation set']),
          isTrue,
        );
        expect(
          _containsTag(event.tags, ['image', 'https://example.com/image.jpg']),
          isTrue,
        );

        // Verify video references as 'e' tags
        expect(_containsTag(event.tags, ['e', 'video1']), isTrue);
        expect(_containsTag(event.tags, ['e', 'video2']), isTrue);
        expect(_containsTag(event.tags, ['e', 'video3']), isTrue);

        // Content is description when provided
        expect(event.content, equals('A test curation set'));
      });

      test('should handle optional fields correctly', () async {
        final event = await curationService.buildCurationEvent(
          id: 'minimal_curation',
          title: 'Minimal Curation',
          videoIds: ['video1'],
        );

        expect(event, isNotNull);
        expect(event!.kind, equals(30005));
        expect(_containsTag(event.tags, ['d', 'minimal_curation']), isTrue);
        expect(_containsTag(event.tags, ['title', 'Minimal Curation']), isTrue);
        expect(_containsTag(event.tags, ['e', 'video1']), isTrue);

        // Optional tags should not be present
        expect(event.tags.where((tag) => tag[0] == 'description'), isEmpty);
        expect(event.tags.where((tag) => tag[0] == 'image'), isEmpty);

        // Content falls back to title when no description
        expect(event.content, equals('Minimal Curation'));
      });

      test('should handle empty video list', () async {
        final event = await curationService.buildCurationEvent(
          id: 'empty_curation',
          title: 'Empty Curation',
          videoIds: [],
        );

        expect(event, isNotNull);
        expect(event!.kind, equals(30005));
        expect(event.tags.where((tag) => tag[0] == 'e'), isEmpty);
      });

      test('should add client tag for attribution', () async {
        final event = await curationService.buildCurationEvent(
          id: 'test_curation',
          title: 'Test',
          videoIds: [],
        );

        expect(event, isNotNull);
        expect(_containsTag(event!.tags, ['client', 'diVine']), isTrue);
      });
    });

    group('publishCuration', () {
      test('should publish event to Nostr and return success', () async {
        when(() => mockNostrService.publishEvent(any())).thenAnswer(
          (_) async => _testEvent(
            tags: [
              ['d', 'test_id'],
            ],
            content: 'Test content',
          ),
        );

        final result = await curationService.publishCuration(
          id: 'test_curation',
          title: 'Test Curation',
          videoIds: ['video1', 'video2'],
          description: 'Test description',
        );

        expect(result.success, isTrue);
        expect(result.successCount, equals(1));
        expect(result.totalRelays, equals(1));
        expect(result.eventId, isNotNull);

        verify(() => mockNostrService.publishEvent(any())).called(1);
      });

      test('should handle complete failure gracefully', () async {
        // publishEvent returns null on failure
        when(
          () => mockNostrService.publishEvent(any()),
        ).thenAnswer((_) async => null);

        final result = await curationService.publishCuration(
          id: 'test_curation',
          title: 'Test',
          videoIds: [],
        );

        expect(result.success, isFalse);
        expect(result.successCount, equals(0));
        expect(result.errors, isNotEmpty);
        expect(result.errors.containsKey('publish'), isTrue);
      });

      test('should timeout after 5 seconds', () async {
        when(() => mockNostrService.publishEvent(any())).thenAnswer((_) async {
          await Future.delayed(const Duration(seconds: 10));
          return _testEvent();
        });

        final stopwatch = Stopwatch()..start();
        final result = await curationService.publishCuration(
          id: 'test_curation',
          title: 'Test',
          videoIds: [],
        );
        stopwatch.stop();

        // Allow some margin for test timing
        expect(stopwatch.elapsed.inSeconds, lessThan(7));
        expect(result.success, isFalse);
        expect(result.errors['timeout'], isNotNull);
      });

      test('should prevent duplicate concurrent publishes', () async {
        final completer = Completer<Event?>();
        when(
          () => mockNostrService.publishEvent(any()),
        ).thenAnswer((_) => completer.future);

        // Start first publish (will block on completer)
        final firstPublish = curationService.publishCuration(
          id: 'rapid_curation',
          title: 'Test',
          videoIds: [],
        );

        // Allow async code to start
        await Future<void>.delayed(const Duration(milliseconds: 10));

        // Second publish of the same ID should be rejected as duplicate
        final secondResult = await curationService.publishCuration(
          id: 'rapid_curation',
          title: 'Test',
          videoIds: [],
        );

        expect(secondResult.success, isFalse);
        expect(secondResult.errors.containsKey('duplicate'), isTrue);

        // Complete the first publish
        completer.complete(_testEvent());
        final firstResult = await firstPublish;
        expect(firstResult.success, isTrue);
      });
    });

    group('Local Persistence', () {
      test('should mark curation as published locally after success', () async {
        when(
          () => mockNostrService.publishEvent(any()),
        ).thenAnswer((_) async => _testEvent());

        await curationService.publishCuration(
          id: 'test_curation',
          title: 'Test',
          videoIds: [],
        );

        final publishStatus = curationService.getCurationPublishStatus(
          'test_curation',
        );
        expect(publishStatus.isPublished, isTrue);
        expect(publishStatus.lastPublishedAt, isNotNull);
        expect(publishStatus.isPublishing, isFalse);
      });

      test('should track failed publish attempts', () async {
        // publishEvent returns null on failure
        when(
          () => mockNostrService.publishEvent(any()),
        ).thenAnswer((_) async => null);

        await curationService.publishCuration(
          id: 'failed_curation',
          title: 'Test',
          videoIds: [],
        );

        final publishStatus = curationService.getCurationPublishStatus(
          'failed_curation',
        );
        expect(publishStatus.isPublished, isFalse);
        expect(publishStatus.failedAttempts, greaterThan(0));
        expect(publishStatus.lastFailureReason, isNotNull);
      });

      test('should return default status for unknown curation', () {
        final status = curationService.getCurationPublishStatus(
          'unknown_curation',
        );
        expect(status.isPublished, isFalse);
        expect(status.isPublishing, isFalse);
        expect(status.failedAttempts, equals(0));
      });
    });

    group('Background Retry Worker', () {
      test('should use exponential backoff timing', () async {
        final delay1 = curationService.getRetryDelay(1);
        final delay2 = curationService.getRetryDelay(2);
        final delay3 = curationService.getRetryDelay(3);

        // Delays should increase exponentially (2^n seconds)
        expect(delay1.inSeconds, equals(2)); // 2^1
        expect(delay2.inSeconds, equals(4)); // 2^2
        expect(delay3.inSeconds, equals(8)); // 2^3

        expect(delay2.inSeconds, greaterThan(delay1.inSeconds));
        expect(delay3.inSeconds, greaterThan(delay2.inSeconds));
      });

      test('should cap retry delay at a reasonable maximum', () {
        // getRetryDelay clamps attemptCount to 0-10
        final maxDelay = curationService.getRetryDelay(100);
        expect(maxDelay.inSeconds, equals(1024)); // 2^10
      });

      test('should coalesce rapid updates to same curation', () async {
        when(
          () => mockNostrService.publishEvent(any()),
        ).thenAnswer((_) async => _testEvent());

        // Publishing same curation multiple times rapidly: first goes through,
        // rest are rejected as duplicate while first is in-flight
        final futures = <Future<dynamic>>[];
        for (var i = 0; i < 5; i++) {
          futures.add(
            curationService.publishCuration(
              id: 'rapid_curation',
              title: 'Test $i',
              videoIds: [],
            ),
          );
        }
        await Future.wait(futures);

        // Only the first call should actually publish
        verify(() => mockNostrService.publishEvent(any())).called(1);
      });
    });

    group('Publishing Status UI', () {
      test('should report "Publishing..." status during publish', () async {
        final completer = Completer<Event?>();
        when(
          () => mockNostrService.publishEvent(any()),
        ).thenAnswer((_) => completer.future);

        final publishFuture = curationService.publishCuration(
          id: 'publishing_curation',
          title: 'Test',
          videoIds: [],
        );

        // Wait for async code to start
        await Future<void>.delayed(const Duration(milliseconds: 10));

        final status = curationService.getCurationPublishStatus(
          'publishing_curation',
        );
        expect(status.isPublishing, isTrue);
        expect(status.statusText, equals('Publishing...'));

        // Complete the publish
        completer.complete(_testEvent());
        await publishFuture;

        final finalStatus = curationService.getCurationPublishStatus(
          'publishing_curation',
        );
        expect(finalStatus.isPublishing, isFalse);
        expect(finalStatus.isPublished, isTrue);
        expect(finalStatus.statusText, contains('Published'));
      });

      test('should show error status for failed publishes', () async {
        // publishEvent returns null on failure
        when(
          () => mockNostrService.publishEvent(any()),
        ).thenAnswer((_) async => null);

        await curationService.publishCuration(
          id: 'error_curation',
          title: 'Test',
          videoIds: [],
        );

        final status = curationService.getCurationPublishStatus(
          'error_curation',
        );
        expect(status.statusText, contains('Error'));
        expect(status.isError, isTrue);
      });
    });
  });
}
