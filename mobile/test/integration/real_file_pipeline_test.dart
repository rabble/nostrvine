// ABOUTME: Real file processing pipeline tests using actual files and HTTP requests
// ABOUTME: Tests the pipeline with real constraints - file I/O, network calls, state persistence

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as path;
import 'package:openvine/services/upload_manager.dart';
import 'package:openvine/services/direct_upload_service.dart';
import 'package:openvine/models/pending_upload.dart';

/// Real file pipeline tests with actual I/O operations
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('Real File Pipeline Tests', () {
    late Directory tempDir;
    late String testHiveDir;

    setUpAll(() async {
      // Create test directories
      tempDir = await Directory.systemTemp.createTemp('pipeline_test_');
      testHiveDir = path.join(tempDir.path, 'hive');
      
      // Initialize Hive with test directory
      Hive.init(testHiveDir);
      
      // Register adapters
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(UploadStatusAdapter());
      }
      if (!Hive.isAdapterRegistered(2)) {
        Hive.registerAdapter(PendingUploadAdapter());
      }
    });

    tearDownAll(() async {
      await Hive.close();
      await tempDir.delete(recursive: true);
    });

    group('File Creation and Upload Flow', () {
      test('should create real video file and track upload lifecycle', () async {
        // ARRANGE: Create a real test video file
        final testVideoFile = File(path.join(tempDir.path, 'test_video.mp4'));
        
        // Create minimal MP4 file header (real file, not just placeholder)
        final mp4Header = _createMinimalMp4Header();
        await testVideoFile.writeAsBytes(mp4Header);
        
        expect(testVideoFile.existsSync(), true);
        expect(testVideoFile.lengthSync(), greaterThan(0));
        
        print('🧪 Created test video file: ${testVideoFile.path} (${testVideoFile.lengthSync()} bytes)');

        // Initialize services with real persistence
        final uploadsBox = await Hive.openBox<PendingUpload>('real_test_uploads');
        final uploadService = DirectUploadService();
        final uploadManager = UploadManager(uploadService: uploadService);
        await uploadManager.initialize();

        try {
          // ACT: Start upload with real file
          final upload = await uploadManager.startUpload(
            videoFile: testVideoFile,
            nostrPubkey: 'npub1test...real',
            title: 'Real File Test Video',
            description: 'Testing with actual file I/O',
            hashtags: ['realtest', 'pipeline'],
          );

          // ASSERT: Upload should be created and persisted
          expect(upload.id, isNotEmpty);
          expect(upload.localVideoPath, testVideoFile.path);
          expect(upload.status, UploadStatus.pending);
          expect(upload.title, 'Real File Test Video');
          
          // Verify persistence in Hive
          final persistedUpload = uploadsBox.get(upload.id);
          expect(persistedUpload, isNotNull);
          expect(persistedUpload!.localVideoPath, testVideoFile.path);
          
          print('✅ Upload created and persisted: ${upload.id}');

          // Test state transitions
          await uploadManager.markUploadReadyToPublish(upload.id, 'real-cloudinary-id-123');
          
          final updatedUpload = uploadManager.getUpload(upload.id);
          expect(updatedUpload!.status, UploadStatus.readyToPublish);
          expect(updatedUpload.cloudinaryPublicId, 'real-cloudinary-id-123');
          
          // Verify persistence of state change
          final persistedUpdated = uploadsBox.get(upload.id);
          expect(persistedUpdated!.status, UploadStatus.readyToPublish);
          
          print('✅ State transition persisted correctly');

        } finally {
          uploadManager.dispose();
          await uploadsBox.close();
        }
      });

      test('should handle file not found errors gracefully', () async {
        final nonExistentFile = File(path.join(tempDir.path, 'does_not_exist.mp4'));
        expect(nonExistentFile.existsSync(), false);

        final uploadsBox = await Hive.openBox<PendingUpload>('error_test_uploads');
        final uploadService = DirectUploadService();
        final uploadManager = UploadManager(uploadService: uploadService);
        await uploadManager.initialize();

        try {
          // Should handle missing file gracefully
          expect(
            () => uploadManager.startUpload(
              videoFile: nonExistentFile,
              nostrPubkey: 'test-pubkey',
              title: 'Missing File Test',
            ),
            throwsA(predicate((e) => e.toString().contains('Video file not found'))),
          );
        } finally {
          uploadManager.dispose();
          await uploadsBox.close();
        }
      });

      test('should handle large file operations', () async {
        // Create a larger test file (1MB)
        final largeFile = File(path.join(tempDir.path, 'large_test_video.mp4'));
        final largeData = Uint8List(1024 * 1024); // 1MB
        
        // Fill with pattern data instead of zeros for more realistic test
        for (int i = 0; i < largeData.length; i++) {
          largeData[i] = i % 256;
        }
        
        await largeFile.writeAsBytes(largeData);
        expect(largeFile.lengthSync(), 1024 * 1024);
        
        print('🧪 Created large test file: ${largeFile.lengthSync()} bytes');

        final uploadsBox = await Hive.openBox<PendingUpload>('large_file_uploads');
        final uploadService = DirectUploadService();
        final uploadManager = UploadManager(uploadService: uploadService);
        await uploadManager.initialize();

        try {
          final startTime = DateTime.now();
          
          final upload = await uploadManager.startUpload(
            videoFile: largeFile,
            nostrPubkey: 'large-file-test-pubkey',
            title: 'Large File Test',
          );

          final duration = DateTime.now().difference(startTime);
          print('✅ Large file upload creation took: ${duration.inMilliseconds}ms');
          
          expect(upload.id, isNotEmpty);
          expect(upload.localVideoPath, largeFile.path);
          
          // Verify we can read the persisted large file reference
          final persistedUpload = uploadManager.getUpload(upload.id);
          expect(persistedUpload, isNotNull);
          
          // Verify the actual file is still accessible
          final referencedFile = File(persistedUpload!.localVideoPath);
          expect(referencedFile.existsSync(), true);
          expect(referencedFile.lengthSync(), 1024 * 1024);

        } finally {
          uploadManager.dispose();
          await uploadsBox.close();
        }
      });
    });

    group('ReadyEventData Processing', () {
      test('should create and validate real NIP-94 events', () async {
        // Create realistic ready event data
        final readyEvent = ReadyEventData(
          publicId: 'real-test-public-id-123',
          secureUrl: 'https://res.cloudinary.com/test/video/upload/v1234567890/real-test-public-id-123.mp4',
          contentSuggestion: 'Real test video for pipeline validation',
          tags: [
            ['url', 'https://res.cloudinary.com/test/video/upload/v1234567890/real-test-public-id-123.mp4'],
            ['m', 'video/mp4'],
            ['size', '1048576'],
            ['duration', '6'],
          ],
          metadata: {
            'width': 1920,
            'height': 1080,
            'fps': 30,
            'bitrate': 5000000,
          },
          processedAt: DateTime.now(),
          originalUploadId: 'upload-id-from-real-test',
          mimeType: 'video/mp4',
          fileSize: 1048576,
          width: 1920,
          height: 1080,
          duration: 6.5,
        );

        // Verify NIP-94 tag generation
        final nip94Tags = readyEvent.nip94Tags;
        
        expect(nip94Tags, contains(['url', 'https://res.cloudinary.com/test/video/upload/v1234567890/real-test-public-id-123.mp4']));
        expect(nip94Tags, contains(['m', 'video/mp4']));
        expect(nip94Tags, contains(['size', '1048576']));
        expect(nip94Tags, contains(['dim', '1920x1080']));
        expect(nip94Tags, contains(['duration', '7'])); // Rounded up from 6.5
        
        // Verify validation
        expect(readyEvent.isReadyForPublishing, true);
        
        // Verify estimated size calculation
        final estimatedSize = readyEvent.estimatedEventSize;
        expect(estimatedSize, greaterThan(200)); // Should include content + tags
        expect(estimatedSize, lessThan(10000)); // Should be reasonable
        
        print('✅ NIP-94 event validated: ${nip94Tags.length} tags, ~$estimatedSize bytes');
      });

      test('should handle edge cases in event data', () async {
        // Test with minimal data
        final minimalEvent = ReadyEventData(
          publicId: 'minimal',
          secureUrl: 'https://example.com/minimal.mp4',
          contentSuggestion: '',
          tags: [],
          metadata: {},
          processedAt: DateTime.now(),
          originalUploadId: 'minimal-upload',
          mimeType: 'video/mp4',
        );

        expect(minimalEvent.isReadyForPublishing, true);
        final nip94Tags = minimalEvent.nip94Tags;
        expect(nip94Tags, contains(['url', 'https://example.com/minimal.mp4']));
        expect(nip94Tags, contains(['m', 'video/mp4']));

        // Test with invalid data
        final invalidEvent = ReadyEventData(
          publicId: '', // Invalid empty public ID
          secureUrl: 'https://example.com/invalid.mp4',
          contentSuggestion: 'Should not be ready',
          tags: [],
          metadata: {},
          processedAt: DateTime.now(),
          originalUploadId: 'invalid-upload',
          mimeType: 'video/mp4',
        );

        expect(invalidEvent.isReadyForPublishing, false);
      });
    });

    group('Cross-Service State Synchronization', () {
      test('services should maintain state consistency across operations', () async {
        // Create test file
        final testFile = File(path.join(tempDir.path, 'sync_test.mp4'));
        await testFile.writeAsBytes(_createMinimalMp4Header());

        // Initialize services
        final uploadsBox = await Hive.openBox<PendingUpload>('sync_test_uploads');
        final uploadService = DirectUploadService();
        final uploadManager = UploadManager(uploadService: uploadService);
        await uploadManager.initialize();

        try {
          // Create upload
          final upload = await uploadManager.startUpload(
            videoFile: testFile,
            nostrPubkey: 'sync-test-pubkey',
            title: 'Sync Test Video',
          );

          // Track all state changes
          final stateChanges = <String>[];
          
          // Initial state
          stateChanges.add('created: ${upload.status}');
          expect(upload.status, UploadStatus.pending);

          // Simulate processing
          await uploadManager.markUploadReadyToPublish(upload.id, 'sync-cloudinary-123');
          final readyUpload = uploadManager.getUpload(upload.id)!;
          stateChanges.add('ready: ${readyUpload.status}');
          expect(readyUpload.status, UploadStatus.readyToPublish);

          // Simulate publishing
          await uploadManager.markUploadPublished(upload.id, 'nostr-event-xyz789');
          final publishedUpload = uploadManager.getUpload(upload.id)!;
          stateChanges.add('published: ${publishedUpload.status}');
          expect(publishedUpload.status, UploadStatus.published);
          expect(publishedUpload.nostrEventId, 'nostr-event-xyz789');

          // Verify all state changes were persisted
          final persistedFinal = uploadsBox.get(upload.id)!;
          expect(persistedFinal.status, UploadStatus.published);
          expect(persistedFinal.nostrEventId, 'nostr-event-xyz789');
          expect(persistedFinal.cloudinaryPublicId, 'sync-cloudinary-123');

          print('✅ State synchronization verified: ${stateChanges.join(' → ')}');

        } finally {
          uploadManager.dispose();
          await uploadsBox.close();
        }
      });
    });

    group('Performance Under Load', () {
      test('should handle multiple concurrent file operations', () async {
        final fileCount = 5;
        final files = <File>[];
        
        // Create multiple test files
        for (int i = 0; i < fileCount; i++) {
          final file = File(path.join(tempDir.path, 'concurrent_$i.mp4'));
          await file.writeAsBytes(_createMinimalMp4Header());
          files.add(file);
        }

        final uploadsBox = await Hive.openBox<PendingUpload>('concurrent_uploads');
        final uploadService = DirectUploadService();
        final uploadManager = UploadManager(uploadService: uploadService);
        await uploadManager.initialize();

        try {
          final startTime = DateTime.now();
          
          // Start concurrent uploads
          final uploadFutures = files.asMap().entries.map((entry) {
            final index = entry.key;
            final file = entry.value;
            return uploadManager.startUpload(
              videoFile: file,
              nostrPubkey: 'concurrent-test-$index',
              title: 'Concurrent Video $index',
            );
          });

          final uploads = await Future.wait(uploadFutures);
          final duration = DateTime.now().difference(startTime);
          
          print('✅ ${uploads.length} concurrent uploads completed in ${duration.inMilliseconds}ms');
          
          // Verify all uploads were created successfully
          expect(uploads.length, fileCount);
          
          // Verify all have unique IDs
          final uniqueIds = uploads.map((u) => u.id).toSet();
          expect(uniqueIds.length, fileCount);
          
          // Verify all are persisted
          for (final upload in uploads) {
            final persisted = uploadsBox.get(upload.id);
            expect(persisted, isNotNull);
            expect(File(persisted!.localVideoPath).existsSync(), true);
          }

          // Test concurrent state updates
          final updateFutures = uploads.map((upload) => 
            uploadManager.markUploadReadyToPublish(upload.id, 'concurrent-${upload.id}')
          );
          
          await Future.wait(updateFutures);
          
          // Verify all updates succeeded
          for (final upload in uploads) {
            final updated = uploadManager.getUpload(upload.id)!;
            expect(updated.status, UploadStatus.readyToPublish);
            expect(updated.cloudinaryPublicId, 'concurrent-${upload.id}');
          }

        } finally {
          uploadManager.dispose();
          await uploadsBox.close();
        }
      });
    });
  });
}

/// Create a minimal but valid MP4 file header for testing
Uint8List _createMinimalMp4Header() {
  // This creates a minimal MP4 file that passes basic validation
  // ftyp box (file type) + mdat box (media data) 
  final data = ByteData(32);
  
  // ftyp box
  data.setUint32(0, 20, Endian.big); // box size
  data.setUint32(4, 0x66747970, Endian.big); // 'ftyp'
  data.setUint32(8, 0x6d703432, Endian.big); // 'mp42' major brand
  data.setUint32(12, 0, Endian.big); // minor version
  data.setUint32(16, 0x6d703432, Endian.big); // 'mp42' compatible brand
  
  // mdat box
  data.setUint32(20, 12, Endian.big); // box size  
  data.setUint32(24, 0x6d646174, Endian.big); // 'mdat'
  data.setUint32(28, 0x00000000, Endian.big); // empty media data
  
  return data.buffer.asUint8List();
}