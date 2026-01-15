// ABOUTME: Tests for CurationService Nostr publishing functionality (kind 30005)
// ABOUTME: Verifies curation sets are correctly published to Nostr relays with retry logic

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/curation_service.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:likes_repository/likes_repository.dart';

import 'curation_publish_test.mocks.dart';

@GenerateMocks([NostrClient, VideoEventService, LikesRepository, AuthService])
void main() {
  group('CurationService Publishing', () {
    late CurationService curationService;
    late MockNostrClient mockNostrService;
    late MockVideoEventService mockVideoEventService;
    late MockLikesRepository mockLikesRepository;
    late MockAuthService mockAuthService;

    setUp(() {
      mockNostrService = MockNostrClient();
      mockVideoEventService = MockVideoEventService();
      mockLikesRepository = MockLikesRepository();
      mockAuthService = MockAuthService();

      // Mock authenticated user with a valid 64-char hex pubkey
      when(mockAuthService.isAuthenticated).thenReturn(true);
      when(mockAuthService.currentPublicKeyHex).thenReturn(
        'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2',
      );

      // Mock empty video events initially
      when(mockVideoEventService.discoveryVideos).thenReturn([]);

      // Mock getLikeCounts to return empty counts (replaced getCachedLikeCount)
      when(mockLikesRepository.getLikeCounts(any)).thenAnswer((_) async => {});

      // Mock createAndSignEvent to return a properly signed event with captured tags
      when(
        mockAuthService.createAndSignEvent(
          kind: anyNamed('kind'),
          content: anyNamed('content'),
          tags: anyNamed('tags'),
        ),
      ).thenAnswer((invocation) async {
        final kind = invocation.namedArguments[#kind] as int;
        final content = invocation.namedArguments[#content] as String;
        final tags = invocation.namedArguments[#tags] as List<List<String>>;

        return Event(
          'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2',
          kind,
          tags,
          content,
        );
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
        // When: Building a curation event
        final event = await curationService.buildCurationEvent(
          id: 'test_curation_1',
          title: 'Test Curation',
          videoIds: ['video1', 'video2', 'video3'],
          description: 'A test curation set',
          imageUrl: 'https://example.com/image.jpg',
        );

        // Then: Event should be created and signed
        expect(event, isNotNull);

        // Event should have correct kind and tags
        expect(event!.kind, equals(30005));
        expect(event.tags, contains(['d', 'test_curation_1']));
        expect(event.tags, contains(['title', 'Test Curation']));
        expect(event.tags, contains(['description', 'A test curation set']));
        expect(
          event.tags,
          contains(['image', 'https://example.com/image.jpg']),
        );

        // Verify video references as 'e' tags
        expect(event.tags, contains(['e', 'video1']));
        expect(event.tags, contains(['e', 'video2']));
        expect(event.tags, contains(['e', 'video3']));

        // Verify content contains description
        expect(event.content, equals('A test curation set'));
        // TODO(any): Fix and enable this test
      }, skip: true);

      test('should handle optional fields correctly', () async {
        // When: Building event without optional fields
        final event = await curationService.buildCurationEvent(
          id: 'minimal_curation',
          title: 'Minimal Curation',
          videoIds: ['video1'],
        );

        // Then: Should be created
        expect(event, isNotNull);

        // Should only have required tags
        expect(event!.kind, equals(30005));
        expect(event.tags, contains(['d', 'minimal_curation']));
        expect(event.tags, contains(['title', 'Minimal Curation']));
        expect(event.tags, contains(['e', 'video1']));

        // Optional tags should not be present
        expect(event.tags.where((tag) => tag[0] == 'description'), isEmpty);
        expect(event.tags.where((tag) => tag[0] == 'image'), isEmpty);
        // TODO(any): Fix and enable this test
      }, skip: true);

      test('should handle empty video list', () async {
        // When: Building event with no videos
        final event = await curationService.buildCurationEvent(
          id: 'empty_curation',
          title: 'Empty Curation',
          videoIds: [],
        );

        // Then: Should be created
        expect(event, isNotNull);

        // Should create event without video tags
        expect(event!.kind, equals(30005));
        expect(event.tags.where((tag) => tag[0] == 'e'), isEmpty);
      });

      test('should add client tag for attribution', () async {
        // When: Building any curation event
        final event = await curationService.buildCurationEvent(
          id: 'test_curation',
          title: 'Test',
          videoIds: [],
        );

        // Then: Should be created
        expect(event, isNotNull);

        // Should include client tag
        expect(event!.tags, contains(['client', 'diVine']));
        // TODO(any): Fix and enable this test
      }, skip: true);
    });

    group('publishCuration', () {
      test('should publish event to Nostr and return success', () async {
        // Given: Mock successful broadcast
        final mockEvent = Event('test_pubkey', 30005, [
          ['d', 'test_id'],
        ], 'Test content');
        when(
          mockNostrService.publishEvent(any),
        ).thenAnswer((_) async => mockEvent);

        // When: Publishing a curation
        final result = await curationService.publishCuration(
          id: 'test_curation',
          title: 'Test Curation',
          videoIds: ['video1', 'video2'],
          description: 'Test description',
        );

        // Then: Should return success
        expect(result.success, isTrue);
        expect(result.successCount, equals(2));
        expect(result.totalRelays, equals(3));
        expect(result.eventId, isNotNull);

        // Verify broadcastEvent was called
        verify(mockNostrService.publishEvent(any)).called(1);
        // TODO(any): Fix and enable this test
      }, skip: true);

      test('should handle complete failure gracefully', () async {
        // Given: Mock failed broadcast
        // publishEvent returns null on failure
        when(mockNostrService.publishEvent(any)).thenAnswer((_) async => null);

        // When: Publishing a curation
        final result = await curationService.publishCuration(
          id: 'test_curation',
          title: 'Test',
          videoIds: [],
        );

        // Then: Should return failure
        expect(result.success, isFalse);
        expect(result.successCount, equals(0));
        expect(result.errors.length, equals(3));
        // TODO(any): Fix and enable this test
      }, skip: true);

      test('should timeout after 5 seconds', () async {
        // Given: Mock slow broadcast
        when(mockNostrService.publishEvent(any)).thenAnswer((_) async {
          await Future.delayed(const Duration(seconds: 10));
          return Event('test', 30005, [], '');
        });

        // When: Publishing with timeout
        final stopwatch = Stopwatch()..start();
        final result = await curationService.publishCuration(
          id: 'test_curation',
          title: 'Test',
          videoIds: [],
        );
        stopwatch.stop();

        // Then: Should timeout and fail
        expect(stopwatch.elapsed.inSeconds, lessThan(7)); // Allow some margin
        expect(result.success, isFalse);
        expect(result.errors['timeout'], isNotNull);
      });

      test('should handle partial relay success', () async {
        // Given: Mock partial success
        when(
          mockNostrService.publishEvent(any),
        ).thenAnswer((_) async => Event('test', 30005, [], ''));

        // When: Publishing
        final result = await curationService.publishCuration(
          id: 'test_curation',
          title: 'Test',
          videoIds: [],
        );

        // Then: Should be marked as success if at least one relay succeeded
        expect(result.success, isTrue);
        expect(result.successCount, equals(1));
        expect(result.failedRelays, contains('relay2'));
        expect(result.failedRelays, contains('relay3'));
        // TODO(any): Fix and enable this test
      }, skip: true);
    });

    group('Local Persistence', () {
      test('should mark curation as published locally after success', () async {
        // Given: Mock successful publish
        when(
          mockNostrService.publishEvent(any),
        ).thenAnswer((_) async => Event('test', 30005, [], ''));

        // When: Publishing curation
        await curationService.publishCuration(
          id: 'test_curation',
          title: 'Test',
          videoIds: [],
        );

        // Then: Should be marked as published
        final publishStatus = curationService.getCurationPublishStatus(
          'test_curation',
        );
        expect(publishStatus.isPublished, isTrue);
        expect(publishStatus.lastPublishedAt, isNotNull);
        expect(publishStatus.publishedEventId, isNotNull);
        // TODO(any): Fix and enable this test
      }, skip: true);

      test('should track failed publish attempts', () async {
        // Given: Mock failed publish - publishEvent returns null on failure
        when(mockNostrService.publishEvent(any)).thenAnswer((_) async => null);

        // When: Publishing fails
        await curationService.publishCuration(
          id: 'failed_curation',
          title: 'Test',
          videoIds: [],
        );

        // Then: Should track failed attempt
        final publishStatus = curationService.getCurationPublishStatus(
          'failed_curation',
        );
        expect(publishStatus.isPublished, isFalse);
        expect(publishStatus.failedAttempts, greaterThan(0));
        expect(publishStatus.lastFailureReason, isNotNull);
      });

      test('should persist publish status across service restarts', () async {
        // Given: Published curation
        when(
          mockNostrService.publishEvent(any),
        ).thenAnswer((_) async => Event('test', 30005, [], ''));

        await curationService.publishCuration(
          id: 'persistent_curation',
          title: 'Test',
          videoIds: [],
        );

        // When: Creating new service instance
        final newService = CurationService(
          nostrService: mockNostrService,
          videoEventService: mockVideoEventService,
          likesRepository: mockLikesRepository,
          authService: mockAuthService,
        );

        // Then: Should retain publish status
        final publishStatus = newService.getCurationPublishStatus(
          'persistent_curation',
        );
        expect(publishStatus.isPublished, isTrue);
        // TODO(any): Fix and enable this test
      }, skip: true);
    });

    group('Background Retry Worker', () {
      test(
        'should retry unpublished curations with exponential backoff',
        () async {
          // Given: Failed initial publish - publishEvent returns null on failure
          when(
            mockNostrService.publishEvent(any),
          ).thenAnswer((_) async => null);

          await curationService.publishCuration(
            id: 'retry_curation',
            title: 'Test',
            videoIds: [],
          );

          // Mock successful retry - publishEvent returns the event on success
          when(
            mockNostrService.publishEvent(any),
          ).thenAnswer((_) async => Event('test', 30005, [], ''));

          // When: Background worker runs
          await curationService.retryUnpublishedCurations();

          // Then: Should successfully publish on retry
          final publishStatus = curationService.getCurationPublishStatus(
            'retry_curation',
          );
          expect(publishStatus.isPublished, isTrue);
        },
        // TODO(any): Fix and enable this test
        skip: true,
      );

      test('should stop retrying after max attempts', () async {
        // Given: Persistent failures
        // publishEvent returns null on failure
        when(mockNostrService.publishEvent(any)).thenAnswer((_) async => null);

        // When: Retrying multiple times
        for (var i = 0; i < 10; i++) {
          await curationService.retryUnpublishedCurations();
        }

        // Then: Should stop retrying after max attempts
        final publishStatus = curationService.getCurationPublishStatus(
          'max_retry_curation',
        );
        expect(publishStatus.failedAttempts, lessThanOrEqualTo(5));
        expect(publishStatus.shouldRetry, isFalse);
        // TODO(any): Fix and enable this test
      }, skip: true);

      test('should use exponential backoff timing', () async {
        // When: Getting retry delay for different attempt counts
        final delay1 = curationService.getRetryDelay(1);
        final delay2 = curationService.getRetryDelay(2);
        final delay3 = curationService.getRetryDelay(3);

        // Then: Delays should increase exponentially
        expect(delay2.inSeconds, greaterThan(delay1.inSeconds));
        expect(delay3.inSeconds, greaterThan(delay2.inSeconds));

        // Verify exponential growth (approx 2^n seconds)
        expect(delay1.inSeconds, closeTo(2, 1)); // ~2s
        expect(delay2.inSeconds, closeTo(4, 2)); // ~4s
        expect(delay3.inSeconds, closeTo(8, 3)); // ~8s
      });

      test('should coalesce rapid updates to same curation', () async {
        // Given: Mock successful broadcast
        when(
          mockNostrService.publishEvent(any),
        ).thenAnswer((_) async => Event('test', 30005, [], ''));

        // When: Publishing same curation multiple times rapidly
        final futures = <Future>[];
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

        // Then: Should coalesce into single publish (or very few)
        verify(mockNostrService.publishEvent(any)).called(lessThanOrEqualTo(2));
      });
    });

    group('Publishing Status UI', () {
      test('should report "Publishing..." status during publish', () async {
        // Given: Slow broadcast simulation
        final completer = Completer<Event?>();
        when(
          mockNostrService.publishEvent(any),
        ).thenAnswer((_) => completer.future);

        // When: Starting publish
        final publishFuture = curationService.publishCuration(
          id: 'publishing_curation',
          title: 'Test',
          videoIds: [],
        );

        // Wait a moment for async code to start
        await Future.delayed(const Duration(milliseconds: 10));

        // Then: Should show publishing status
        final status = curationService.getCurationPublishStatus(
          'publishing_curation',
        );
        expect(status.isPublishing, isTrue);
        expect(status.statusText, equals('Publishing...'));

        // Complete the publish
        completer.complete(Event('test', 30005, [], ''));
        await publishFuture;

        // Should now show published
        final finalStatus = curationService.getCurationPublishStatus(
          'publishing_curation',
        );
        expect(finalStatus.isPublishing, isFalse);
        expect(finalStatus.statusText, equals('Published'));
        // TODO(any): Fix and enable this test
      }, skip: true);

      test('should show relay success count in status', () async {
        // Given: Partial success
        when(
          mockNostrService.publishEvent(any),
        ).thenAnswer((_) async => Event('test', 30005, [], ''));

        // When: Publishing
        await curationService.publishCuration(
          id: 'partial_curation',
          title: 'Test',
          videoIds: [],
        );

        // Then: Status should show relay count
        final status = curationService.getCurationPublishStatus(
          'partial_curation',
        );
        expect(status.statusText, contains('2/5'));
        // TODO(any): Fix and enable this test
      }, skip: true);

      test('should show error status for failed publishes', () async {
        // Given: Failed publish
        // publishEvent returns null on failure
        when(mockNostrService.publishEvent(any)).thenAnswer((_) async => null);

        // When: Publishing fails
        await curationService.publishCuration(
          id: 'error_curation',
          title: 'Test',
          videoIds: [],
        );

        // Then: Should show error status
        final status = curationService.getCurationPublishStatus(
          'error_curation',
        );
        expect(status.statusText, contains('Error'));
        expect(status.isError, isTrue);
      });
    });
  });
}
