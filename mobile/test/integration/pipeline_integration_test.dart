// ABOUTME: Integration tests for the complete video upload \u2192 processing \u2192 publishing pipeline
// ABOUTME: Tests real service interactions, state transitions, and error handling scenarios

import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:mocktail/mocktail.dart';
import 'package:http/http.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:nostrvine_app/services/upload_manager.dart';
import 'package:nostrvine_app/services/cloudinary_upload_service.dart';
import 'package:nostrvine_app/services/video_event_publisher.dart';
import 'package:nostrvine_app/services/api_service.dart';
import 'package:nostrvine_app/services/notification_service.dart';
import 'package:nostrvine_app/services/nostr_service_interface.dart';
import 'package:nostrvine_app/models/pending_upload.dart';
import 'package:nostrvine_app/models/ready_event_data.dart';
import 'package:nostr/nostr.dart';

// Mock classes
class MockHttpClient extends Mock implements http.Client {}
class MockResponse extends Mock implements http.Response {}
class MockNostrService extends Mock implements INostrService {}
class MockEvent extends Mock implements Event {}
class MockFile extends Mock implements File {}

/// Pipeline integration test suite
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  setUpAll(() async {
    // Initialize Hive for testing
    Hive.init('./test_hive');
    
    // Register adapters
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(UploadStatusAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(PendingUploadAdapter());
    }
    
    // Register fallback values for mocks
    registerFallbackValue(Uri.parse('https://example.com'));
    registerFallbackValue(<String, String>{});
    registerFallbackValue(UploadStatus.pending);
    registerFallbackValue(MockEvent());
  });

  tearDownAll(() async {
    await Hive.close();
  });

  group('Video Processing Pipeline Integration Tests', () {
    late UploadManager uploadManager;
    late CloudinaryUploadService cloudinaryService;
    late VideoEventPublisher videoEventPublisher;
    late ApiService apiService;
    late NotificationService notificationService;
    late MockHttpClient mockHttpClient;
    late MockNostrService mockNostrService;
    late Box<PendingUpload> uploadsBox;

    setUp(() async {
      // Clean up any existing test boxes
      try {
        await Hive.deleteBoxFromDisk('test_uploads');
      } catch (_) {}

      // Create fresh mock services
      mockHttpClient = MockHttpClient();
      mockNostrService = MockNostrService();
      
      // Initialize real services with mocked dependencies
      cloudinaryService = CloudinaryUploadService();
      apiService = ApiService(client: mockHttpClient);
      notificationService = NotificationService.instance;
      uploadManager = UploadManager(cloudinaryService: cloudinaryService);
      
      // Open test Hive box
      uploadsBox = await Hive.openBox<PendingUpload>('test_uploads');
      uploadManager = UploadManager(cloudinaryService: cloudinaryService);
      
      // Initialize upload manager with test box
      await uploadManager.initialize();
      
      // Setup VideoEventPublisher with mock dependencies
      videoEventPublisher = VideoEventPublisher(
        uploadManager: uploadManager,
        nostrService: mockNostrService,
        fetchReadyEvents: () => apiService.getReadyEvents(),
        cleanupRemoteEvent: (publicId) => apiService.cleanupRemoteEvent(publicId),
      );

      // Setup default mock behaviors
      when(() => mockNostrService.broadcastEvent(any()))
          .thenAnswer((_) async => NostrBroadcastResult(
            event: MockEvent(),
            successCount: 1,
            totalRelays: 1,
            results: {'relay1': true},
            errors: {},
          ));
    });

    tearDown(() async {
      videoEventPublisher.dispose();
      uploadManager.dispose();
      apiService.dispose();
      await uploadsBox.close();
      try {
        await Hive.deleteBoxFromDisk('test_uploads');
      } catch (_) {}
    });

    group('End-to-End Pipeline Flow', () {
      test('complete upload → processing → publishing pipeline should work', () async {
        // ARRANGE: Setup complete pipeline with real state transitions
        final testVideoFile = MockFile();
        when(() => testVideoFile.path).thenReturn('/tmp/test_video.mp4');
        when(() => testVideoFile.existsSync()).thenReturn(true);
        when(() => testVideoFile.readAsBytesSync()).thenReturn([1, 2, 3, 4]); // Minimal file content

        // Mock successful Cloudinary upload
        final cloudinaryResponse = MockResponse();
        when(() => cloudinaryResponse.statusCode).thenReturn(200);
        when(() => cloudinaryResponse.body).thenReturn(jsonEncode({
          'public_id': 'test-video-123',
          'secure_url': 'https://cloudinary.com/test-video-123.mp4',
          'bytes': 1024000,
          'width': 1920,
          'height': 1080,
          'duration': 6.5,
        }));
        
        when(() => mockHttpClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        )).thenAnswer((_) async => cloudinaryResponse);

        // Mock backend ready events API
        final readyEventResponse = MockResponse();
        when(() => readyEventResponse.statusCode).thenReturn(200);
        when(() => readyEventResponse.body).thenReturn(jsonEncode({
          'events': [{
            'public_id': 'test-video-123',
            'secure_url': 'https://cloudinary.com/test-video-123.mp4',
            'content_suggestion': 'Test video content',
            'tags': [['url', 'https://cloudinary.com/test-video-123.mp4']],
            'metadata': {'width': 1920, 'height': 1080},
            'processed_at': DateTime.now().toIso8601String(),
            'original_upload_id': 'will-be-set-by-test',
            'mime_type': 'video/mp4',
            'file_size': 1024000,
          }]
        }));

        when(() => mockHttpClient.get(any(), headers: any(named: 'headers')))
            .thenAnswer((_) async => readyEventResponse);

        // Mock successful cleanup
        final cleanupResponse = MockResponse();
        when(() => cleanupResponse.statusCode).thenReturn(200);
        when(() => mockHttpClient.delete(any(), headers: any(named: 'headers')))
            .thenAnswer((_) async => cleanupResponse);

        // ACT: Execute the complete pipeline
        
        // Step 1: Start upload
        print('🧪 TEST: Starting upload...');
        final upload = await uploadManager.startUpload(
          videoFile: testVideoFile,
          nostrPubkey: 'test-pubkey-123',
          title: 'Test Video',
          description: 'Integration test video',
          hashtags: ['test', 'integration'],
        );

        // Verify upload is in pending/uploading state initially
        expect(upload.status, UploadStatus.pending);
        
        // Wait for upload to process
        await Future.delayed(const Duration(milliseconds: 100));
        
        // Step 2: Simulate processing completion
        print('🧪 TEST: Simulating processing completion...');
        await uploadManager.markUploadReadyToPublish(upload.id, 'test-video-123');
        
        final updatedUpload = uploadManager.getUpload(upload.id);
        expect(updatedUpload?.status, UploadStatus.readyToPublish);
        expect(updatedUpload?.cloudinaryPublicId, 'test-video-123');

        // Step 3: Update backend response to include this upload's ID
        when(() => readyEventResponse.body).thenReturn(jsonEncode({
          'events': [{
            'public_id': 'test-video-123',
            'secure_url': 'https://cloudinary.com/test-video-123.mp4',
            'content_suggestion': 'Test video content',
            'tags': [['url', 'https://cloudinary.com/test-video-123.mp4']],
            'metadata': {'width': 1920, 'height': 1080},
            'processed_at': DateTime.now().toIso8601String(),
            'original_upload_id': upload.id, // Now matches our upload
            'mime_type': 'video/mp4',
            'file_size': 1024000,
          }]
        }));

        // Step 4: Initialize publisher and trigger background polling
        print('🧪 TEST: Starting background publisher...');
        await videoEventPublisher.initialize();
        
        // Force an immediate check instead of waiting for polling interval
        await videoEventPublisher.forceCheck();
        
        // Step 5: Verify the complete state transition
        await Future.delayed(const Duration(milliseconds: 200));
        
        final finalUpload = uploadManager.getUpload(upload.id);
        expect(finalUpload?.status, UploadStatus.published);
        expect(finalUpload?.nostrEventId, isNotNull);
        
        // Step 6: Verify all services were called correctly
        verify(() => mockHttpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body'))).called(1);
        verify(() => mockHttpClient.get(any(), headers: any(named: 'headers'))).called(greaterThan(0));
        verify(() => mockNostrService.broadcastEvent(any())).called(1);
        verify(() => mockHttpClient.delete(any(), headers: any(named: 'headers'))).called(1);

        print('✅ TEST: Complete pipeline executed successfully!');
      });

      test('pipeline should handle upload failures gracefully', () async {
        // ARRANGE: Setup failing upload scenario
        final testVideoFile = MockFile();
        when(() => testVideoFile.path).thenReturn('/tmp/nonexistent_video.mp4');
        when(() => testVideoFile.existsSync()).thenReturn(false);

        // ACT: Try to upload non-existent file
        expect(
          () => uploadManager.startUpload(
            videoFile: testVideoFile,
            nostrPubkey: 'test-pubkey',
            title: 'Failing Video',
          ),
          throwsA(isA<Exception>()),
        );
      });

      test('pipeline should handle backend API failures gracefully', () async {
        // ARRANGE: Setup API failure scenario
        when(() => mockHttpClient.get(any(), headers: any(named: 'headers')))
            .thenThrow(Exception('Network error'));

        // ACT: Initialize publisher and force check
        await videoEventPublisher.initialize();
        
        // Should not throw - should handle gracefully
        expect(() => videoEventPublisher.forceCheck(), returnsNormally);
        
        // Wait for error handling
        await Future.delayed(const Duration(milliseconds: 100));
        
        // ASSERT: Publisher should still be active despite error
        expect(videoEventPublisher.publishingStats['is_polling_active'], true);
      });

      test('pipeline should handle Nostr broadcasting failures gracefully', () async {
        // ARRANGE: Setup Nostr failure
        when(() => mockNostrService.broadcastEvent(any()))
            .thenThrow(Exception('Relay connection failed'));

        // Mock successful ready event API
        final readyEventResponse = MockResponse();
        when(() => readyEventResponse.statusCode).thenReturn(200);
        when(() => readyEventResponse.body).thenReturn(jsonEncode({
          'events': [{
            'public_id': 'test-video-123',
            'secure_url': 'https://cloudinary.com/test-video-123.mp4',
            'content_suggestion': 'Test video content',
            'tags': [['url', 'https://cloudinary.com/test-video-123.mp4']],
            'metadata': {},
            'processed_at': DateTime.now().toIso8601String(),
            'original_upload_id': 'test-upload-id',
            'mime_type': 'video/mp4',
          }]
        }));

        when(() => mockHttpClient.get(any(), headers: any(named: 'headers')))
            .thenAnswer((_) async => readyEventResponse);

        // ACT: Force check with Nostr failure
        await videoEventPublisher.initialize();
        await videoEventPublisher.forceCheck();
        
        await Future.delayed(const Duration(milliseconds: 100));

        // ASSERT: Should track the failure
        expect(videoEventPublisher.publishingStats['total_failed'], greaterThan(0));
      });
    });

    group('Service Integration', () {
      test('services should maintain consistent state across operations', () async {
        // Test that UploadManager and VideoEventPublisher stay in sync
        final testVideoFile = MockFile();
        when(() => testVideoFile.path).thenReturn('/tmp/sync_test.mp4');
        when(() => testVideoFile.existsSync()).thenReturn(true);
        when(() => testVideoFile.readAsBytesSync()).thenReturn([1, 2, 3]);

        // Mock minimal successful upload
        final response = MockResponse();
        when(() => response.statusCode).thenReturn(200);
        when(() => response.body).thenReturn(jsonEncode({
          'public_id': 'sync-test-123',
          'secure_url': 'https://cloudinary.com/sync-test-123.mp4',
        }));
        when(() => mockHttpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body')))
            .thenAnswer((_) async => response);

        // Start upload
        final upload = await uploadManager.startUpload(
          videoFile: testVideoFile,
          nostrPubkey: 'sync-test-pubkey',
          title: 'Sync Test',
        );

        // Wait for processing
        await Future.delayed(const Duration(milliseconds: 100));

        // Check that UploadManager has the upload
        final retrievedUpload = uploadManager.getUpload(upload.id);
        expect(retrievedUpload, isNotNull);
        expect(retrievedUpload!.id, upload.id);

        // Check that services can work with the same upload
        await uploadManager.markUploadReadyToPublish(upload.id, 'sync-test-123');
        
        final readyUpload = uploadManager.getUpload(upload.id);
        expect(readyUpload!.status, UploadStatus.readyToPublish);
        expect(readyUpload.cloudinaryPublicId, 'sync-test-123');
      });

      test('notification service should trigger correctly during pipeline', () async {
        // This is a basic test since NotificationService is mostly placeholder
        expect(() => notificationService.initialize(), returnsNormally);
        
        expect(() => notificationService.showVideoPublished(
          videoTitle: 'Test Video',
          nostrEventId: 'test-event-123',
          videoUrl: 'https://cloudinary.com/test.mp4',
        ), returnsNormally);

        expect(notificationService.notifications.length, 1);
        expect(notificationService.notifications.first.type, NotificationType.videoPublished);
      });
    });

    group('Performance and Reliability', () {
      test('pipeline should handle multiple concurrent uploads', () async {
        // Test concurrent upload handling
        final files = List.generate(3, (i) {
          final file = MockFile();
          when(() => file.path).thenReturn('/tmp/concurrent_$i.mp4');
          when(() => file.existsSync()).thenReturn(true);
          when(() => file.readAsBytesSync()).thenReturn([i, i + 1, i + 2]);
          return file;
        });

        // Mock responses for all uploads
        final response = MockResponse();
        when(() => response.statusCode).thenReturn(200);
        when(() => response.body).thenReturn(jsonEncode({
          'public_id': 'concurrent-test',
          'secure_url': 'https://cloudinary.com/concurrent-test.mp4',
        }));
        when(() => mockHttpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body')))
            .thenAnswer((_) async => response);

        // Start concurrent uploads
        final uploadFutures = files.map((file) => uploadManager.startUpload(
          videoFile: file,
          nostrPubkey: 'concurrent-test-pubkey',
          title: 'Concurrent Test ${files.indexOf(file)}',
        ));

        final uploads = await Future.wait(uploadFutures);
        
        // Verify all uploads were created
        expect(uploads.length, 3);
        expect(uploads.map((u) => u.id).toSet().length, 3); // All unique IDs

        // Verify all are in upload manager
        for (final upload in uploads) {
          final retrieved = uploadManager.getUpload(upload.id);
          expect(retrieved, isNotNull);
        }
      });

      test('pipeline should recover from service restarts', () async {
        // Simulate service restart by disposing and recreating
        final testVideoFile = MockFile();
        when(() => testVideoFile.path).thenReturn('/tmp/restart_test.mp4');
        when(() => testVideoFile.existsSync()).thenReturn(true);
        when(() => testVideoFile.readAsBytesSync()).thenReturn([9, 8, 7]);

        final response = MockResponse();
        when(() => response.statusCode).thenReturn(200);
        when(() => response.body).thenReturn(jsonEncode({
          'public_id': 'restart-test-123',
          'secure_url': 'https://cloudinary.com/restart-test-123.mp4',
        }));
        when(() => mockHttpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body')))
            .thenAnswer((_) async => response);

        // Create upload before "restart"
        final upload = await uploadManager.startUpload(
          videoFile: testVideoFile,
          nostrPubkey: 'restart-test-pubkey',
          title: 'Restart Test',
        );

        await Future.delayed(const Duration(milliseconds: 50));
        await uploadManager.markUploadReadyToPublish(upload.id, 'restart-test-123');

        // Simulate restart by creating new UploadManager instance with same storage
        uploadManager.dispose();
        
        final newUploadManager = UploadManager(cloudinaryService: cloudinaryService);
        await newUploadManager.initialize();

        // Verify upload persisted across restart
        final persistedUpload = newUploadManager.getUpload(upload.id);
        expect(persistedUpload, isNotNull);
        expect(persistedUpload!.id, upload.id);
        expect(persistedUpload.status, UploadStatus.readyToPublish);

        newUploadManager.dispose();
      });
    });

    group('Error Scenarios', () {
      test('pipeline should handle malformed backend responses', () async {
        // Setup malformed JSON response
        final malformedResponse = MockResponse();
        when(() => malformedResponse.statusCode).thenReturn(200);
        when(() => malformedResponse.body).thenReturn('{"invalid": json}');

        when(() => mockHttpClient.get(any(), headers: any(named: 'headers')))
            .thenAnswer((_) async => malformedResponse);

        await videoEventPublisher.initialize();
        
        // Should handle malformed response gracefully
        expect(() => videoEventPublisher.forceCheck(), returnsNormally);
        
        await Future.delayed(const Duration(milliseconds: 100));
        
        // Publisher should still be active
        expect(videoEventPublisher.publishingStats['is_polling_active'], true);
      });

      test('pipeline should handle network timeouts', () async {
        // Setup timeout scenario
        when(() => mockHttpClient.get(any(), headers: any(named: 'headers')))
            .thenAnswer((_) async {
              await Future.delayed(const Duration(seconds: 35)); // Longer than API timeout
              return MockResponse();
            });

        await videoEventPublisher.initialize();
        
        // Should handle timeout gracefully
        expect(() => videoEventPublisher.forceCheck(), returnsNormally);
        
        await Future.delayed(const Duration(milliseconds: 100));
        
        // Should still be polling despite timeout
        expect(videoEventPublisher.publishingStats['is_polling_active'], true);
      });
    });
  });
}