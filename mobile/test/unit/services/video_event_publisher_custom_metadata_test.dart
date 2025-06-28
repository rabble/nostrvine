// ABOUTME: Unit tests for VideoEventPublisher.publishVideoEvent custom metadata method
// ABOUTME: Tests the wrapper method that allows custom metadata for video events

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
class FakeUploadStatus extends Fake implements UploadStatus {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeNip94Metadata());
    registerFallbackValue(UploadStatus.published);
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
    
    // Default mock behavior
    when(() => mockNostrService.publishVideoEvent(any())).thenAnswer((_) async => 'event123');
    when(() => mockUploadManager.updateUploadStatus(any(), any(), eventId: any(named: 'eventId')))
        .thenAnswer((_) async {});
  });

  group('VideoEventPublisher.publishVideoEvent', () {
    test('should create temporary upload with custom metadata and publish', () async {
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

      final customTitle = 'Custom Title';
      final customDescription = 'Custom Description';
      final customHashtags = ['custom', 'hashtags'];

      // Capture the metadata passed to publishVideoEvent
      Nip94Metadata? capturedMetadata;
      when(() => mockNostrService.publishVideoEvent(any())).thenAnswer((invocation) async {
        capturedMetadata = invocation.positionalArguments[0] as Nip94Metadata;
        return 'event123';
      });

      // Act
      final result = await videoEventPublisher.publishVideoEvent(
        upload: originalUpload,
        title: customTitle,
        description: customDescription,
        hashtags: customHashtags,
      );

      // Assert
      expect(result, isTrue);
      verify(() => mockNostrService.publishVideoEvent(any())).called(1);
      
      // Verify the metadata contains custom values
      expect(capturedMetadata, isNotNull);
      expect(capturedMetadata!.title, equals(customTitle));
      expect(capturedMetadata!.content, equals(customDescription));
      expect(capturedMetadata!.t, equals(customHashtags));
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

      Nip94Metadata? capturedMetadata;
      when(() => mockNostrService.publishVideoEvent(any())).thenAnswer((invocation) async {
        capturedMetadata = invocation.positionalArguments[0] as Nip94Metadata;
        return 'event123';
      });

      // Act
      final result = await videoEventPublisher.publishVideoEvent(
        upload: originalUpload,
        title: null,
        description: null,
        hashtags: null,
      );

      // Assert
      expect(result, isTrue);
      expect(capturedMetadata!.title, equals('Original Title'));
      expect(capturedMetadata!.content, equals('Original Description'));
      expect(capturedMetadata!.t, equals(['original', 'tags']));
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

      Nip94Metadata? capturedMetadata;
      when(() => mockNostrService.publishVideoEvent(any())).thenAnswer((invocation) async {
        capturedMetadata = invocation.positionalArguments[0] as Nip94Metadata;
        return 'event123';
      });

      // Act - only update title
      final result = await videoEventPublisher.publishVideoEvent(
        upload: originalUpload,
        title: 'New Title Only',
        description: null,
        hashtags: null,
      );

      // Assert
      expect(result, isTrue);
      expect(capturedMetadata!.title, equals('New Title Only'));
      expect(capturedMetadata!.content, equals('Original Description'));
      expect(capturedMetadata!.t, equals(['original', 'tags']));
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

      Nip94Metadata? capturedMetadata;
      when(() => mockNostrService.publishVideoEvent(any())).thenAnswer((invocation) async {
        capturedMetadata = invocation.positionalArguments[0] as Nip94Metadata;
        return 'event123';
      });

      // Act
      final result = await videoEventPublisher.publishVideoEvent(
        upload: originalUpload,
        title: '',
        description: '',
        hashtags: [],
      );

      // Assert
      expect(result, isTrue);
      expect(capturedMetadata!.title, equals(''));
      expect(capturedMetadata!.content, equals(''));
      expect(capturedMetadata!.t, equals([]));
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
      when(() => mockUploadManager.updateUploadStatus(any(), UploadStatus.failed, errorMessage: any(named: 'errorMessage')))
          .thenAnswer((_) async {});

      // Act
      final result = await videoEventPublisher.publishVideoEvent(
        upload: upload,
        title: 'Test Title',
      );

      // Assert
      expect(result, isFalse);
      verify(() => mockUploadManager.updateUploadStatus(
        upload.id, 
        UploadStatus.failed, 
        errorMessage: any(named: 'errorMessage'),
      )).called(1);
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

      Nip94Metadata? capturedMetadata;
      when(() => mockNostrService.publishVideoEvent(any())).thenAnswer((invocation) async {
        capturedMetadata = invocation.positionalArguments[0] as Nip94Metadata;
        return 'event123';
      });

      // Act
      final result = await videoEventPublisher.publishVideoEvent(
        upload: upload,
        title: 'Title with émojis 🎬 and symbols @#\$%',
        description: 'Description with\nnewlines\tand\ttabs',
        hashtags: ['tag-with-dash', 'tag_with_underscore', '🏷️'],
      );

      // Assert
      expect(result, isTrue);
      expect(capturedMetadata!.title, equals('Title with émojis 🎬 and symbols @#\$%'));
      expect(capturedMetadata!.content, equals('Description with\nnewlines\tand\ttabs'));
      expect(capturedMetadata!.t, equals(['tag-with-dash', 'tag_with_underscore', '🏷️']));
    });

    test('should update upload status on successful publish', () async {
      // Arrange
      final upload = PendingUpload.create(
        localVideoPath: '/path/to/video.mp4',
        nostrPubkey: 'pubkey123',
      ).copyWith(
        id: 'upload-123',
        status: UploadStatus.readyToPublish,
        cdnUrl: 'https://cdn.example.com/video.mp4',
        videoId: 'video123',
      );

      when(() => mockNostrService.publishVideoEvent(any())).thenAnswer((_) async => 'event-id-456');

      // Act
      final result = await videoEventPublisher.publishVideoEvent(
        upload: upload,
        title: 'Test Video',
      );

      // Assert
      expect(result, isTrue);
      verify(() => mockUploadManager.updateUploadStatus(
        'upload-123',
        UploadStatus.published,
        eventId: 'event-id-456',
      )).called(1);
    });
  });
}