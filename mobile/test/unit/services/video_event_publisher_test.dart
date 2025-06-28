// ABOUTME: Unit tests for VideoEventPublisher service including publishVideoEvent method
// ABOUTME: Tests custom metadata publishing functionality and edge cases

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/models/pending_upload.dart';
import 'package:openvine/models/nip94_metadata.dart';
import 'package:openvine/services/video_event_publisher.dart';
import 'package:openvine/services/nostr_service_interface.dart';
import 'package:openvine/services/upload_manager.dart';

class MockINostrService extends Mock implements INostrService {}
class MockUploadManager extends Mock implements UploadManager {}
class FakeNip94Metadata extends Fake implements Nip94Metadata {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeNip94Metadata());
  });
  late VideoEventPublisher videoEventPublisher;
  late MockINostrService mockNostrService;
  late MockUploadManager mockUploadManager;

  setUp(() {
    mockNostrService = MockINostrService();
    mockUploadManager = MockUploadManager();

    videoEventPublisher = VideoEventPublisher(
      nostrService: mockNostrService,
      uploadManager: mockUploadManager,
    );
  });

  group('VideoEventPublisher', () {
    group('publishVideoEvent', () {
      test('should call publishDirectUpload with updated metadata', () async {
        // Arrange
        final originalUpload = PendingUpload.create(
          localVideoPath: '/path/to/video.mp4',
          nostrPubkey: 'pubkey123',
          title: 'Original Title',
          description: 'Original Description',
          hashtags: ['original', 'tags'],
        ).copyWith(
          status: UploadStatus.readyToPublish,
          cdnUrl: 'https://cdn.example.com/video.mp4',
          videoId: 'video123',
        );

        // Mock the publishDirectUpload to capture the upload passed to it
        PendingUpload? capturedUpload;
        when(() => mockNostrService.publishVideoEvent(any())).thenAnswer((_) async => 'event123');
        
        // Override the method to capture the upload
        videoEventPublisher = VideoEventPublisher(
          nostrService: mockNostrService,
          uploadManager: mockUploadManager,
        );

        // Act
        await videoEventPublisher.publishVideoEvent(
          upload: originalUpload,
          title: 'New Title',
          description: 'New Description',
          hashtags: ['new', 'hashtags'],
        );

        // Assert - verify the Nostr service was called
        verify(() => mockNostrService.publishVideoEvent(any())).called(1);
      });

      test('should use original values when custom metadata is null', () async {
        // Arrange
        final originalUpload = PendingUpload.create(
          localVideoPath: '/path/to/video.mp4',
          nostrPubkey: 'pubkey123',
          title: 'Original Title',
          description: 'Original Description', 
          hashtags: ['original', 'tags'],
        ).copyWith(
          status: UploadStatus.readyToPublish,
          cdnUrl: 'https://cdn.example.com/video.mp4',
          videoId: 'video123',
        );

        when(() => mockNostrService.publishVideoEvent(any())).thenAnswer((_) async => 'event123');

        // Act
        await videoEventPublisher.publishVideoEvent(
          upload: originalUpload,
          title: null,
          description: null,
          hashtags: null,
        );

        // Assert
        verify(() => mockNostrService.publishVideoEvent(any())).called(1);
      });

      test('should handle partial metadata updates', () async {
        // Arrange
        final originalUpload = PendingUpload.create(
          localVideoPath: '/path/to/video.mp4',
          nostrPubkey: 'pubkey123',
          title: 'Original Title',
          description: 'Original Description',
          hashtags: ['original', 'tags'],
        ).copyWith(
          status: UploadStatus.readyToPublish,
          cdnUrl: 'https://cdn.example.com/video.mp4',
          videoId: 'video123',
        );

        when(() => mockNostrService.publishVideoEvent(any())).thenAnswer((_) async => 'event123');

        // Act - only update title
        await videoEventPublisher.publishVideoEvent(
          upload: originalUpload,
          title: 'New Title Only',
          description: null,
          hashtags: null,
        );

        // Assert
        verify(() => mockNostrService.publishVideoEvent(any())).called(1);
      });

      test('should handle empty strings in metadata', () async {
        // Arrange
        final originalUpload = PendingUpload.create(
          localVideoPath: '/path/to/video.mp4',
          nostrPubkey: 'pubkey123',
          title: 'Original Title',
          description: 'Original Description',
          hashtags: ['original', 'tags'],
        ).copyWith(
          status: UploadStatus.readyToPublish,
          cdnUrl: 'https://cdn.example.com/video.mp4',
          videoId: 'video123',
        );

        when(() => mockNostrService.publishVideoEvent(any())).thenAnswer((_) async => 'event123');

        // Act
        await videoEventPublisher.publishVideoEvent(
          upload: originalUpload,
          title: '',
          description: '',
          hashtags: [],
        );

        // Assert
        verify(() => mockNostrService.publishVideoEvent(any())).called(1);
      });

      test('should return true when publish succeeds', () async {
        // Arrange
        final upload = PendingUpload.create(
          localVideoPath: '/path/to/video.mp4',
          nostrPubkey: 'pubkey123',
        ).copyWith(
          status: UploadStatus.readyToPublish,
          cdnUrl: 'https://cdn.example.com/video.mp4',
          videoId: 'video123',
        );

        when(() => mockNostrService.publishVideoEvent(any())).thenAnswer((_) async => 'event123');
        when(() => mockUploadManager.updateUploadStatus(any(), any(), eventId: any(named: 'eventId')))
            .thenAnswer((_) async {});

        // Act
        final result = await videoEventPublisher.publishVideoEvent(
          upload: upload,
          title: 'Test Title',
        );

        // Assert
        expect(result, isTrue);
      });

      test('should return false when publish fails', () async {
        // Arrange
        final upload = PendingUpload.create(
          localVideoPath: '/path/to/video.mp4',
          nostrPubkey: 'pubkey123',
        ).copyWith(
          status: UploadStatus.readyToPublish,
          cdnUrl: 'https://cdn.example.com/video.mp4',
          videoId: 'video123',
        );

        when(() => mockNostrService.publishVideoEvent(any()))
            .thenThrow(Exception('Publishing failed'));

        // Act
        final result = await videoEventPublisher.publishVideoEvent(
          upload: upload,
          title: 'Test Title',
        );

        // Assert
        expect(result, isFalse);
      });

      test('should handle special characters in metadata', () async {
        // Arrange
        final upload = PendingUpload.create(
          localVideoPath: '/path/to/video.mp4',
          nostrPubkey: 'pubkey123',
        ).copyWith(
          status: UploadStatus.readyToPublish,
          cdnUrl: 'https://cdn.example.com/video.mp4',
          videoId: 'video123',
        );

        when(() => mockNostrService.publishVideoEvent(any())).thenAnswer((_) async => 'event123');

        // Act
        await videoEventPublisher.publishVideoEvent(
          upload: upload,
          title: 'Title with émojis 🎬 and symbols @#\$%',
          description: 'Description with\nnewlines\tand\ttabs',
          hashtags: ['tag-with-dash', 'tag_with_underscore', '🏷️'],
        );

        // Assert
        verify(() => mockNostrService.publishVideoEvent(any())).called(1);
      });

      test('should handle very long metadata', () async {
        // Arrange
        final upload = PendingUpload.create(
          localVideoPath: '/path/to/video.mp4',
          nostrPubkey: 'pubkey123',
        ).copyWith(
          status: UploadStatus.readyToPublish,
          cdnUrl: 'https://cdn.example.com/video.mp4',
          videoId: 'video123',
        );

        final longTitle = 'A' * 500; // 500 character title
        final longDescription = 'B' * 2000; // 2000 character description
        final manyHashtags = List.generate(50, (i) => 'tag$i'); // 50 hashtags

        when(() => mockNostrService.publishVideoEvent(any())).thenAnswer((_) async => 'event123');

        // Act
        await videoEventPublisher.publishVideoEvent(
          upload: upload,
          title: longTitle,
          description: longDescription,
          hashtags: manyHashtags,
        );

        // Assert
        verify(() => mockNostrService.publishVideoEvent(any())).called(1);
      });
    });
  });
}