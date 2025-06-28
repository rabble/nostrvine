// ABOUTME: Unit tests for UploadManager service including getUploadByFilePath method
// ABOUTME: Tests file path lookup functionality and edge cases

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/models/pending_upload.dart';
import 'package:openvine/services/upload_manager.dart';
import 'package:openvine/services/direct_upload_service.dart';
import 'package:hive/hive.dart';

class MockDirectUploadService extends Mock implements DirectUploadService {}
class MockBox<T> extends Mock implements Box<T> {
  @override
  bool get isOpen => true;
}
void main() {
  late UploadManager uploadManager;
  late MockDirectUploadService mockUploadService;
  late MockBox<PendingUpload> mockPendingUploadsBox;

  setUp(() {
    mockUploadService = MockDirectUploadService();
    mockPendingUploadsBox = MockBox<PendingUpload>();

    // Create upload manager with mocks
    uploadManager = UploadManager(
      uploadService: mockUploadService,
    );

    // Note: We can't directly set the pendingUploadsBox as it's private
    // So we'll test the public API methods only
  });

  group('UploadManager', () {
    group('getUploadByFilePath', () {
      test('should return upload with matching file path', () {
        // Arrange
        final upload1 = PendingUpload.create(
          localVideoPath: '/path/to/video1.mp4',
          nostrPubkey: 'pubkey1',
        );
        final upload2 = PendingUpload.create(
          localVideoPath: '/path/to/video2.mp4',
          nostrPubkey: 'pubkey2',
        );
        final upload3 = PendingUpload.create(
          localVideoPath: '/path/to/video3.mp4',
          nostrPubkey: 'pubkey3',
        );

        uploadManager.pendingUploads.addAll([upload1, upload2, upload3]);

        // Act
        final result = uploadManager.getUploadByFilePath('/path/to/video2.mp4');

        // Assert
        expect(result, equals(upload2));
        expect(result?.localVideoPath, equals('/path/to/video2.mp4'));
      });

      test('should return null when no upload matches file path', () {
        // Arrange
        final upload1 = PendingUpload.create(
          localVideoPath: '/path/to/video1.mp4',
          nostrPubkey: 'pubkey1',
        );
        final upload2 = PendingUpload.create(
          localVideoPath: '/path/to/video2.mp4',
          nostrPubkey: 'pubkey2',
        );

        uploadManager.pendingUploads.addAll([upload1, upload2]);

        // Act
        final result = uploadManager.getUploadByFilePath('/path/to/nonexistent.mp4');

        // Assert
        expect(result, isNull);
      });

      test('should return null when pendingUploads is empty', () {
        // Arrange - empty list

        // Act
        final result = uploadManager.getUploadByFilePath('/path/to/video.mp4');

        // Assert
        expect(result, isNull);
      });

      test('should handle file paths with spaces', () {
        // Arrange
        final uploadWithSpaces = PendingUpload.create(
          localVideoPath: '/path with spaces/my video.mp4',
          nostrPubkey: 'pubkey1',
        );

        uploadManager.pendingUploads.add(uploadWithSpaces);

        // Act
        final result = uploadManager.getUploadByFilePath('/path with spaces/my video.mp4');

        // Assert
        expect(result, equals(uploadWithSpaces));
      });

      test('should handle special characters in file paths', () {
        // Arrange
        final uploadWithSpecialChars = PendingUpload.create(
          localVideoPath: '/path/to/video@#\$%^&()_+.mp4',
          nostrPubkey: 'pubkey1',
        );

        uploadManager.pendingUploads.add(uploadWithSpecialChars);

        // Act
        final result = uploadManager.getUploadByFilePath('/path/to/video@#\$%^&()_+.mp4');

        // Assert
        expect(result, equals(uploadWithSpecialChars));
      });

      test('should return first match when multiple uploads have same path', () {
        // Arrange
        final upload1 = PendingUpload.create(
          localVideoPath: '/path/to/duplicate.mp4',
          nostrPubkey: 'pubkey1',
        );
        final upload2 = PendingUpload.create(
          localVideoPath: '/path/to/duplicate.mp4',
          nostrPubkey: 'pubkey2',
        );

        uploadManager.pendingUploads.addAll([upload1, upload2]);

        // Act
        final result = uploadManager.getUploadByFilePath('/path/to/duplicate.mp4');

        // Assert
        expect(result, equals(upload1));
      });

      test('should be case sensitive', () {
        // Arrange
        final upload = PendingUpload.create(
          localVideoPath: '/Path/To/Video.mp4',
          nostrPubkey: 'pubkey1',
        );

        uploadManager.pendingUploads.add(upload);

        // Act
        final resultLowerCase = uploadManager.getUploadByFilePath('/path/to/video.mp4');
        final resultCorrectCase = uploadManager.getUploadByFilePath('/Path/To/Video.mp4');

        // Assert
        expect(resultLowerCase, isNull);
        expect(resultCorrectCase, equals(upload));
      });

      test('should handle uploads with different statuses', () {
        // Arrange
        final pendingUpload = PendingUpload.create(
          localVideoPath: '/path/to/pending.mp4',
          nostrPubkey: 'pubkey1',
        );
        final uploadingUpload = pendingUpload.copyWith(
          localVideoPath: '/path/to/uploading.mp4',
          status: UploadStatus.uploading,
        );
        final publishedUpload = pendingUpload.copyWith(
          localVideoPath: '/path/to/published.mp4',
          status: UploadStatus.published,
        );

        uploadManager.pendingUploads.addAll([
          pendingUpload,
          uploadingUpload,
          publishedUpload,
        ]);

        // Act & Assert
        expect(
          uploadManager.getUploadByFilePath('/path/to/pending.mp4'),
          equals(pendingUpload),
        );
        expect(
          uploadManager.getUploadByFilePath('/path/to/uploading.mp4'),
          equals(uploadingUpload),
        );
        expect(
          uploadManager.getUploadByFilePath('/path/to/published.mp4'),
          equals(publishedUpload),
        );
      });
    });
  });
}