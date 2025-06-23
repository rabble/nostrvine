// ABOUTME: Tests for thumbnail inclusion in NIP-71 video events
// ABOUTME: Verifies that published events include proper thumb tags

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:openvine/services/video_event_publisher.dart';
import 'package:openvine/services/upload_manager.dart';
import 'package:openvine/services/nostr_service_interface.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/models/pending_upload.dart';
import 'package:openvine/models/ready_event_data.dart';
import 'package:nostr_sdk/event.dart';

@GenerateMocks([
  UploadManager,
  INostrService,
  AuthService,
])
import 'video_event_publisher_thumbnail_test.mocks.dart';

void main() {
  group('VideoEventPublisher Thumbnail Integration', () {
    late VideoEventPublisher publisher;
    late MockUploadManager mockUploadManager;
    late MockINostrService mockNostrService;
    late MockAuthService mockAuthService;

    setUp(() {
      mockUploadManager = MockUploadManager();
      mockNostrService = MockINostrService();
      mockAuthService = MockAuthService();

      publisher = VideoEventPublisher(
        uploadManager: mockUploadManager,
        nostrService: mockNostrService,
        authService: mockAuthService,
        fetchReadyEvents: () async => [],
        cleanupRemoteEvent: (id) async {},
      );

      // Setup auth service mocks
      when(mockAuthService.isAuthenticated).thenReturn(true);
    });

    tearDown(() {
      publisher.dispose();
    });

    test('publishDirectUpload includes thumbnail in event tags', () async {
      // Create upload with thumbnail
      final upload = PendingUpload(
        id: 'test-upload-123',
        localVideoPath: '/test/video.mp4',
        nostrPubkey: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        status: UploadStatus.readyToPublish,
        createdAt: DateTime.now(),
        videoId: 'video123',
        cdnUrl: 'https://cdn.example.com/video123.mp4',
        thumbnailPath: 'https://cdn.example.com/thumb123.jpg',
        title: 'Test Video',
        description: 'A test video with thumbnail',
        hashtags: ['test', 'video'],
      );

      // Mock event creation
      final mockEvent = Event(
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        22,
        [
          ['url', 'https://cdn.example.com/video123.mp4'],
          ['m', 'video/mp4'],
          ['thumb', 'https://cdn.example.com/thumb123.jpg'],
          ['title', 'Test Video'],
          ['summary', 'A test video with thumbnail'],
          ['t', 'test'],
          ['t', 'video'],
          ['client', 'nostrvine'],
        ],
        'A test video with thumbnail',
      );

      when(mockAuthService.createAndSignEvent(
        kind: anyNamed('kind'),
        content: anyNamed('content'),
        tags: anyNamed('tags'),
      )).thenAnswer((_) async => mockEvent);

      when(mockNostrService.broadcastEvent(any)).thenAnswer((invocation) async {
        final event = invocation.positionalArguments[0] as Event;
        return NostrBroadcastResult(
          event: event,
          successCount: 1,
          totalRelays: 1,
          results: {'relay1': true},
          errors: {},
        );
      });

      when(mockUploadManager.updateUploadStatus(
        any,
        any,
        nostrEventId: anyNamed('nostrEventId'),
      )).thenAnswer((_) async {});

      // Test publishing
      final result = await publisher.publishDirectUpload(upload);

      expect(result, isTrue);

      // Verify event creation was called with correct parameters
      final verification = verify(mockAuthService.createAndSignEvent(
        kind: 22,
        content: 'A test video with thumbnail',
        tags: captureAnyNamed('tags'),
      ));
      verification.called(1);

      // Check that tags include thumbnail
      final capturedTags = verification.captured[0] as List<List<String>>;
      
      // Check for specific tags
      expect(capturedTags.any((tag) => tag.length >= 2 && tag[0] == 'thumb' && tag[1] == 'https://cdn.example.com/thumb123.jpg'), isTrue);
      expect(capturedTags.any((tag) => tag.length >= 2 && tag[0] == 'url' && tag[1] == 'https://cdn.example.com/video123.mp4'), isTrue);
      expect(capturedTags.any((tag) => tag.length >= 2 && tag[0] == 'title' && tag[1] == 'Test Video'), isTrue);
      expect(capturedTags.any((tag) => tag.length >= 2 && tag[0] == 'client' && tag[1] == 'nostrvine'), isTrue);
    });

    test('publishDirectUpload works without thumbnail', () async {
      // Create upload without thumbnail
      final upload = PendingUpload(
        id: 'test-upload-456',
        localVideoPath: '/test/video2.mp4',
        nostrPubkey: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        status: UploadStatus.readyToPublish,
        createdAt: DateTime.now(),
        videoId: 'video456',
        cdnUrl: 'https://cdn.example.com/video456.mp4',
        thumbnailPath: null, // No thumbnail
        title: 'Video Without Thumbnail',
        description: 'A test video without thumbnail',
      );

      // Mock event creation
      final mockEvent = Event(
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        22,
        [
          ['url', 'https://cdn.example.com/video456.mp4'],
          ['m', 'video/mp4'],
          ['title', 'Video Without Thumbnail'],
          ['summary', 'A test video without thumbnail'],
          ['client', 'nostrvine'],
        ],
        'A test video without thumbnail',
      );

      when(mockAuthService.createAndSignEvent(
        kind: anyNamed('kind'),
        content: anyNamed('content'),
        tags: anyNamed('tags'),
      )).thenAnswer((_) async => mockEvent);

      when(mockNostrService.broadcastEvent(any)).thenAnswer((invocation) async {
        final event = invocation.positionalArguments[0] as Event;
        return NostrBroadcastResult(
          event: event,
          successCount: 1,
          totalRelays: 1,
          results: {'relay1': true},
          errors: {},
        );
      });

      when(mockUploadManager.updateUploadStatus(
        any,
        any,
        nostrEventId: anyNamed('nostrEventId'),
      )).thenAnswer((_) async {});

      // Test publishing
      final result = await publisher.publishDirectUpload(upload);

      expect(result, isTrue);

      // Verify tags don't include thumbnail
      final verification = verify(mockAuthService.createAndSignEvent(
        kind: 22,
        content: 'A test video without thumbnail',
        tags: captureAnyNamed('tags'),
      ));
      verification.called(1);

      final capturedTags = verification.captured[0] as List<List<String>>;
      expect(capturedTags.any((tag) => tag.length >= 1 && tag[0] == 'thumb'), isFalse);
      expect(capturedTags.any((tag) => tag.length >= 2 && tag[0] == 'url' && tag[1] == 'https://cdn.example.com/video456.mp4'), isTrue);
    });

    test('fails gracefully when upload missing required fields', () async {
      // Create upload without required fields
      final upload = PendingUpload(
        id: 'test-upload-invalid',
        localVideoPath: '/test/video.mp4',
        nostrPubkey: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        status: UploadStatus.readyToPublish,
        createdAt: DateTime.now(),
        videoId: null, // Missing video ID
        cdnUrl: null,  // Missing CDN URL
      );

      // Test publishing
      final result = await publisher.publishDirectUpload(upload);

      expect(result, isFalse);

      // Verify no event was created
      verifyNever(mockAuthService.createAndSignEvent(
        kind: anyNamed('kind'),
        content: anyNamed('content'),
        tags: anyNamed('tags'),
      ));
    });

    test('creates proper NIP-71 compliant event structure', () async {
      final upload = PendingUpload(
        id: 'test-nip71',
        localVideoPath: '/test/nip71.mp4',
        nostrPubkey: '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
        status: UploadStatus.readyToPublish,
        createdAt: DateTime.now(),
        videoId: 'nip71-video',
        cdnUrl: 'https://cdn.example.com/nip71.mp4',
        thumbnailPath: 'https://cdn.example.com/nip71-thumb.jpg',
        title: 'NIP-71 Test',
        description: 'Testing NIP-71 compliance',
        hashtags: ['nip71', 'nostr'],
      );

      when(mockAuthService.createAndSignEvent(
        kind: anyNamed('kind'),
        content: anyNamed('content'),
        tags: anyNamed('tags'),
      )).thenAnswer((invocation) async {
        final kind = invocation.namedArguments[const Symbol('kind')] as int;
        final content = invocation.namedArguments[const Symbol('content')] as String;
        final tags = invocation.namedArguments[const Symbol('tags')] as List<List<String>>;

        return Event(
          '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
          kind,
          tags,
          content,
        );
      });

      when(mockNostrService.broadcastEvent(any)).thenAnswer((invocation) async {
        final event = invocation.positionalArguments[0] as Event;
        return NostrBroadcastResult(
          event: event,
          successCount: 1,
          totalRelays: 1,
          results: {'relay1': true},
          errors: {},
        );
      });
      when(mockUploadManager.updateUploadStatus(any, any, nostrEventId: anyNamed('nostrEventId')))
          .thenAnswer((_) async {});

      final result = await publisher.publishDirectUpload(upload);

      expect(result, isTrue);

      // Verify NIP-71 compliance
      final verification = verify(mockAuthService.createAndSignEvent(
        kind: 22, // NIP-71 short video kind
        content: 'Testing NIP-71 compliance',
        tags: captureAnyNamed('tags'),
      ));

      final tags = verification.captured[0] as List<List<String>>;
      
      // Check required NIP-71 tags
      expect(tags.any((tag) => tag.length >= 2 && tag[0] == 'url' && tag[1] == 'https://cdn.example.com/nip71.mp4'), isTrue);
      expect(tags.any((tag) => tag.length >= 2 && tag[0] == 'm' && tag[1] == 'video/mp4'), isTrue);
      
      // Check optional but included tags
      expect(tags.any((tag) => tag.length >= 2 && tag[0] == 'thumb' && tag[1] == 'https://cdn.example.com/nip71-thumb.jpg'), isTrue);
      expect(tags.any((tag) => tag.length >= 2 && tag[0] == 'title' && tag[1] == 'NIP-71 Test'), isTrue);
      expect(tags.any((tag) => tag.length >= 2 && tag[0] == 'summary' && tag[1] == 'Testing NIP-71 compliance'), isTrue);
      expect(tags.any((tag) => tag.length >= 2 && tag[0] == 't' && tag[1] == 'nip71'), isTrue);
      expect(tags.any((tag) => tag.length >= 2 && tag[0] == 't' && tag[1] == 'nostr'), isTrue);
      expect(tags.any((tag) => tag.length >= 2 && tag[0] == 'client' && tag[1] == 'nostrvine'), isTrue);
    });
  });
}