// ABOUTME: Unit tests for UploadManager.getUploadByFilePath method
// ABOUTME: Tests file path lookup functionality using the public API

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/models/pending_upload.dart';
import 'package:openvine/services/upload_manager.dart';
import 'package:openvine/services/direct_upload_service.dart';
import 'package:hive_flutter/hive_flutter.dart';

class MockDirectUploadService extends Mock implements DirectUploadService {}
class MockFile extends Mock implements File {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  late UploadManager uploadManager;
  late MockDirectUploadService mockUploadService;

  setUpAll(() async {
    // Initialize Hive for testing
    await Hive.initFlutter();
    // Delete any existing test box
    await Hive.deleteBoxFromDisk('pending_uploads');
  });

  setUp(() async {
    mockUploadService = MockDirectUploadService();
    uploadManager = UploadManager(uploadService: mockUploadService);
    
    // Initialize the upload manager (this will open the Hive box)
    await uploadManager.initialize();
  });

  tearDown(() async {
    // Clean up after each test
    await Hive.deleteBoxFromDisk('pending_uploads');
  });

  group('UploadManager.getUploadByFilePath', () {
    test('should return upload with matching file path', () async {
      // Arrange - Create some test uploads
      final mockFile1 = MockFile();
      final mockFile2 = MockFile();
      final mockFile3 = MockFile();
      
      when(() => mockFile1.path).thenReturn('/path/to/video1.mp4');
      when(() => mockFile2.path).thenReturn('/path/to/video2.mp4');
      when(() => mockFile3.path).thenReturn('/path/to/video3.mp4');
      when(() => mockFile1.exists()).thenAnswer((_) async => true);
      when(() => mockFile2.exists()).thenAnswer((_) async => true);
      when(() => mockFile3.exists()).thenAnswer((_) async => true);
      when(() => mockFile1.existsSync()).thenReturn(true);
      when(() => mockFile2.existsSync()).thenReturn(true);
      when(() => mockFile3.existsSync()).thenReturn(true);
      when(() => mockFile1.lengthSync()).thenReturn(1000000);
      when(() => mockFile2.lengthSync()).thenReturn(2000000);
      when(() => mockFile3.lengthSync()).thenReturn(3000000);
      
      // Start uploads to create PendingUpload entries
      await uploadManager.startUpload(
        videoFile: mockFile1,
        nostrPubkey: 'pubkey1',
      );
      await uploadManager.startUpload(
        videoFile: mockFile2,
        nostrPubkey: 'pubkey2',
      );
      await uploadManager.startUpload(
        videoFile: mockFile3,
        nostrPubkey: 'pubkey3',
      );

      // Act
      final result = uploadManager.getUploadByFilePath('/path/to/video2.mp4');

      // Assert
      expect(result, isNotNull);
      expect(result?.localVideoPath, equals('/path/to/video2.mp4'));
      expect(result?.nostrPubkey, equals('pubkey2'));
    });

    test('should return null when no upload matches file path', () async {
      // Arrange
      final mockFile1 = MockFile();
      when(() => mockFile1.path).thenReturn('/path/to/video1.mp4');
      when(() => mockFile1.exists()).thenAnswer((_) async => true);
      when(() => mockFile1.existsSync()).thenReturn(true);
      when(() => mockFile1.lengthSync()).thenReturn(1000000);
      
      await uploadManager.startUpload(
        videoFile: mockFile1,
        nostrPubkey: 'pubkey1',
      );

      // Act
      final result = uploadManager.getUploadByFilePath('/path/to/nonexistent.mp4');

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
      final mockFile = MockFile();
      when(() => mockFile.path).thenReturn('/path with spaces/my video.mp4');
      when(() => mockFile.exists()).thenAnswer((_) async => true);
      when(() => mockFile.existsSync()).thenReturn(true);
      when(() => mockFile.lengthSync()).thenReturn(1000000);
      
      await uploadManager.startUpload(
        videoFile: mockFile,
        nostrPubkey: 'pubkey1',
      );

      // Act
      final result = uploadManager.getUploadByFilePath('/path with spaces/my video.mp4');

      // Assert
      expect(result, isNotNull);
      expect(result?.localVideoPath, equals('/path with spaces/my video.mp4'));
    });

    test('should handle special characters in file paths', () async {
      // Arrange
      final mockFile = MockFile();
      when(() => mockFile.path).thenReturn('/path/to/video@#\$%^&()_+.mp4');
      when(() => mockFile.exists()).thenAnswer((_) async => true);
      when(() => mockFile.existsSync()).thenReturn(true);
      when(() => mockFile.lengthSync()).thenReturn(1000000);
      
      await uploadManager.startUpload(
        videoFile: mockFile,
        nostrPubkey: 'pubkey1',
      );

      // Act
      final result = uploadManager.getUploadByFilePath('/path/to/video@#\$%^&()_+.mp4');

      // Assert
      expect(result, isNotNull);
      expect(result?.localVideoPath, equals('/path/to/video@#\$%^&()_+.mp4'));
    });

    test('should return first match when multiple uploads have same path', () async {
      // This shouldn't normally happen, but let's test the edge case
      // We'll create uploads with different timestamps
      final mockFile = MockFile();
      when(() => mockFile.path).thenReturn('/path/to/duplicate.mp4');
      when(() => mockFile.exists()).thenAnswer((_) async => true);
      when(() => mockFile.existsSync()).thenReturn(true);
      when(() => mockFile.lengthSync()).thenReturn(1000000);
      
      await uploadManager.startUpload(
        videoFile: mockFile,
        nostrPubkey: 'pubkey1',
      );
      
      // Small delay to ensure different timestamps
      await Future.delayed(const Duration(milliseconds: 10));
      
      await uploadManager.startUpload(
        videoFile: mockFile,
        nostrPubkey: 'pubkey2',
      );

      // Act
      final result = uploadManager.getUploadByFilePath('/path/to/duplicate.mp4');
      final allUploads = uploadManager.pendingUploads;

      // Assert
      expect(result, isNotNull);
      expect(allUploads.where((u) => u.localVideoPath == '/path/to/duplicate.mp4').length, equals(2));
      // The method returns the first match from the sorted list (newest first)
      expect(result?.nostrPubkey, equals('pubkey2')); // The second upload should be newer
    });

    test('should be case sensitive', () async {
      // Arrange
      final mockFile = MockFile();
      when(() => mockFile.path).thenReturn('/Path/To/Video.mp4');
      when(() => mockFile.exists()).thenAnswer((_) async => true);
      when(() => mockFile.existsSync()).thenReturn(true);
      when(() => mockFile.lengthSync()).thenReturn(1000000);
      
      await uploadManager.startUpload(
        videoFile: mockFile,
        nostrPubkey: 'pubkey1',
      );

      // Act
      final resultLowerCase = uploadManager.getUploadByFilePath('/path/to/video.mp4');
      final resultCorrectCase = uploadManager.getUploadByFilePath('/Path/To/Video.mp4');

      // Assert
      expect(resultLowerCase, isNull);
      expect(resultCorrectCase, isNotNull);
      expect(resultCorrectCase?.localVideoPath, equals('/Path/To/Video.mp4'));
    });
  });
}