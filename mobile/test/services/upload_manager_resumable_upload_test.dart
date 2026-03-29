import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/models/blossom_resumable_upload_session.dart';
import 'package:openvine/models/pending_upload.dart';
import 'package:openvine/services/blossom_upload_service.dart';
import 'package:openvine/services/upload_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_helpers.dart';

class _MockBlossomUploadService extends Mock implements BlossomUploadService {}

void main() {
  setUpAll(() async {
    await setupTestEnvironment();
    registerFallbackValue(File(''));
    registerFallbackValue(
      const BlossomResumableUploadSession(
        uploadId: 'fallback',
        uploadUrl: 'https://upload.divine.video/sessions/fallback',
        chunkSize: 4,
        nextOffset: 0,
      ),
    );
  });

  group('UploadManager resumable uploads', () {
    late _MockBlossomUploadService mockBlossomService;
    late UploadManager uploadManager;
    late Directory tempDir;
    late File videoFile;

    setUp(() async {
      await TestHelpers.cleanupHiveBox('pending_uploads');
      SharedPreferences.setMockInitialValues({});

      tempDir = await Directory.systemTemp.createTemp(
        'upload_manager_resumable_',
      );
      videoFile = File('${tempDir.path}/video.mp4')
        ..writeAsBytesSync(List<int>.generate(32, (index) => index));

      mockBlossomService = _MockBlossomUploadService();
      when(() => mockBlossomService.isBlossomEnabled()).thenAnswer(
        (_) async => false,
      );

      uploadManager = UploadManager(blossomService: mockBlossomService);
      await uploadManager.initialize();
      await TestHelpers.ensureBoxEmpty<PendingUpload>('pending_uploads');
    });

    tearDown(() async {
      uploadManager.dispose();
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'restarts a Divine resumable upload from the last committed offset after app restart',
      () async {
        final upload =
            PendingUpload.create(
              localVideoPath: videoFile.path,
              nostrPubkey: 'test-pubkey',
              title: 'Resumable video',
            ).copyWith(
              status: UploadStatus.uploading,
              uploadProgress: 0.4,
              resumableSession: const BlossomResumableUploadSession(
                uploadId: 'up_123',
                uploadUrl: 'https://upload.divine.video/sessions/up_123',
                chunkSize: 8,
                nextOffset: 16,
              ),
            );

        await Hive.box<PendingUpload>('pending_uploads').put(upload.id, upload);
        uploadManager.dispose();

        final resumeStarted = Completer<void>();
        when(
          () => mockBlossomService.uploadVideo(
            videoFile: any(named: 'videoFile'),
            nostrPubkey: any(named: 'nostrPubkey'),
            title: any(named: 'title'),
            description: any(named: 'description'),
            hashtags: any(named: 'hashtags'),
            proofManifestJson: any(named: 'proofManifestJson'),
            resumableSession: any(named: 'resumableSession'),
            onResumableSessionUpdated: any(
              named: 'onResumableSessionUpdated',
            ),
            onProgress: any(named: 'onProgress'),
          ),
        ).thenAnswer((invocation) async {
          final session =
              invocation.namedArguments[#resumableSession]
                  as BlossomResumableUploadSession?;
          final onResumableSessionUpdated =
              invocation.namedArguments[#onResumableSessionUpdated]
                  as void Function(BlossomResumableUploadSession)?;

          expect(session?.uploadId, equals('up_123'));
          expect(session?.nextOffset, equals(16));

          onResumableSessionUpdated?.call(
            session!.copyWith(nextOffset: 32),
          );
          resumeStarted.complete();

          return const BlossomUploadResult(
            success: true,
            videoId: 'video-123',
            url: 'https://media.divine.video/video-123',
            fallbackUrl: 'https://media.divine.video/video-123',
          );
        });

        uploadManager = UploadManager(blossomService: mockBlossomService);
        await uploadManager.initialize();

        await TestHelpers.waitForCondition(
          () => resumeStarted.isCompleted,
          timeout: const Duration(seconds: 1),
          checkInterval: const Duration(milliseconds: 20),
        );
        await TestHelpers.waitForCondition(() {
          final currentUpload = uploadManager.getUpload(upload.id);
          return currentUpload?.status == UploadStatus.readyToPublish;
        });

        final resumedUpload = uploadManager.getUpload(upload.id);
        expect(resumedUpload, isNotNull);
        expect(resumedUpload!.videoId, equals('video-123'));
        expect(
          resumedUpload.cdnUrl,
          equals('https://media.divine.video/video-123'),
        );
        expect(resumedUpload.resumableSession, isNull);
      },
    );

    test(
      'falls back to failed state when a session expires and cannot be resumed',
      () async {
        final upload =
            PendingUpload.create(
              localVideoPath: videoFile.path,
              nostrPubkey: 'test-pubkey',
              title: 'Expired resumable video',
            ).copyWith(
              status: UploadStatus.uploading,
              uploadProgress: 0.4,
              resumableSession: const BlossomResumableUploadSession(
                uploadId: 'up_123',
                uploadUrl: 'https://upload.divine.video/sessions/up_123',
                chunkSize: 8,
                nextOffset: 16,
              ),
            );

        await Hive.box<PendingUpload>('pending_uploads').put(upload.id, upload);
        uploadManager.dispose();

        final resumeAttempted = Completer<void>();
        when(
          () => mockBlossomService.uploadVideo(
            videoFile: any(named: 'videoFile'),
            nostrPubkey: any(named: 'nostrPubkey'),
            title: any(named: 'title'),
            description: any(named: 'description'),
            hashtags: any(named: 'hashtags'),
            proofManifestJson: any(named: 'proofManifestJson'),
            resumableSession: any(named: 'resumableSession'),
            onResumableSessionUpdated: any(
              named: 'onResumableSessionUpdated',
            ),
            onProgress: any(named: 'onProgress'),
          ),
        ).thenAnswer((_) async {
          resumeAttempted.complete();
          throw const BlossomResumableUploadException(
            'Resumable upload session expired',
            statusCode: 410,
          );
        });

        uploadManager = UploadManager(blossomService: mockBlossomService);
        await uploadManager.initialize();

        await TestHelpers.waitForCondition(
          () => resumeAttempted.isCompleted,
          timeout: const Duration(seconds: 1),
          checkInterval: const Duration(milliseconds: 20),
        );
        await TestHelpers.waitForCondition(() {
          final currentUpload = uploadManager.getUpload(upload.id);
          return currentUpload?.status == UploadStatus.failed;
        });

        final failedUpload = uploadManager.getUpload(upload.id);
        expect(failedUpload, isNotNull);
        expect(failedUpload!.status, equals(UploadStatus.failed));
        expect(failedUpload.resumableSession, isNull);
        expect(failedUpload.errorMessage, contains('session expired'));
      },
    );

    test(
      'serializes rapid session-progress writes so the latest offset wins',
      () async {
        const chunkSize = 8;
        const fileSize = 80;

        // Create a file of the expected size so lengthSync() is consistent.
        videoFile = File('${tempDir.path}/video_serial.mp4')
          ..writeAsBytesSync(List<int>.generate(fileSize, (i) => i));

        final uploadCompleter = Completer<BlossomUploadResult>();

        // Capture the onResumableSessionUpdated callback so we can call it
        // rapidly ourselves.
        void Function(BlossomResumableUploadSession)? capturedCallback;

        when(
          () => mockBlossomService.uploadVideo(
            videoFile: any(named: 'videoFile'),
            nostrPubkey: any(named: 'nostrPubkey'),
            title: any(named: 'title'),
            description: any(named: 'description'),
            hashtags: any(named: 'hashtags'),
            proofManifestJson: any(named: 'proofManifestJson'),
            resumableSession: any(named: 'resumableSession'),
            onResumableSessionUpdated: any(
              named: 'onResumableSessionUpdated',
            ),
            onProgress: any(named: 'onProgress'),
          ),
        ).thenAnswer((invocation) async {
          capturedCallback =
              invocation.namedArguments[#onResumableSessionUpdated]
                  as void Function(BlossomResumableUploadSession)?;

          return uploadCompleter.future;
        });

        // Start the upload without awaiting — startUpload blocks until the
        // upload completes, but we need to interact with the callback
        // mid-upload.
        unawaited(
          uploadManager.startUpload(
            videoFile: videoFile,
            nostrPubkey: 'test-pubkey',
            title: 'Serialization test',
          ),
        );

        // Wait for the mock to capture the callback.
        await TestHelpers.waitForCondition(
          () => capturedCallback != null,
          timeout: const Duration(seconds: 2),
        );

        // Grab the upload ID from the box since startUpload hasn't returned.
        final uploads = uploadManager.pendingUploads;
        expect(uploads, isNotEmpty);
        final uploadId = uploads.first.id;

        // Fire 5 rapid session updates without awaiting (simulates real
        // chunk-completion callbacks arriving in quick succession).
        for (var i = 1; i <= 5; i++) {
          capturedCallback!(
            BlossomResumableUploadSession(
              uploadId: 'up_serial',
              uploadUrl: 'https://upload.divine.video/sessions/up_serial',
              chunkSize: chunkSize,
              nextOffset: chunkSize * i,
            ),
          );
        }

        // Allow the serialized futures to drain.
        await TestHelpers.waitForCondition(
          () {
            final u = uploadManager.getUpload(uploadId);
            if (u == null) return false;
            const expectedOffset = chunkSize * 5;
            return u.resumableSession?.nextOffset == expectedOffset;
          },
          timeout: const Duration(seconds: 2),
          checkInterval: const Duration(milliseconds: 20),
        );

        final persisted = uploadManager.getUpload(uploadId)!;
        expect(persisted.resumableSession?.nextOffset, equals(chunkSize * 5));

        final expectedProgress = ((chunkSize * 5) / fileSize * 0.8).clamp(
          0.0,
          0.8,
        );
        expect(persisted.uploadProgress, closeTo(expectedProgress, 0.001));

        // Complete the upload future to let tearDown dispose cleanly.
        uploadCompleter.complete(
          const BlossomUploadResult(
            success: true,
            videoId: 'video-serial',
            url: 'https://media.divine.video/video-serial',
            fallbackUrl: 'https://media.divine.video/video-serial',
          ),
        );
      },
    );
  });
}
