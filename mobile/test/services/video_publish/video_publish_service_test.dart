// ABOUTME: Tests for VideoPublishService
// ABOUTME: Uses mocked dependencies to test publish flow without real uploads

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' show AspectRatio;
import 'package:openvine/models/pending_upload.dart';
import 'package:openvine/models/recording_clip.dart';
import 'package:openvine/models/vine_draft.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/blossom_upload_service.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:openvine/services/upload_manager.dart';
import 'package:openvine/services/video_event_publisher.dart';
import 'package:openvine/services/video_publish/video_publish_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

// Mock classes
class MockUploadManager extends Mock implements UploadManager {}

class MockAuthService extends Mock implements AuthService {}

class MockVideoEventPublisher extends Mock implements VideoEventPublisher {}

class MockBlossomUploadService extends Mock implements BlossomUploadService {}

class MockDraftStorageService extends Mock implements DraftStorageService {}

void main() {
  late MockUploadManager mockUploadManager;
  late MockAuthService mockAuthService;
  late MockVideoEventPublisher mockVideoEventPublisher;
  late MockBlossomUploadService mockBlossomService;
  late MockDraftStorageService mockDraftService;
  late VideoPublishService service;

  late List<double> progressChanges;

  setUpAll(() {
    // Register fallback values for mocktail
    registerFallbackValue(
      VineDraft.create(
        clips: [_createTestClip()],
        title: 'Test',
        description: 'Test',
        hashtags: {},
        selectedApproach: 'test',
      ),
    );
    registerFallbackValue(_createPendingUpload(status: UploadStatus.pending));
  });

  setUp(() {
    mockUploadManager = MockUploadManager();
    mockAuthService = MockAuthService();
    mockVideoEventPublisher = MockVideoEventPublisher();
    mockBlossomService = MockBlossomUploadService();
    mockDraftService = MockDraftStorageService();

    progressChanges = [];

    service = VideoPublishService(
      uploadManager: mockUploadManager,
      authService: mockAuthService,
      videoEventPublisher: mockVideoEventPublisher,
      blossomService: mockBlossomService,
      draftService: mockDraftService,
      onProgressChanged:
          ({required double progress, required String draftId}) =>
              progressChanges.add(progress),
    );
  });

  group('VideoPublishService', () {
    group('publishVideo', () {
      test('returns error when user is not authenticated', () async {
        // Arrange
        when(() => mockAuthService.isAuthenticated).thenReturn(false);
        when(() => mockDraftService.saveDraft(any())).thenAnswer((_) async {});

        final draft = _createTestDraft();

        // Act
        final result = await service.publishVideo(draft: draft);

        // Assert
        expect(result, isA<PublishError>());
        expect(
          (result as PublishError).userMessage,
          'Please sign in to publish videos.',
        );
      });

      test('returns success when publish completes successfully', () async {
        // Arrange
        _setupSuccessfulPublish(
          mockAuthService: mockAuthService,
          mockUploadManager: mockUploadManager,
          mockDraftService: mockDraftService,
          mockVideoEventPublisher: mockVideoEventPublisher,
        );

        final draft = _createTestDraft();

        // Act
        final result = await service.publishVideo(draft: draft);

        // Assert
        expect(result, isA<PublishSuccess>());
        verify(() => mockDraftService.deleteDraft(draft.id)).called(1);
      });

      test('returns error when video event publishing fails', () async {
        // Arrange
        when(() => mockAuthService.isAuthenticated).thenReturn(true);
        when(
          () => mockAuthService.currentPublicKeyHex,
        ).thenReturn('test_pubkey');
        when(() => mockDraftService.saveDraft(any())).thenAnswer((_) async {});
        when(() => mockUploadManager.isInitialized).thenReturn(true);
        when(
          () => mockUploadManager.startUploadFromDraft(
            draft: any(named: 'draft'),
            nostrPubkey: any(named: 'nostrPubkey'),
            onProgress: any(named: 'onProgress'),
          ),
        ).thenAnswer(
          (_) async =>
              _createPendingUpload(status: UploadStatus.readyToPublish),
        );
        when(
          () => mockUploadManager.getUpload(any()),
        ).thenReturn(_createPendingUpload(status: UploadStatus.readyToPublish));
        when(
          () => mockVideoEventPublisher.publishVideoEvent(
            upload: any(named: 'upload'),
            title: any(named: 'title'),
            description: any(named: 'description'),
            hashtags: any(named: 'hashtags'),
            expirationTimestamp: any(named: 'expirationTimestamp'),
            allowAudioReuse: any(named: 'allowAudioReuse'),
          ),
        ).thenAnswer((_) async => false);
        when(
          () => mockBlossomService.getBlossomServer(),
        ).thenAnswer((_) async => 'https://test.server');

        final draft = _createTestDraft();

        // Act
        final result = await service.publishVideo(draft: draft);

        // Assert
        expect(result, isA<PublishError>());
      });

      test('saves draft with publishing status before starting', () async {
        // Arrange
        _setupSuccessfulPublish(
          mockAuthService: mockAuthService,
          mockUploadManager: mockUploadManager,
          mockDraftService: mockDraftService,
          mockVideoEventPublisher: mockVideoEventPublisher,
        );

        final draft = _createTestDraft();

        // Act
        await service.publishVideo(draft: draft);

        // Assert
        verify(() => mockDraftService.saveDraft(any())).called(greaterThan(0));
      });

      test('initializes upload manager if not initialized', () async {
        // Arrange
        when(() => mockAuthService.isAuthenticated).thenReturn(true);
        when(
          () => mockAuthService.currentPublicKeyHex,
        ).thenReturn('test_pubkey');
        when(() => mockDraftService.saveDraft(any())).thenAnswer((_) async {});
        when(
          () => mockDraftService.deleteDraft(any()),
        ).thenAnswer((_) async {});
        when(() => mockUploadManager.isInitialized).thenReturn(false);
        when(() => mockUploadManager.initialize()).thenAnswer((_) async {});
        when(
          () => mockUploadManager.startUploadFromDraft(
            draft: any(named: 'draft'),
            nostrPubkey: any(named: 'nostrPubkey'),
            onProgress: any(named: 'onProgress'),
          ),
        ).thenAnswer(
          (_) async =>
              _createPendingUpload(status: UploadStatus.readyToPublish),
        );
        when(
          () => mockUploadManager.getUpload(any()),
        ).thenReturn(_createPendingUpload(status: UploadStatus.readyToPublish));
        when(
          () => mockVideoEventPublisher.publishVideoEvent(
            upload: any(named: 'upload'),
            title: any(named: 'title'),
            description: any(named: 'description'),
            hashtags: any(named: 'hashtags'),
            expirationTimestamp: any(named: 'expirationTimestamp'),
            allowAudioReuse: any(named: 'allowAudioReuse'),
          ),
        ).thenAnswer((_) async => true);

        final draft = _createTestDraft();

        // Act
        await service.publishVideo(draft: draft);

        // Assert
        verify(() => mockUploadManager.initialize()).called(1);
      });

      test('returns error when upload fails', () async {
        // Arrange
        when(() => mockAuthService.isAuthenticated).thenReturn(true);
        when(
          () => mockAuthService.currentPublicKeyHex,
        ).thenReturn('test_pubkey');
        when(() => mockDraftService.saveDraft(any())).thenAnswer((_) async {});
        when(() => mockUploadManager.isInitialized).thenReturn(true);
        when(
          () => mockUploadManager.startUploadFromDraft(
            draft: any(named: 'draft'),
            nostrPubkey: any(named: 'nostrPubkey'),
            onProgress: any(named: 'onProgress'),
          ),
        ).thenAnswer(
          (_) async => _createPendingUpload(
            status: UploadStatus.failed,
            errorMessage: 'Network error',
          ),
        );
        when(() => mockUploadManager.getUpload(any())).thenReturn(
          _createPendingUpload(
            status: UploadStatus.failed,
            errorMessage: 'Network error',
          ),
        );
        when(
          () => mockBlossomService.getBlossomServer(),
        ).thenAnswer((_) async => 'https://test.server');

        final draft = _createTestDraft();

        // Act
        final result = await service.publishVideo(draft: draft);

        // Assert
        expect(result, isA<PublishError>());
      });
    });

    group('retryUpload', () {
      test('returns error when no upload to retry', () async {
        // Arrange
        final draft = _createTestDraft();

        // Act
        final result = await service.retryUpload(draft);

        // Assert
        expect(result, isA<PublishError>());
        expect((result as PublishError).userMessage, 'No upload to retry.');
      });

      test(
        'returns no upload to retry after auth failure clears upload id',
        () async {
          // Arrange - trigger an auth failure to set _backgroundUploadId
          when(() => mockAuthService.isAuthenticated).thenReturn(false);
          when(
            () => mockDraftService.saveDraft(any()),
          ).thenAnswer((_) async {});

          final draft = _createTestDraft();
          await service.publishVideo(draft: draft);

          // Act - retry should fail because auth failure cleared the upload id
          final result = await service.retryUpload(draft);

          // Assert
          expect(result, isA<PublishError>());
          expect((result as PublishError).userMessage, 'No upload to retry.');
        },
      );

      test(
        'returns no upload to retry after upload failure clears upload id',
        () async {
          // Arrange - trigger an upload failure
          when(() => mockAuthService.isAuthenticated).thenReturn(true);
          when(
            () => mockAuthService.currentPublicKeyHex,
          ).thenReturn('test_pubkey');
          when(
            () => mockDraftService.saveDraft(any()),
          ).thenAnswer((_) async {});
          when(() => mockUploadManager.isInitialized).thenReturn(true);
          when(
            () => mockUploadManager.startUploadFromDraft(
              draft: any(named: 'draft'),
              nostrPubkey: any(named: 'nostrPubkey'),
              onProgress: any(named: 'onProgress'),
            ),
          ).thenAnswer(
            (_) async => _createPendingUpload(
              status: UploadStatus.failed,
              errorMessage: 'Network error',
            ),
          );
          when(() => mockUploadManager.getUpload(any())).thenReturn(
            _createPendingUpload(
              status: UploadStatus.failed,
              errorMessage: 'Network error',
            ),
          );
          when(
            () => mockBlossomService.getBlossomServer(),
          ).thenAnswer((_) async => 'https://test.server');

          final draft = _createTestDraft();
          await service.publishVideo(draft: draft);

          // Act - retry should fail because upload failure cleared the id
          final result = await service.retryUpload(draft);

          // Assert
          expect(result, isA<PublishError>());
          expect((result as PublishError).userMessage, 'No upload to retry.');
        },
      );

      test(
        'returns no upload to retry after exception clears upload id',
        () async {
          // Arrange - trigger an exception during publish
          when(() => mockAuthService.isAuthenticated).thenReturn(true);
          when(
            () => mockAuthService.currentPublicKeyHex,
          ).thenReturn('test_pubkey');
          when(
            () => mockDraftService.saveDraft(any()),
          ).thenAnswer((_) async {});
          when(() => mockUploadManager.isInitialized).thenReturn(true);
          when(
            () => mockUploadManager.startUploadFromDraft(
              draft: any(named: 'draft'),
              nostrPubkey: any(named: 'nostrPubkey'),
              onProgress: any(named: 'onProgress'),
            ),
          ).thenThrow(Exception('unexpected error'));
          when(
            () => mockBlossomService.getBlossomServer(),
          ).thenAnswer((_) async => 'https://test.server');

          final draft = _createTestDraft();
          await service.publishVideo(draft: draft);

          // Act - retry should fail because exception cleared the id
          final result = await service.retryUpload(draft);

          // Assert
          expect(result, isA<PublishError>());
          expect((result as PublishError).userMessage, 'No upload to retry.');
        },
      );
    });

    group('error messages', () {
      test('returns user-friendly message for 404 error', () async {
        // Arrange
        when(() => mockAuthService.isAuthenticated).thenReturn(true);
        when(
          () => mockAuthService.currentPublicKeyHex,
        ).thenReturn('test_pubkey');
        when(() => mockDraftService.saveDraft(any())).thenAnswer((_) async {});
        when(() => mockUploadManager.isInitialized).thenReturn(true);
        when(
          () => mockUploadManager.startUploadFromDraft(
            draft: any(named: 'draft'),
            nostrPubkey: any(named: 'nostrPubkey'),
            onProgress: any(named: 'onProgress'),
          ),
        ).thenThrow(Exception('404 not_found'));
        when(
          () => mockBlossomService.getBlossomServer(),
        ).thenAnswer((_) async => 'https://media.divine.video');

        final draft = _createTestDraft();

        // Act
        final result = await service.publishVideo(draft: draft);

        // Assert
        expect(result, isA<PublishError>());
        expect(
          (result as PublishError).userMessage,
          contains('Blossom media server'),
        );
        expect(result.userMessage, contains('not working'));
      });

      test('returns user-friendly message for network error', () async {
        // Arrange
        when(() => mockAuthService.isAuthenticated).thenReturn(true);
        when(
          () => mockAuthService.currentPublicKeyHex,
        ).thenReturn('test_pubkey');
        when(() => mockDraftService.saveDraft(any())).thenAnswer((_) async {});
        when(() => mockUploadManager.isInitialized).thenReturn(true);
        when(
          () => mockUploadManager.startUploadFromDraft(
            draft: any(named: 'draft'),
            nostrPubkey: any(named: 'nostrPubkey'),
            onProgress: any(named: 'onProgress'),
          ),
        ).thenThrow(Exception('network connection failed'));
        when(
          () => mockBlossomService.getBlossomServer(),
        ).thenAnswer((_) async => 'https://media.divine.video');

        final draft = _createTestDraft();

        // Act
        final result = await service.publishVideo(draft: draft);

        // Assert
        expect(result, isA<PublishError>());
        expect((result as PublishError).userMessage, contains('Network error'));
      });
    });
  });
}

// Helper functions

RecordingClip _createTestClip() {
  return RecordingClip(
    id: 'test_clip',
    video: EditorVideo.file('/test/video.mp4'),
    duration: const Duration(seconds: 10),
    recordedAt: DateTime.now(),
    targetAspectRatio: AspectRatio.square,
    originalAspectRatio: 9 / 16,
  );
}

VineDraft _createTestDraft() {
  return VineDraft.create(
    clips: [_createTestClip()],
    title: 'Test Video',
    description: 'Test description',
    hashtags: {'test', 'video'},
    selectedApproach: 'test',
    id: 'test_draft_id',
  );
}

PendingUpload _createPendingUpload({
  required UploadStatus status,
  String? errorMessage,
}) {
  return PendingUpload(
    id: 'test_upload_id',
    localVideoPath: '/test/video.mp4',
    nostrPubkey: 'test_pubkey',
    status: status,
    createdAt: DateTime.now(),
    errorMessage: errorMessage,
    uploadProgress: status == UploadStatus.readyToPublish ? 1.0 : 0.5,
    cdnUrl: 'https://test.cdn/video.mp4',
  );
}

void _setupSuccessfulPublish({
  required MockAuthService mockAuthService,
  required MockUploadManager mockUploadManager,
  required MockDraftStorageService mockDraftService,
  required MockVideoEventPublisher mockVideoEventPublisher,
}) {
  when(() => mockAuthService.isAuthenticated).thenReturn(true);
  when(() => mockAuthService.currentPublicKeyHex).thenReturn('test_pubkey');
  when(() => mockDraftService.saveDraft(any())).thenAnswer((_) async {});
  when(() => mockDraftService.deleteDraft(any())).thenAnswer((_) async {});
  when(() => mockUploadManager.isInitialized).thenReturn(true);
  when(
    () => mockUploadManager.startUploadFromDraft(
      draft: any(named: 'draft'),
      nostrPubkey: any(named: 'nostrPubkey'),
      onProgress: any(named: 'onProgress'),
    ),
  ).thenAnswer(
    (_) async => _createPendingUpload(status: UploadStatus.readyToPublish),
  );
  when(
    () => mockUploadManager.getUpload(any()),
  ).thenReturn(_createPendingUpload(status: UploadStatus.readyToPublish));
  when(
    () => mockVideoEventPublisher.publishVideoEvent(
      upload: any(named: 'upload'),
      title: any(named: 'title'),
      description: any(named: 'description'),
      hashtags: any(named: 'hashtags'),
      expirationTimestamp: any(named: 'expirationTimestamp'),
      allowAudioReuse: any(named: 'allowAudioReuse'),
    ),
  ).thenAnswer((_) async => true);
}
