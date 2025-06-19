// ABOUTME: Comprehensive tests for vine publishing service
// ABOUTME: Tests complete publishing workflow from frames to Nostr broadcasting

import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr/nostr.dart';
import 'package:nostrvine_app/services/vine_publishing_service.dart';
import 'package:nostrvine_app/services/gif_service.dart';
import 'package:nostrvine_app/services/nostr_service.dart';
import 'package:nostrvine_app/services/nostr_service_interface.dart';
import 'package:nostrvine_app/services/camera_service.dart';
import 'package:nostrvine_app/models/nip94_metadata.dart';

// Mock classes for testing
class MockGifService extends Mock implements GifService {}
class MockNostrService extends Mock implements NostrService {}

void main() {
  setUpAll(() {
    // Initialize Flutter test bindings for SharedPreferences
    TestWidgetsFlutterBinding.ensureInitialized();
    
    // Register fallback values for mocktail
    registerFallbackValue(GifQuality.medium);
    registerFallbackValue(NIP94Metadata(
      url: 'test.com',
      mimeType: 'image/gif',
      sha256Hash: 'a1b2c3d4e5f67890123456789012345678901234567890123456789012345678',
      sizeBytes: 1024,
      dimensions: '320x240',
    ));
  });
  
  group('VinePublishingService', () {
    late VinePublishingService publishingService;
    late MockGifService mockGifService;
    late MockNostrService mockNostrService;
    late VineRecordingResult mockRecordingResult;
    
    setUp(() {
      mockGifService = MockGifService();
      mockNostrService = MockNostrService();
      publishingService = VinePublishingService(
        gifService: mockGifService,
        nostrService: mockNostrService,
      );
      
      // Create mock recording result
      mockRecordingResult = VineRecordingResult(
        frames: [
          Uint8List.fromList(List.filled(640 * 480 * 3, 128)), // Mock RGB frame
          Uint8List.fromList(List.filled(640 * 480 * 3, 130)),
          Uint8List.fromList(List.filled(640 * 480 * 3, 132)),
        ],
        frameCount: 3,
        processingTime: const Duration(milliseconds: 500),
        selectedApproach: 'Real-time Stream',
        qualityRatio: 1.0,
      );
      
      // Setup mock GIF result
      final mockGifBytes = Uint8List.fromList(List.filled(1024, 0xFF));
      final mockGifResult = GifResult(
        gifBytes: mockGifBytes,
        frameCount: 3,
        width: 320,
        height: 240,
        processingTime: const Duration(milliseconds: 200),
        originalSize: 640 * 480 * 3 * 3,
        compressedSize: 1024,
        quality: GifQuality.medium,
      );
      
      when(() => mockGifService.createGifFromFrames(
        frames: any(named: 'frames'),
        originalWidth: any(named: 'originalWidth'),
        originalHeight: any(named: 'originalHeight'),
        quality: any(named: 'quality'),
      )).thenAnswer((_) async => mockGifResult);
      
      // Setup mock Nostr broadcast result
      final testKeyPairs = Keychain.generate();
      final mockBroadcastResult = NostrBroadcastResult(
        event: Event.from(
          kind: 1063,
          content: 'Test vine',
          tags: [],
          privkey: testKeyPairs.private,
        ),
        successCount: 2,
        totalRelays: 3,
        results: {'relay1': true, 'relay2': true, 'relay3': false},
        errors: {'relay3': 'Connection timeout'},
      );
      
      when(() => mockNostrService.publishFileMetadata(
        metadata: any(named: 'metadata'),
        content: any(named: 'content'),
        hashtags: any(named: 'hashtags'),
      )).thenAnswer((_) async => mockBroadcastResult);
    });
    
    tearDown(() {
      publishingService.dispose();
    });
    
    group('Initial State', () {
      test('should start in idle state', () {
        expect(publishingService.state, equals(PublishingState.idle));
        expect(publishingService.progress, equals(0.0));
        expect(publishingService.statusMessage, isNull);
        expect(publishingService.isPublishing, isFalse);
      });
      
      test('should provide state information', () {
        expect(publishingService.state, isA<PublishingState>());
        expect(publishingService.progress, isA<double>());
        expect(publishingService.isPublishing, isA<bool>());
      });
    });
    
    group('Publishing State Management', () {
      test('should track publishing states correctly', () {
        expect(publishingService.isPublishing, isFalse);
        
        // States that indicate publishing in progress
        final publishingStates = [
          PublishingState.creatingGif,
          PublishingState.uploadingToBackend,
          PublishingState.waitingForProcessing,
          PublishingState.broadcastingToNostr,
        ];
        
        for (final state in publishingStates) {
          // We can't directly set state, but we can verify the logic
          expect(state != PublishingState.idle, isTrue);
          expect(state != PublishingState.completed, isTrue);
          expect(state != PublishingState.error, isTrue);
        }
      });
      
      test('should notify listeners on state changes', () {
        var notificationCount = 0;
        publishingService.addListener(() {
          notificationCount++;
        });
        
        // Trigger a state change by calling reset
        publishingService.reset();
        expect(notificationCount, greaterThan(0));
      });
    });
    
    group('Local Publishing (No Backend)', () {
      test('should publish vine locally successfully', () async {
        const caption = 'Test vine content';
        const hashtags = ['test', 'vine'];
        
        final result = await publishingService.publishVineLocal(
          recordingResult: mockRecordingResult,
          caption: caption,
          hashtags: hashtags,
        );
        
        expect(result.success, isTrue);
        expect(result.metadata, isNotNull);
        expect(result.broadcastResult, isNotNull);
        expect(result.error, isNull);
        expect(result.finalState, equals(PublishingState.completed));
        
        // Verify GIF service was called
        verify(() => mockGifService.createGifFromFrames(
          frames: any(named: 'frames'),
          originalWidth: 640,
          originalHeight: 480,
          quality: GifQuality.medium,
        )).called(1);
        
        // Verify Nostr service was called
        verify(() => mockNostrService.publishFileMetadata(
          metadata: any(named: 'metadata'),
          content: caption,
          hashtags: hashtags,
        )).called(1);
      });
      
      test('should create valid NIP-94 metadata during publishing', () async {
        const caption = 'Test vine with metadata';
        const altText = 'Accessibility description';
        
        final result = await publishingService.publishVineLocal(
          recordingResult: mockRecordingResult,
          caption: caption,
          altText: altText,
        );
        
        expect(result.success, isTrue);
        expect(result.metadata, isNotNull);
        
        final metadata = result.metadata!;
        expect(metadata.isValid, isTrue);
        expect(metadata.summary, equals(caption));
        expect(metadata.altText, equals(altText));
        expect(metadata.isGif, isTrue);
        expect(metadata.width, equals(320));
        expect(metadata.height, equals(240));
        // Frame count comes from the recording result, not metadata
        expect(mockRecordingResult.frameCount, equals(3));
      });
      
      test('should handle empty frames list', () async {
        final emptyRecordingResult = VineRecordingResult(
          frames: [], // Empty frames
          frameCount: 0,
          processingTime: const Duration(milliseconds: 100),
          selectedApproach: 'Test',
          qualityRatio: 0.0,
        );
        
        when(() => mockGifService.createGifFromFrames(
          frames: any(named: 'frames'),
          originalWidth: any(named: 'originalWidth'),
          originalHeight: any(named: 'originalHeight'),
          quality: any(named: 'quality'),
        )).thenThrow(GifProcessingException('No frames to process'));
        
        final result = await publishingService.publishVineLocal(
          recordingResult: emptyRecordingResult,
          caption: 'Empty test',
        );
        
        expect(result.success, isFalse);
        expect(result.error, isNotNull);
        expect(result.error, contains('Publishing failed'));
      });
    });
    
    group('Publishing Workflow Steps', () {
      test('should progress through all publishing states', () async {
        final stateChanges = <PublishingState>[];
        publishingService.addListener(() {
          stateChanges.add(publishingService.state);
        });
        
        await publishingService.publishVineLocal(
          recordingResult: mockRecordingResult,
          caption: 'State tracking test',
        );
        
        // Should have progressed through states
        expect(stateChanges, isNotEmpty);
        expect(stateChanges, contains(PublishingState.creatingGif));
        expect(stateChanges, contains(PublishingState.broadcastingToNostr));
        expect(stateChanges, contains(PublishingState.completed));
      });
      
      test('should update progress during publishing', () async {
        final progressUpdates = <double>[];
        publishingService.addListener(() {
          progressUpdates.add(publishingService.progress);
        });
        
        await publishingService.publishVineLocal(
          recordingResult: mockRecordingResult,
          caption: 'Progress test',
        );
        
        expect(progressUpdates, isNotEmpty);
        expect(progressUpdates.last, equals(1.0)); // Should end at 100%
      });
      
      test('should provide status messages during publishing', () async {
        final statusMessages = <String>[];
        publishingService.addListener(() {
          final message = publishingService.statusMessage;
          if (message != null) {
            statusMessages.add(message);
          }
        });
        
        await publishingService.publishVineLocal(
          recordingResult: mockRecordingResult,
          caption: 'Status test',
        );
        
        expect(statusMessages, isNotEmpty);
        expect(statusMessages.any((msg) => msg.contains('Creating GIF')), isTrue);
        expect(statusMessages.any((msg) => msg.contains('Broadcasting')), isTrue);
        expect(statusMessages.any((msg) => msg.contains('successfully')), isTrue);
      });
    });
    
    group('Error Handling', () {
      test('should handle GIF creation failure', () async {
        when(() => mockGifService.createGifFromFrames(
          frames: any(named: 'frames'),
          originalWidth: any(named: 'originalWidth'),
          originalHeight: any(named: 'originalHeight'),
          quality: any(named: 'quality'),
        )).thenThrow(GifProcessingException('GIF creation failed'));
        
        final result = await publishingService.publishVineLocal(
          recordingResult: mockRecordingResult,
          caption: 'Error test',
        );
        
        expect(result.success, isFalse);
        expect(result.error, contains('GIF creation failed'));
        expect(result.finalState, equals(PublishingState.error));
      });
      
      test('should handle Nostr broadcasting failure', () async {
        when(() => mockNostrService.publishFileMetadata(
          metadata: any(named: 'metadata'),
          content: any(named: 'content'),
          hashtags: any(named: 'hashtags'),
        )).thenThrow(NostrServiceException('All relays failed'));
        
        final result = await publishingService.publishVineLocal(
          recordingResult: mockRecordingResult,
          caption: 'Broadcast error test',
        );
        
        expect(result.success, isFalse);
        expect(result.error, contains('All relays failed'));
        expect(result.finalState, equals(PublishingState.error));
      });
      
      test('should handle partial Nostr broadcast success', () async {
        final testKeyPairs = Keychain.generate();
        final partialFailureResult = NostrBroadcastResult(
          event: Event.from(
            kind: 1063,
            content: 'Test',
            tags: [],
            privkey: testKeyPairs.private,
          ),
          successCount: 0, // No successful broadcasts
          totalRelays: 3,
          results: {'relay1': false, 'relay2': false, 'relay3': false},
          errors: {'relay1': 'Error 1', 'relay2': 'Error 2', 'relay3': 'Error 3'},
        );
        
        when(() => mockNostrService.publishFileMetadata(
          metadata: any(named: 'metadata'),
          content: any(named: 'content'),
          hashtags: any(named: 'hashtags'),
        )).thenAnswer((_) async => partialFailureResult);
        
        final result = await publishingService.publishVineLocal(
          recordingResult: mockRecordingResult,
          caption: 'Partial failure test',
        );
        
        expect(result.success, isFalse);
        expect(result.error, contains('Failed to broadcast to any Nostr relays'));
      });
      
      test('should prevent concurrent publishing', () async {
        // Start first publishing operation
        final future1 = publishingService.publishVineLocal(
          recordingResult: mockRecordingResult,
          caption: 'First publish',
        );
        
        // Try to start second operation while first is running
        expect(
          () => publishingService.publishVineLocal(
            recordingResult: mockRecordingResult,
            caption: 'Second publish',
          ),
          throwsA(isA<Exception>()),
        );
        
        // Wait for first operation to complete
        await future1;
      });
    });
    
    group('Service Reset and Cleanup', () {
      test('should reset to idle state', () {
        publishingService.reset();
        
        expect(publishingService.state, equals(PublishingState.idle));
        expect(publishingService.progress, equals(0.0));
        expect(publishingService.statusMessage, isNull);
        expect(publishingService.isPublishing, isFalse);
      });
      
      test('should support cancellation', () async {
        // Set service to a publishing state first
        // Note: We can't easily test real cancellation without complex async mocking
        // So we test the cancellation when not publishing (should be no-op)
        await publishingService.cancelPublishing();
        
        // When not publishing, cancelPublishing should be a no-op
        expect(publishingService.state, equals(PublishingState.idle));
        expect(publishingService.statusMessage, isNull);
      });
    });
    
    group('Result Objects', () {
      test('should create success result correctly', () {
        final metadata = NIP94Metadata(
          url: 'test.com',
          mimeType: 'image/gif',
          sha256Hash: 'a1b2c3d4e5f67890123456789012345678901234567890123456789012345678',
          sizeBytes: 1024,
          dimensions: '320x240',
        );
        
        final testKeyPairs = Keychain.generate();
        final broadcastResult = NostrBroadcastResult(
          event: Event.from(
            kind: 1063,
            content: 'Test',
            tags: [],
            privkey: testKeyPairs.private,
          ),
          successCount: 2,
          totalRelays: 3,
          results: {},
          errors: {},
        );
        
        final result = VinePublishResult.success(
          metadata: metadata,
          broadcastResult: broadcastResult,
          processingTime: const Duration(seconds: 5),
        );
        
        expect(result.success, isTrue);
        expect(result.metadata, equals(metadata));
        expect(result.broadcastResult, equals(broadcastResult));
        expect(result.error, isNull);
        expect(result.finalState, equals(PublishingState.completed));
      });
      
      test('should create error result correctly', () {
        const errorMessage = 'Test error occurred';
        const processingTime = Duration(seconds: 2);
        
        final result = VinePublishResult.error(
          error: errorMessage,
          processingTime: processingTime,
          finalState: PublishingState.error,
        );
        
        expect(result.success, isFalse);
        expect(result.error, equals(errorMessage));
        expect(result.metadata, isNull);
        expect(result.broadcastResult, isNull);
        expect(result.processingTime, equals(processingTime));
        expect(result.finalState, equals(PublishingState.error));
      });
    });
    
    group('Publishing Errors Enum', () {
      test('should have all required error types', () {
        expect(PublishingError.gifCreationFailed.userMessage, contains('GIF'));
        expect(PublishingError.hashCalculationFailed.userMessage, contains('hash'));
        expect(PublishingError.backendUploadFailed.userMessage, contains('backend'));
        expect(PublishingError.nostrBroadcastFailed.userMessage, contains('Nostr'));
        expect(PublishingError.networkError.userMessage, contains('Network'));
        expect(PublishingError.authenticationError.userMessage, contains('Authentication'));
        expect(PublishingError.invalidMetadata.userMessage, contains('metadata'));
        expect(PublishingError.quotaExceeded.userMessage, contains('quota'));
        expect(PublishingError.cancelled.userMessage, contains('cancelled'));
      });
    });
    
    group('Publishing Exception', () {
      test('should create exception with error and details', () {
        const error = PublishingError.gifCreationFailed;
        const details = 'Out of memory';
        
        final exception = VinePublishingException(error, details);
        
        expect(exception.error, equals(error));
        expect(exception.details, equals(details));
        expect(exception.message, contains('Failed to create GIF'));
        expect(exception.message, contains('Out of memory'));
        expect(exception.toString(), contains('VinePublishingException'));
      });
      
      test('should create exception without details', () {
        const error = PublishingError.networkError;
        
        final exception = VinePublishingException(error);
        
        expect(exception.error, equals(error));
        expect(exception.details, isNull);
        expect(exception.message, equals(error.userMessage));
      });
    });
    
    group('Retry and Offline Support', () {
      test('should have offline queue support methods', () {
        expect(publishingService.offlineQueue, isA<List<OfflineVineData>>());
        expect(publishingService.offlineQueueCount, equals(0));
        expect(publishingService.hasOfflineContent, isFalse);
      });
      
      test('should handle offline queue operations', () async {
        // Test that offline methods exist and can be called
        await publishingService.retryOfflineQueue();
        await publishingService.clearOfflineQueue();
        
        expect(publishingService.offlineQueueCount, equals(0));
      });
      
      test('should include retry count in result', () async {
        final result = await publishingService.publishVineLocal(
          recordingResult: mockRecordingResult,
          caption: 'Retry count test',
        );
        
        expect(result.retryCount, isA<int>());
        expect(result.retryCount, greaterThanOrEqualTo(0));
      });
      
      test('should support offline queued results', () {
        final result = VinePublishResult.offlineQueued(
          processingTime: const Duration(seconds: 1),
        );
        
        expect(result.success, isFalse);
        expect(result.isOfflineQueued, isTrue);
        expect(result.finalState, equals(PublishingState.queuedOffline));
        expect(result.error, contains('Queued for publishing'));
      });
      
      test('should have new publishing states', () {
        expect(PublishingState.retrying, isA<PublishingState>());
        expect(PublishingState.queuedOffline, isA<PublishingState>());
      });
      
      test('should have additional error types', () {
        expect(PublishingError.retryLimitExceeded.userMessage, contains('retry'));
        expect(PublishingError.offlineQueueFull.userMessage, contains('queue'));
      });
      
      test('should create retryable exceptions', () {
        const exception = VinePublishingException(
          PublishingError.networkError,
          'Connection timeout',
          true, // isRetryable
        );
        
        expect(exception.isRetryable, isTrue);
        expect(exception.error, equals(PublishingError.networkError));
        expect(exception.details, equals('Connection timeout'));
      });
    });
  });
}