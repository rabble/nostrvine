// ABOUTME: Unit tests for VideoEventPublisher.publishVideoEvent custom metadata method
// ABOUTME: Tests the wrapper method that allows custom metadata for video events

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/models/pending_upload.dart';
import 'package:openvine/models/nip94_metadata.dart';
import 'package:openvine/models/ready_event_data.dart';
import 'package:openvine/services/video_event_publisher.dart';
import 'package:openvine/services/nostr_service_interface.dart';
import 'package:openvine/services/upload_manager.dart';

class MockINostrService extends Mock implements INostrService {}
class MockUploadManager extends Mock implements UploadManager {}
class FakeNIP94Metadata extends Fake implements NIP94Metadata {}
class FakeReadyEventData extends Fake implements ReadyEventData {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeNIP94Metadata());
    registerFallbackValue(UploadStatus.pending);
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
      fetchReadyEvents: () async => [],
      cleanupRemoteEvent: (publicId) async {},
    );
    
    // Default mock behavior - removed global stub, tests will provide specific stubs
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

      // Capture the parameters passed to publishVideoEvent
      String? capturedContent;
      String? capturedTitle;
      List<String>? capturedHashtags;
      
      when(() => mockNostrService.publishVideoEvent(
        videoUrl: any(named: 'videoUrl'),
        content: any(named: 'content'),
        title: any(named: 'title'),
        thumbnailUrl: any(named: 'thumbnailUrl'),
        duration: any(named: 'duration'),
        dimensions: any(named: 'dimensions'),
        mimeType: any(named: 'mimeType'),
        sha256: any(named: 'sha256'),
        fileSize: any(named: 'fileSize'),
        hashtags: any(named: 'hashtags'),
      )).thenAnswer((invocation) async {
        capturedContent = invocation.namedArguments[Symbol('content')] as String;
        capturedTitle = invocation.namedArguments[Symbol('title')] as String?;
        capturedHashtags = invocation.namedArguments[Symbol('hashtags')] as List<String>?;
        return NostrBroadcastResult(
          event: Event(
            'pubkey123',
            22,
            [],
            '',
          ),
          successCount: 1,
          totalRelays: 1,
          results: {'relay1': true},
          errors: {},
        );
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
      verify(() => mockNostrService.publishVideoEvent(
        videoUrl: any(named: 'videoUrl'),
        content: any(named: 'content'),
        title: any(named: 'title'),
        thumbnailUrl: any(named: 'thumbnailUrl'),
        duration: any(named: 'duration'),
        dimensions: any(named: 'dimensions'),
        mimeType: any(named: 'mimeType'),
        sha256: any(named: 'sha256'),
        fileSize: any(named: 'fileSize'),
        hashtags: any(named: 'hashtags'),
      )).called(1);
      
      // Verify the parameters contain custom values
      expect(capturedTitle, equals(customTitle));
      expect(capturedContent, equals(customDescription));
      expect(capturedHashtags, equals(customHashtags));
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

      String? capturedTitle;
      String? capturedContent;
      List<String>? capturedHashtags;
      
      when(() => mockNostrService.publishVideoEvent(
        videoUrl: any(named: 'videoUrl'),
        content: any(named: 'content'),
        title: any(named: 'title'),
        thumbnailUrl: any(named: 'thumbnailUrl'),
        duration: any(named: 'duration'),
        dimensions: any(named: 'dimensions'),
        mimeType: any(named: 'mimeType'),
        sha256: any(named: 'sha256'),
        fileSize: any(named: 'fileSize'),
        hashtags: any(named: 'hashtags'),
      )).thenAnswer((invocation) async {
        capturedTitle = invocation.namedArguments[Symbol('title')] as String?;
        capturedContent = invocation.namedArguments[Symbol('content')] as String;
        capturedHashtags = invocation.namedArguments[Symbol('hashtags')] as List<String>?;
        return NostrBroadcastResult(
          event: Event(
            'pubkey123',
            22,
            [],
            '',
          ),
          successCount: 1,
          totalRelays: 1,
          results: {'relay1': true},
          errors: {},
        );
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
      expect(capturedTitle, equals('Original Title'));
      expect(capturedContent, equals('Original Description'));
      expect(capturedHashtags, equals(['original', 'tags']));
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

      String? capturedTitle;
      String? capturedContent;
      List<String>? capturedHashtags;
      
      when(() => mockNostrService.publishVideoEvent(
        videoUrl: any(named: 'videoUrl'),
        content: any(named: 'content'),
        title: any(named: 'title'),
        thumbnailUrl: any(named: 'thumbnailUrl'),
        duration: any(named: 'duration'),
        dimensions: any(named: 'dimensions'),
        mimeType: any(named: 'mimeType'),
        sha256: any(named: 'sha256'),
        fileSize: any(named: 'fileSize'),
        hashtags: any(named: 'hashtags'),
      )).thenAnswer((invocation) async {
        capturedTitle = invocation.namedArguments[Symbol('title')] as String?;
        capturedContent = invocation.namedArguments[Symbol('content')] as String;
        capturedHashtags = invocation.namedArguments[Symbol('hashtags')] as List<String>?;
        return NostrBroadcastResult(
          event: Event(
            'pubkey123',
            22,
            [],
            '',
          ),
          successCount: 1,
          totalRelays: 1,
          results: {'relay1': true},
          errors: {},
        );
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
      expect(capturedTitle, equals('New Title Only'));
      expect(capturedContent, equals('Original Description'));
      expect(capturedHashtags, equals(['original', 'tags']));
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

      String? capturedTitle;
      String? capturedContent;
      List<String>? capturedHashtags;
      
      when(() => mockNostrService.publishVideoEvent(
        videoUrl: any(named: 'videoUrl'),
        content: any(named: 'content'),
        title: any(named: 'title'),
        thumbnailUrl: any(named: 'thumbnailUrl'),
        duration: any(named: 'duration'),
        dimensions: any(named: 'dimensions'),
        mimeType: any(named: 'mimeType'),
        sha256: any(named: 'sha256'),
        fileSize: any(named: 'fileSize'),
        hashtags: any(named: 'hashtags'),
      )).thenAnswer((invocation) async {
        capturedTitle = invocation.namedArguments[Symbol('title')] as String?;
        capturedContent = invocation.namedArguments[Symbol('content')] as String;
        capturedHashtags = invocation.namedArguments[Symbol('hashtags')] as List<String>?;
        return NostrBroadcastResult(
          event: Event(
            'pubkey123',
            22,
            [],
            '',
          ),
          successCount: 1,
          totalRelays: 1,
          results: {'relay1': true},
          errors: {},
        );
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
      expect(capturedTitle, equals(''));
      expect(capturedContent, equals(''));
      expect(capturedHashtags, equals([]));
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

      when(() => mockNostrService.publishVideoEvent(
        videoUrl: any(named: 'videoUrl'),
        content: any(named: 'content'),
        title: any(named: 'title'),
        thumbnailUrl: any(named: 'thumbnailUrl'),
        duration: any(named: 'duration'),
        dimensions: any(named: 'dimensions'),
        mimeType: any(named: 'mimeType'),
        sha256: any(named: 'sha256'),
        fileSize: any(named: 'fileSize'),
        hashtags: any(named: 'hashtags'),
      )).thenThrow(Exception('Publishing failed'));
      when(() => mockUploadManager.updateUploadStatus(any(), UploadStatus.failed))
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

      String? capturedTitle;
      String? capturedContent;
      List<String>? capturedHashtags;
      
      when(() => mockNostrService.publishVideoEvent(
        videoUrl: any(named: 'videoUrl'),
        content: any(named: 'content'),
        title: any(named: 'title'),
        thumbnailUrl: any(named: 'thumbnailUrl'),
        duration: any(named: 'duration'),
        dimensions: any(named: 'dimensions'),
        mimeType: any(named: 'mimeType'),
        sha256: any(named: 'sha256'),
        fileSize: any(named: 'fileSize'),
        hashtags: any(named: 'hashtags'),
      )).thenAnswer((invocation) async {
        capturedTitle = invocation.namedArguments[Symbol('title')] as String?;
        capturedContent = invocation.namedArguments[Symbol('content')] as String;
        capturedHashtags = invocation.namedArguments[Symbol('hashtags')] as List<String>?;
        return NostrBroadcastResult(
          event: Event(
            'pubkey123',
            22,
            [],
            '',
          ),
          successCount: 1,
          totalRelays: 1,
          results: {'relay1': true},
          errors: {},
        );
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
      expect(capturedTitle, equals('Title with émojis 🎬 and symbols @#\$%'));
      expect(capturedContent, equals('Description with\nnewlines\tand\ttabs'));
      expect(capturedHashtags, equals(['tag-with-dash', 'tag_with_underscore', '🏷️']));
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

      when(() => mockNostrService.publishVideoEvent(
        videoUrl: any(named: 'videoUrl'),
        content: any(named: 'content'),
        title: any(named: 'title'),
        thumbnailUrl: any(named: 'thumbnailUrl'),
        duration: any(named: 'duration'),
        dimensions: any(named: 'dimensions'),
        mimeType: any(named: 'mimeType'),
        sha256: any(named: 'sha256'),
        fileSize: any(named: 'fileSize'),
        hashtags: any(named: 'hashtags'),
      )).thenAnswer((_) async => NostrBroadcastResult(
        event: Event(
          'pubkey123',
          22,
          [],
          '',
        ),
        successCount: 1,
        totalRelays: 1,
        results: {'relay1': true},
        errors: {},
      ));

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
        nostrEventId: any(named: 'nostrEventId'),
      )).called(1);
    });
  });
}