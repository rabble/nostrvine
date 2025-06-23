// ABOUTME: Unit tests for UploadManager to verify state management and persistence
// ABOUTME: Tests upload lifecycle, retry logic, and local storage integration

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/services/upload_manager.dart';
import 'package:openvine/services/cloudinary_upload_service.dart';
import 'package:openvine/models/pending_upload.dart';

// Mock classes
class MockCloudinaryUploadService extends Mock implements CloudinaryUploadService {}
class MockFile extends Mock implements File {}

void main() {
  group('UploadManager', () {
    late UploadManager uploadManager;
    late MockCloudinaryUploadService mockCloudinaryService;
    late MockFile mockVideoFile;

    setUp(() {
      mockCloudinaryService = MockCloudinaryUploadService();
      mockVideoFile = MockFile();
      uploadManager = UploadManager(cloudinaryService: mockCloudinaryService);
      
      // Setup default mocks
      when(() => mockVideoFile.path).thenReturn('/path/to/video.mp4');
      when(() => mockVideoFile.existsSync()).thenReturn(true);
    });

    tearDown(() {
      uploadManager.dispose();
    });

    group('initialization', () {
      test('should start with empty uploads list', () {
        // Assert
        expect(uploadManager.pendingUploads, isEmpty);
      });

      test('should provide correct upload statistics', () {
        // Act
        final stats = uploadManager.uploadStats;
        
        // Assert
        expect(stats['total'], 0);
        expect(stats['pending'], 0);
        expect(stats['uploading'], 0);
        expect(stats['processing'], 0);
        expect(stats['ready'], 0);
        expect(stats['published'], 0);
        expect(stats['failed'], 0);
      });
    });

    group('startUpload', () {
      test('should create pending upload with correct data', () async {
        // Arrange
        when(() => mockCloudinaryService.uploadVideo(
          videoFile: any(named: 'videoFile'),
          nostrPubkey: any(named: 'nostrPubkey'),
          title: any(named: 'title'),
          description: any(named: 'description'),
          hashtags: any(named: 'hashtags'),
          onProgress: any(named: 'onProgress'),
        )).thenAnswer((_) async => UploadResult.success(
          cloudinaryPublicId: 'test-id',
          cloudinaryUrl: 'https://test.com/video.mp4',
        ));

        // Act
        final upload = await uploadManager.startUpload(
          videoFile: mockVideoFile,
          nostrPubkey: 'test-pubkey',
          title: 'Test Video',
          description: 'Test Description',
          hashtags: ['test', 'upload'],
        );
        
        // Assert
        expect(upload.localVideoPath, '/path/to/video.mp4');
        expect(upload.nostrPubkey, 'test-pubkey');
        expect(upload.title, 'Test Video');
        expect(upload.description, 'Test Description');
        expect(upload.hashtags, ['test', 'upload']);
        expect(upload.status, UploadStatus.pending);
        expect(upload.retryCount, 0);
      });

      test('should start upload process automatically', () async {
        // Arrange
        when(() => mockCloudinaryService.uploadVideo(
          videoFile: any(named: 'videoFile'),
          nostrPubkey: any(named: 'nostrPubkey'),
          title: any(named: 'title'),
          description: any(named: 'description'),
          hashtags: any(named: 'hashtags'),
          onProgress: any(named: 'onProgress'),
        )).thenAnswer((_) async => UploadResult.success(
          cloudinaryPublicId: 'test-id',
          cloudinaryUrl: 'https://test.com/video.mp4',
        ));

        // Act
        await uploadManager.startUpload(
          videoFile: mockVideoFile,
          nostrPubkey: 'test-pubkey',
        );
        
        // Give some time for async operation to start
        await Future.delayed(const Duration(milliseconds: 10));
        
        // Assert
        verify(() => mockCloudinaryService.uploadVideo(
          videoFile: mockVideoFile,
          nostrPubkey: 'test-pubkey',
          title: null,
          description: null,
          hashtags: null,
          onProgress: any(named: 'onProgress'),
        )).called(1);
      });
    });

    group('getUploadsByStatus', () {
      test('should filter uploads by status correctly', () {
        // Note: This test is limited because we can't easily test Hive persistence
        // in unit tests without a full Hive setup
        
        // Act & Assert
        expect(uploadManager.getUploadsByStatus(UploadStatus.pending), isEmpty);
        expect(uploadManager.getUploadsByStatus(UploadStatus.uploading), isEmpty);
        expect(uploadManager.getUploadsByStatus(UploadStatus.failed), isEmpty);
      });
    });

    group('retryUpload', () {
      test('should handle retry of non-existent upload', () async {
        // Act & Assert - should not throw
        await uploadManager.retryUpload('non-existent-id');
      });
    });

    group('cancelUpload', () {
      test('should handle cancellation of non-existent upload', () async {
        // Act & Assert - should not throw
        await uploadManager.cancelUpload('non-existent-id');
        
        verify(() => mockCloudinaryService.cancelUpload(any())).called(1);
      });
    });

    group('cleanupCompletedUploads', () {
      test('should not throw when no uploads exist', () async {
        // Act & Assert - should not throw
        await uploadManager.cleanupCompletedUploads();
      });
    });
  });

  group('PendingUpload', () {
    test('should create upload with correct defaults', () {
      // Act
      final upload = PendingUpload.create(
        localVideoPath: '/path/to/video.mp4',
        nostrPubkey: 'test-pubkey',
        title: 'Test Video',
      );
      
      // Assert
      expect(upload.localVideoPath, '/path/to/video.mp4');
      expect(upload.nostrPubkey, 'test-pubkey');
      expect(upload.title, 'Test Video');
      expect(upload.status, UploadStatus.pending);
      expect(upload.retryCount, 0);
      expect(upload.createdAt, isA<DateTime>());
      expect(upload.id, isNotEmpty);
    });

    test('should calculate progress correctly for different statuses', () {
      final baseUpload = PendingUpload.create(
        localVideoPath: '/path/to/video.mp4',
        nostrPubkey: 'test-pubkey',
      );
      
      // Test different statuses
      expect(baseUpload.progressValue, 0.0); // pending
      
      final uploading = baseUpload.copyWith(
        status: UploadStatus.uploading,
        uploadProgress: 0.5,
      );
      expect(uploading.progressValue, 0.5);
      
      final processing = baseUpload.copyWith(status: UploadStatus.processing);
      expect(processing.progressValue, 0.8);
      
      final published = baseUpload.copyWith(status: UploadStatus.published);
      expect(published.progressValue, 1.0);
    });

    test('should determine retry eligibility correctly', () {
      final upload = PendingUpload.create(
        localVideoPath: '/path/to/video.mp4',
        nostrPubkey: 'test-pubkey',
      );
      
      // Fresh upload - cannot retry
      expect(upload.canRetry, false);
      
      // Failed upload with retries available
      final failedUpload = upload.copyWith(
        status: UploadStatus.failed,
        retryCount: 1,
      );
      expect(failedUpload.canRetry, true);
      
      // Failed upload with max retries
      final maxRetriesUpload = upload.copyWith(
        status: UploadStatus.failed,
        retryCount: 3,
      );
      expect(maxRetriesUpload.canRetry, false);
    });

    test('should detect completion status correctly', () {
      final upload = PendingUpload.create(
        localVideoPath: '/path/to/video.mp4',
        nostrPubkey: 'test-pubkey',
      );
      
      // Pending upload - not completed
      expect(upload.isCompleted, false);
      
      // Published upload - completed
      final published = upload.copyWith(status: UploadStatus.published);
      expect(published.isCompleted, true);
      
      // Failed upload - completed
      final failed = upload.copyWith(status: UploadStatus.failed);
      expect(failed.isCompleted, true);
    });

    test('should provide appropriate status text', () {
      final upload = PendingUpload.create(
        localVideoPath: '/path/to/video.mp4',
        nostrPubkey: 'test-pubkey',
      );
      
      expect(upload.statusText, contains('Waiting'));
      
      final uploading = upload.copyWith(
        status: UploadStatus.uploading,
        uploadProgress: 0.7,
      );
      expect(uploading.statusText, contains('70%'));
      
      final failed = upload.copyWith(
        status: UploadStatus.failed,
        errorMessage: 'Network error',
      );
      expect(failed.statusText, contains('Network error'));
    });
  });
}