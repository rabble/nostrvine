// ABOUTME: Unit tests for UploadManager.getUploadByFilePath method
// ABOUTME: Tests file path lookup functionality using the public API

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/models/pending_upload.dart';
import 'package:openvine/services/blossom_upload_service.dart';
import 'package:openvine/services/upload_manager.dart';
import '../../helpers/real_integration_test_helper.dart';
import '../../helpers/test_helpers.dart';

class MockBlossomUploadService extends Mock implements BlossomUploadService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late UploadManager uploadManager;
  late MockBlossomUploadService mockUploadService;
  late Directory tempDir;

  setUpAll(() async {
    // Setup test environment with platform channel mocks
    await RealIntegrationTestHelper.setupTestEnvironment();
    registerFallbackValue(File(''));
    // Initialize Hive for testing
    await Hive.initFlutter();

    // CRITICAL: Delete the entire pending_uploads box from disk ONCE before any tests run
    // This ensures we don't have accumulated data from previous test runs
    try {
      if (Hive.isBoxOpen('pending_uploads')) {
        await Hive.box('pending_uploads').close();
      }
      await Hive.deleteBoxFromDisk('pending_uploads');
    } catch (e) {
      // Box might not exist, that's fine
    }
  });

  setUp(() async {
    // Use the reusable test helper to ensure a fresh empty Hive box
    await TestHelpers.cleanupHiveBox('pending_uploads');
    tempDir = await Directory.systemTemp.createTemp(
      'upload_manager_get_by_path_test_',
    );

    mockUploadService = MockBlossomUploadService();
    when(() => mockUploadService.isBlossomEnabled()).thenAnswer(
      (_) async => false,
    );
    when(
      () => mockUploadService.uploadVideo(
        videoFile: any(named: 'videoFile'),
        nostrPubkey: any(named: 'nostrPubkey'),
        title: any(named: 'title'),
        description: any(named: 'description'),
        hashtags: any(named: 'hashtags'),
        proofManifestJson: any(named: 'proofManifestJson'),
        resumableSession: any(named: 'resumableSession'),
        onResumableSessionUpdated: any(named: 'onResumableSessionUpdated'),
        onProgress: any(named: 'onProgress'),
      ),
    ).thenAnswer(
      (_) async => const BlossomUploadResult(
        success: true,
        videoId: 'test-video-id',
      ),
    );
    uploadManager = UploadManager(blossomService: mockUploadService);

    // Initialize creates a fresh empty box
    await uploadManager.initialize();

    // CRITICAL: Explicitly clear the box after initialization to remove any stale data
    await TestHelpers.ensureBoxEmpty<PendingUpload>('pending_uploads');
  });

  tearDown(() async {
    // Clean up after each test using proper async coordination
    try {
      // Dispose the upload manager and wait for completion
      uploadManager.dispose();

      // Use proper async coordination instead of arbitrary delays
      await Future.microtask(() {});

      // Close the box if it's still open
      if (Hive.isBoxOpen('pending_uploads')) {
        final box = Hive.box('pending_uploads');
        await box.close();
      }
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    } catch (e) {
      // Manager or box might already be disposed/closed
    }
    reset(mockUploadService);
  });

  File createVideoFile(String relativePath, List<int> bytes) {
    final file = File('${tempDir.path}/$relativePath');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes);
    return file;
  }

  group('UploadManager.getUploadByFilePath', () {
    test('should return upload with matching file path', () async {
      // Arrange - Create some test uploads
      final file1 = createVideoFile('path/to/video1.mp4', [0, 1, 2]);
      final file2 = createVideoFile('path/to/video2.mp4', [3, 4, 5]);
      final file3 = createVideoFile('path/to/video3.mp4', [6, 7, 8]);

      // Start uploads to create PendingUpload entries
      await uploadManager.startUpload(
        videoFile: file1,
        nostrPubkey: 'pubkey1',
      );
      await uploadManager.startUpload(
        videoFile: file2,
        nostrPubkey: 'pubkey2',
      );
      await uploadManager.startUpload(
        videoFile: file3,
        nostrPubkey: 'pubkey3',
      );

      // Act
      final result = uploadManager.getUploadByFilePath(file2.path);

      // Assert
      expect(result, isNotNull);
      expect(result?.localVideoPath, equals(file2.path));
      expect(result?.nostrPubkey, equals('pubkey2'));
    });

    test('should return null when no upload matches file path', () async {
      // Arrange
      final file1 = createVideoFile('path/to/video1.mp4', [0, 1, 2]);

      await uploadManager.startUpload(
        videoFile: file1,
        nostrPubkey: 'pubkey1',
      );

      // Act
      final missingPath = '${tempDir.path}/path/to/nonexistent.mp4';
      final result = uploadManager.getUploadByFilePath(missingPath);

      // Assert
      expect(result, isNull);
    });

    test('should return null when pendingUploads is empty', () {
      // Act
      final result = uploadManager.getUploadByFilePath('/path/to/video.mp4');

      // Assert
      expect(result, isNull);
    });

    test('should handle file paths with spaces', () async {
      // Arrange
      final file = createVideoFile('path with spaces/my video.mp4', [0, 1, 2]);

      await uploadManager.startUpload(
        videoFile: file,
        nostrPubkey: 'pubkey1',
      );

      // Act
      final result = uploadManager.getUploadByFilePath(file.path);

      // Assert
      expect(result, isNotNull);
      expect(result?.localVideoPath, equals(file.path));
    });

    test('should handle special characters in file paths', () async {
      // Arrange
      final file = createVideoFile(r'path/to/video@#$%^&()_+.mp4', [0, 1, 2]);

      await uploadManager.startUpload(
        videoFile: file,
        nostrPubkey: 'pubkey1',
      );

      // Act
      final result = uploadManager.getUploadByFilePath(file.path);

      // Assert
      expect(result, isNotNull);
      expect(result?.localVideoPath, equals(file.path));
    });

    test(
      'should return first match when multiple uploads have same path',
      () async {
        // This shouldn't normally happen, but let's test the edge case
        // We'll create uploads with different timestamps
        final file = createVideoFile('path/to/duplicate.mp4', [0, 1, 2]);

        await uploadManager.startUpload(
          videoFile: file,
          nostrPubkey: 'pubkey1',
        );

        // Use proper async coordination to ensure different timestamps
        // Check that first upload is tracked before creating second
        expect(uploadManager.pendingUploads.length, equals(1));

        await uploadManager.startUpload(
          videoFile: file,
          nostrPubkey: 'pubkey2',
        );

        // Act
        final result = uploadManager.getUploadByFilePath(file.path);
        final allUploads = uploadManager.pendingUploads;

        // Assert
        expect(result, isNotNull);
        expect(
          allUploads.where((u) => u.localVideoPath == file.path).length,
          2,
        );
        // The method returns the first match from the sorted list (newest first)
        expect(
          result?.nostrPubkey,
          equals('pubkey2'),
        ); // The second upload should be newer
      },
    );

    test('should be case sensitive', () async {
      // Arrange
      final file = createVideoFile('Path/To/Video.mp4', [0, 1, 2]);

      await uploadManager.startUpload(
        videoFile: file,
        nostrPubkey: 'pubkey1',
      );

      // Act
      final resultLowerCase = uploadManager.getUploadByFilePath(
        '${tempDir.path}/path/to/video.mp4',
      );
      final resultCorrectCase = uploadManager.getUploadByFilePath(file.path);

      // Assert
      expect(resultLowerCase, isNull);
      expect(resultCorrectCase, isNotNull);
      expect(resultCorrectCase?.localVideoPath, equals(file.path));
    });
  });
}
