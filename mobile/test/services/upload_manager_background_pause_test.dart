// ABOUTME: Regression tests for the pause/cancel race on OS background uploads.
// ABOUTME: A user-initiated stop must not be reported as a failure.

import 'dart:async';
import 'dart:io';

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/models/pending_upload.dart';
import 'package:openvine/services/upload/upload_ports.dart';
import 'package:openvine/services/upload_manager.dart';

class _MockBlossomUploadService extends Mock implements BlossomUploadService {}

class _MockUploadCrashReporter extends Mock implements UploadCrashReporter {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockBlossomUploadService mockBlossomService;
  late _MockUploadCrashReporter mockCrashReporter;
  late UploadManager uploadManager;
  late Directory testDir;

  setUpAll(() {
    registerFallbackValue(File(''));
    registerFallbackValue(StackTrace.empty);
  });

  setUp(() async {
    testDir = await Directory.systemTemp.createTemp(
      'upload_manager_bg_pause_test_',
    );
    Hive.init(testDir.path);
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(UploadStatusAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(PendingUploadAdapter());
    }

    mockBlossomService = _MockBlossomUploadService();
    mockCrashReporter = _MockUploadCrashReporter();
    when(() => mockBlossomService.isBlossomEnabled()).thenAnswer((_) async {
      return false;
    });
    when(
      () => mockCrashReporter.recordError(
        any(),
        any(),
        reason: any(named: 'reason'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => mockCrashReporter.setCustomKey(any(), any()),
    ).thenAnswer((_) async {});

    uploadManager = UploadManager(
      blossomService: mockBlossomService,
      crashReporter: mockCrashReporter,
      useBackgroundUpload: true,
    );
    await uploadManager.initialize();
  });

  tearDown(() async {
    uploadManager.dispose();
    try {
      await Hive.close();
    } on PathNotFoundException catch (_) {
      // Hive may already have removed the lock file during async shutdown.
    }
    try {
      await testDir.delete(recursive: true);
    } on PathNotFoundException catch (_) {
      // Lock file may already be deleted by Hive.close().
    }
  });

  // Stubs an OS background transfer that never finishes on its own; cancelling
  // it resolves the future with a `cancelled` failure — the race trigger.
  Completer<BlossomUploadResult> stubCancellableTransfer() {
    final transfer = Completer<BlossomUploadResult>();
    when(
      () => mockBlossomService.uploadVideoInBackground(
        videoFile: any(named: 'videoFile'),
        taskId: any(named: 'taskId'),
        proofManifestJson: any(named: 'proofManifestJson'),
        onProgress: any(named: 'onProgress'),
      ),
    ).thenAnswer((_) => transfer.future);
    when(() => mockBlossomService.cancelBackgroundUpload(any())).thenAnswer((
      _,
    ) async {
      if (!transfer.isCompleted) {
        transfer.complete(
          const BlossomUploadResult(
            success: false,
            errorMessage: 'Upload cancelled',
            failureReason: BlossomUploadFailureReason.unknown,
          ),
        );
      }
    });
    return transfer;
  }

  Future<PendingUpload> seedPausedUpload() async {
    final videoFile = File(
      '${testDir.path}/${DateTime.now().microsecondsSinceEpoch}.mp4',
    );
    await videoFile.writeAsString('fake video content');
    final upload = PendingUpload.create(
      localVideoPath: videoFile.path,
      nostrPubkey: 'pk',
      title: 'T',
    );
    final box = Hive.box<PendingUpload>('pending_uploads');
    await box.put(upload.id, upload.copyWith(status: UploadStatus.paused));
    return upload;
  }

  group('UploadManager background pause/cancel race', () {
    test(
      'pausing an in-flight background upload leaves it paused, not failed',
      () async {
        final upload = await seedPausedUpload();
        stubCancellableTransfer();

        // resumeUpload() drives a fresh _performUpload run; it stays in flight
        // on the transfer future until the pause cancels it.
        final runFuture = uploadManager.resumeUpload(upload.id);
        await _pumpUntil(
          () =>
              uploadManager.getUpload(upload.id)?.status ==
              UploadStatus.uploading,
        );

        await uploadManager.pauseUpload(upload.id);
        await runFuture;

        final result = uploadManager.getUpload(upload.id);
        expect(result?.status, equals(UploadStatus.paused));
        expect(result?.errorMessage, isNull);
        verify(
          () => mockBlossomService.cancelBackgroundUpload(upload.id),
        ).called(1);
        // The user-initiated pause is not a crash.
        verifyNever(
          () => mockCrashReporter.recordError(
            any(),
            any(),
            reason: any(named: 'reason'),
          ),
        );
      },
    );

    test(
      'cancelling an in-flight background upload marks it failed without a crash report',
      () async {
        final upload = await seedPausedUpload();
        stubCancellableTransfer();

        final runFuture = uploadManager.resumeUpload(upload.id);
        await _pumpUntil(
          () =>
              uploadManager.getUpload(upload.id)?.status ==
              UploadStatus.uploading,
        );

        await uploadManager.cancelUpload(upload.id);
        await runFuture;

        final result = uploadManager.getUpload(upload.id);
        expect(result?.status, equals(UploadStatus.failed));
        expect(result?.errorMessage, equals('Upload cancelled by user'));
        // A deliberate cancel must not be reported to Crashlytics as a failure.
        verifyNever(
          () => mockCrashReporter.recordError(
            any(),
            any(),
            reason: any(named: 'reason'),
          ),
        );
      },
    );
  });
}

Future<void> _pumpUntil(bool Function() predicate) async {
  for (var i = 0; i < 200; i++) {
    if (predicate()) return;
    await Future<void>.delayed(Duration.zero);
  }
  fail('Condition was not met in time');
}
