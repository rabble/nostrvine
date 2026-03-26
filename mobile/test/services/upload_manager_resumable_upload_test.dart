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
  });
}
