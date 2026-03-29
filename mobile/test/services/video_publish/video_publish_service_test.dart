// ABOUTME: Tests for VideoPublishService
// ABOUTME: Uses mocked dependencies to test publish flow without real uploads

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' show AspectRatio;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/models/pending_upload.dart';
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
      DivineVideoDraft.create(
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

    group('upload reuse', () {
      test(
        'reuses readyToPublish upload matching video path',
        () async {
          when(() => mockAuthService.isAuthenticated).thenReturn(true);
          when(
            () => mockAuthService.currentPublicKeyHex,
          ).thenReturn('test_pubkey');
          when(
            () => mockDraftService.saveDraft(any()),
          ).thenAnswer((_) async {});
          when(
            () => mockDraftService.deleteDraft(any()),
          ).thenAnswer((_) async {});
          when(() => mockUploadManager.isInitialized).thenReturn(true);

          final readyUpload = _createPendingUpload(
            status: UploadStatus.readyToPublish,
          );
          when(
            () => mockUploadManager.findReusableUpload(any()),
          ).thenReturn(readyUpload);
          when(
            () => mockUploadManager.getUpload(any()),
          ).thenReturn(readyUpload);
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
          final result = await service.publishVideo(draft: draft);

          expect(result, isA<PublishSuccess>());
          // Should NOT have started a new upload.
          verifyNever(
            () => mockUploadManager.startUploadFromDraft(
              draft: any(named: 'draft'),
              nostrPubkey: any(named: 'nostrPubkey'),
              onProgress: any(named: 'onProgress'),
            ),
          );
        },
      );

      test(
        'falls through to new upload when no reusable upload exists',
        () async {
          _setupSuccessfulPublish(
            mockAuthService: mockAuthService,
            mockUploadManager: mockUploadManager,
            mockDraftService: mockDraftService,
            mockVideoEventPublisher: mockVideoEventPublisher,
          );

          // Explicitly return null for path lookup.
          when(
            () => mockUploadManager.findReusableUpload(any()),
          ).thenReturn(null);

          final draft = _createTestDraft();
          final result = await service.publishVideo(draft: draft);

          expect(result, isA<PublishSuccess>());
          verify(
            () => mockUploadManager.startUploadFromDraft(
              draft: any(named: 'draft'),
              nostrPubkey: any(named: 'nostrPubkey'),
              onProgress: any(named: 'onProgress'),
            ),
          ).called(1);
        },
      );

      test(
        'resumes interrupted upload when reusable upload is in '
        'uploading status',
        () async {
          when(() => mockAuthService.isAuthenticated).thenReturn(true);
          when(
            () => mockAuthService.currentPublicKeyHex,
          ).thenReturn('test_pubkey');
          when(
            () => mockDraftService.saveDraft(any()),
          ).thenAnswer((_) async {});
          when(
            () => mockDraftService.deleteDraft(any()),
          ).thenAnswer((_) async {});
          when(() => mockUploadManager.isInitialized).thenReturn(true);

          final uploadingUpload = _createPendingUpload(
            status: UploadStatus.uploading,
          );
          final readyUpload = _createPendingUpload(
            status: UploadStatus.readyToPublish,
          );

          when(
            () => mockUploadManager.findReusableUpload(any()),
          ).thenReturn(uploadingUpload);

          // First call returns uploading (triggers resume),
          // subsequent calls return readyToPublish (poll succeeds).
          var getUploadCalls = 0;
          when(() => mockUploadManager.getUpload(any())).thenAnswer((_) {
            getUploadCalls++;
            return getUploadCalls <= 1 ? uploadingUpload : readyUpload;
          });
          when(
            () => mockUploadManager.resumeInterruptedUpload(any()),
          ).thenReturn(null);
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
          final result = await service.publishVideo(draft: draft);

          expect(result, isA<PublishSuccess>());
          verify(
            () => mockUploadManager.resumeInterruptedUpload(
              uploadingUpload.id,
            ),
          ).called(1);
          verifyNever(
            () => mockUploadManager.startUploadFromDraft(
              draft: any(named: 'draft'),
              nostrPubkey: any(named: 'nostrPubkey'),
              onProgress: any(named: 'onProgress'),
            ),
          );
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
          contains('media server'),
        );
        expect(result.userMessage, contains('not available'));
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
        expect(
          (result as PublishError).userMessage,
          contains('Something went wrong'),
        );
      });

      test('returns user-friendly message for timeout error', () async {
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
        ).thenThrow(Exception('Connection timed out'));
        when(
          () => mockBlossomService.getBlossomServer(),
        ).thenAnswer((_) async => 'https://media.divine.video');

        final draft = _createTestDraft();
        final result = await service.publishVideo(draft: draft);

        expect(result, isA<PublishError>());
        expect(
          (result as PublishError).userMessage,
          contains('timed out'),
        );
      });

      test('returns user-friendly message for TLS/certificate error', () async {
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
        ).thenThrow(Exception('HandshakeException: certificate verify failed'));
        when(
          () => mockBlossomService.getBlossomServer(),
        ).thenAnswer((_) async => 'https://media.divine.video');

        final draft = _createTestDraft();
        final result = await service.publishVideo(draft: draft);

        expect(result, isA<PublishError>());
        expect(
          (result as PublishError).userMessage,
          contains('Secure connection failed'),
        );
      });

      test('returns user-friendly message for 413 payload too large', () async {
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
        ).thenThrow(Exception('413 payload too large'));
        when(
          () => mockBlossomService.getBlossomServer(),
        ).thenAnswer((_) async => 'https://media.divine.video');

        final draft = _createTestDraft();
        final result = await service.publishVideo(draft: draft);

        expect(result, isA<PublishError>());
        expect(
          (result as PublishError).userMessage,
          contains('too large'),
        );
      });

      test(
        'returns user-friendly message for 500 internal server error',
        () async {
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
          ).thenThrow(Exception('500 internal server error'));
          when(
            () => mockBlossomService.getBlossomServer(),
          ).thenAnswer((_) async => 'https://media.divine.video');

          final draft = _createTestDraft();
          final result = await service.publishVideo(draft: draft);

          expect(result, isA<PublishError>());
          final msg = (result as PublishError).userMessage;
          expect(msg, contains('internal error'));
          expect(msg, contains('media.divine.video'));
        },
      );

      test(
        'returns user-friendly message for 502/503 service unavailable',
        () async {
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
          ).thenThrow(Exception('502 bad gateway'));
          when(
            () => mockBlossomService.getBlossomServer(),
          ).thenAnswer((_) async => 'https://media.divine.video');

          final draft = _createTestDraft();
          final result = await service.publishVideo(draft: draft);

          expect(result, isA<PublishError>());
          final msg = (result as PublishError).userMessage;
          expect(msg, contains('temporarily down'));
          expect(msg, contains('media.divine.video'));
        },
      );

      test('returns user-friendly message for 401 unauthorized', () async {
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
        ).thenThrow(Exception('401 unauthorized'));
        when(
          () => mockBlossomService.getBlossomServer(),
        ).thenAnswer((_) async => 'https://media.divine.video');

        final draft = _createTestDraft();
        final result = await service.publishVideo(draft: draft);

        expect(result, isA<PublishError>());
        expect(
          (result as PublishError).userMessage,
          contains('sign in'),
        );
      });

      test('returns user-friendly message for 403 forbidden', () async {
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
        ).thenThrow(Exception('403 forbidden'));
        when(
          () => mockBlossomService.getBlossomServer(),
        ).thenAnswer((_) async => 'https://media.divine.video');

        final draft = _createTestDraft();
        final result = await service.publishVideo(draft: draft);

        expect(result, isA<PublishError>());
        expect(
          (result as PublishError).userMessage,
          contains('permission'),
        );
      });

      test('returns user-friendly message for file not found', () async {
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
        ).thenThrow(Exception('No such file or directory'));
        when(
          () => mockBlossomService.getBlossomServer(),
        ).thenAnswer((_) async => 'https://media.divine.video');

        final draft = _createTestDraft();
        final result = await service.publishVideo(draft: draft);

        expect(result, isA<PublishError>());
        expect(
          (result as PublishError).userMessage,
          contains('could not be found'),
        );
      });

      test('returns user-friendly message for storage full', () async {
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
        ).thenThrow(Exception('no space left, disk full'));
        when(
          () => mockBlossomService.getBlossomServer(),
        ).thenAnswer((_) async => 'https://media.divine.video');

        final draft = _createTestDraft();
        final result = await service.publishVideo(draft: draft);

        expect(result, isA<PublishError>());
        expect(
          (result as PublishError).userMessage,
          contains('storage'),
        );
      });

      test('returns user-friendly message for Nostr relay failure', () async {
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
        ).thenThrow(Exception('Failed to publish nostr event'));
        when(
          () => mockBlossomService.getBlossomServer(),
        ).thenAnswer((_) async => 'https://media.divine.video');

        final draft = _createTestDraft();
        final result = await service.publishVideo(draft: draft);

        expect(result, isA<PublishError>());
        final msg = (result as PublishError).userMessage;
        expect(msg, contains('relay'));
      });

      test('returns user-friendly message for SocketException '
          '(no internet)', () async {
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
        ).thenThrow(Exception('SocketException: Network is unreachable'));
        when(
          () => mockBlossomService.getBlossomServer(),
        ).thenAnswer((_) async => 'https://media.divine.video');

        final draft = _createTestDraft();
        final result = await service.publishVideo(draft: draft);

        expect(result, isA<PublishError>());
        expect(
          (result as PublishError).userMessage,
          contains('No internet connection'),
        );
      });

      test('returns user-friendly message for connection refused', () async {
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
        ).thenThrow(Exception('Connection refused'));
        when(
          () => mockBlossomService.getBlossomServer(),
        ).thenAnswer((_) async => 'https://media.divine.video');

        final draft = _createTestDraft();
        final result = await service.publishVideo(draft: draft);

        expect(result, isA<PublishError>());
        expect(
          (result as PublishError).userMessage,
          contains('Could not reach the server'),
        );
      });
    });
  });
}

// Helper functions

DivineVideoClip _createTestClip() {
  return DivineVideoClip(
    id: 'test_clip',
    video: EditorVideo.file('/test/video.mp4'),
    duration: const Duration(seconds: 10),
    recordedAt: DateTime.now(),
    targetAspectRatio: AspectRatio.square,
    originalAspectRatio: 9 / 16,
  );
}

DivineVideoDraft _createTestDraft() {
  return DivineVideoDraft.create(
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
