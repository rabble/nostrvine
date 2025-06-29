// ABOUTME: Simple demonstration of pipeline testing framework 
// ABOUTME: Shows how integration tests can catch real pipeline issues

import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:openvine/models/pending_upload.dart';
import '../helpers/pipeline_test_factory.dart';
import 'package:openvine/utils/unified_logger.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('Pipeline Integration Demo', () {
    late Directory tempDir;

    setUpAll(() async {
      // Initialize test environment
      tempDir = await Directory.systemTemp.createTemp('pipeline_demo_');
      Hive.init('${tempDir.path}/hive');
      
      // Register adapters
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(UploadStatusAdapter());
      }
      if (!Hive.isAdapterRegistered(2)) {
        Hive.registerAdapter(PendingUploadAdapter());
      }
      
      // Register mock fallbacks
      registerFallbackValue(Uri.parse('https://example.com'));
      registerFallbackValue(<String, String>{});
      registerFallbackValue(UploadStatus.pending);
    });

    tearDownAll(() async {
      await PipelineTestFactory.cleanup();
      await Hive.close();
      await tempDir.delete(recursive: true);
    });

    test('demonstrates successful pipeline flow', () async {
      Log.debug('🧪 DEMO: Testing successful pipeline flow');
      
      // ARRANGE: Create test stack with success scenario
      final stack = await PipelineTestFactory.createTestStack(
        testName: 'demo_success',
        config: const PipelineTestConfig(scenario: PipelineTestScenario.success),
      );
      
      try {
        await stack.initialize();
        
        // Create test file
        final testFile = await PipelineTestFactory.createTestFile(
          tempDir, 
          'demo_success.mp4',
          sizeBytes: 1024, // Small file for demo
        );
        
        expect(testFile.existsSync(), true);
        Log.debug('  ✅ Created test video file: ${testFile.lengthSync()} bytes');
        
        // ACT: Execute full pipeline
        final result = await stack.executeFullPipeline(
          testFile: testFile,
          uploadTitle: 'Demo Success Video',
          hashtags: ['demo', 'success', 'pipeline'],
        );
        
        // ASSERT: Verify successful flow
        expect(result.success, true);
        expect(result.uploadCreated, true);
        expect(result.markedReady, true);
        expect(result.publishingTriggered, true);
        expect(result.finalStatus, UploadStatus.published);
        
        Log.debug('  ✅ Pipeline executed successfully in ${result.duration?.inMilliseconds}ms');
        Log.debug('  📊 Final result: ${result.toSummary()}');
        
        // Verify service states
        expect(stack.videoEventPublisher.publishingStats['total_published'], 1);
        expect(stack.videoEventPublisher.publishingStats['total_failed'], 0);
        expect(stack.videoEventPublisher.publishingStats['is_polling_active'], true);
        
        Log.debug('  ✅ All services in healthy state');
        
      } finally {
        await stack.dispose();
      }
    });

    test('demonstrates upload failure handling', () async {
      Log.debug('🧪 DEMO: Testing upload failure handling');
      
      // ARRANGE: Create test stack with upload failure scenario
      final stack = await PipelineTestFactory.createTestStack(
        testName: 'demo_upload_fail',
        config: const PipelineTestConfig(scenario: PipelineTestScenario.uploadFailure),
      );
      
      try {
        await stack.initialize();
        
        // Create test file
        final testFile = await PipelineTestFactory.createTestFile(tempDir, 'demo_fail.mp4');
        
        // ACT: Execute pipeline that will fail at upload
        final result = await stack.executeFullPipeline(testFile: testFile);
        
        // ASSERT: Verify graceful failure handling
        expect(result.success, false);
        expect(result.uploadCreated, true); // Upload record created
        expect(result.finalStatus, UploadStatus.failed); // Marked as failed
        expect(result.error, isNotNull); // Error captured
        
        Log.debug('  ✅ Upload failure handled gracefully');
        Log.debug('  📊 Failure result: ${result.toSummary()}');
        
        // Verify service remains stable despite failure
        expect(stack.videoEventPublisher.publishingStats['is_polling_active'], true);
        
        Log.debug('  ✅ Services remain stable after failure');
        
      } finally {
        await stack.dispose();
      }
    });

    test('demonstrates ReadyEventData validation', () async {
      Log.debug('🧪 DEMO: Testing ReadyEventData processing');
      
      // ARRANGE: Create test ready event
      final readyEvent = PipelineTestFactory.createTestReadyEvent(
        publicId: 'demo-public-id-123',
        uploadId: 'demo-upload-456',
        videoUrl: 'https://demo.cloudinary.com/video.mp4',
        metadata: {
          'width': 1920,
          'height': 1080,
          'duration': 5.5,
          'fps': 30,
        },
      );
      
      // ACT & ASSERT: Verify event validation
      expect(readyEvent.isReadyForPublishing, true);
      Log.debug('  ✅ Ready event validation passed');
      
      // Verify NIP-94 tag generation
      final nip94Tags = readyEvent.nip94Tags;
      expect(nip94Tags, isNotEmpty);
      expect(nip94Tags, contains(['url', 'https://demo.cloudinary.com/video.mp4']));
      expect(nip94Tags, contains(['m', 'video/mp4']));
      expect(nip94Tags, contains(['dim', '1920x1080']));
      expect(nip94Tags, contains(['duration', '6'])); // Rounded from 5.5
      
      Log.debug('  ✅ NIP-94 tags generated: ${nip94Tags.length} tags');
      
      // Verify size estimation
      final estimatedSize = readyEvent.estimatedEventSize;
      expect(estimatedSize, greaterThan(100));
      expect(estimatedSize, lessThan(5000));
      
      Log.debug('  ✅ Event size estimation: ~$estimatedSize bytes');
    });

    test('demonstrates concurrent operation handling', () async {
      Log.debug('🧪 DEMO: Testing concurrent operations');
      
      // ARRANGE: Create multiple test stacks
      final stacks = <PipelineTestStack>[];
      final scenarios = [
        PipelineTestScenario.success,
        PipelineTestScenario.partialSuccess,
        PipelineTestScenario.success,
      ];
      
      try {
        for (int i = 0; i < scenarios.length; i++) {
          final stack = await PipelineTestFactory.createTestStack(
            testName: 'demo_concurrent_$i',
            config: PipelineTestConfig(scenario: scenarios[i]),
          );
          await stack.initialize();
          stacks.add(stack);
        }
        
        // ACT: Execute concurrent pipelines
        final futures = stacks.asMap().entries.map((entry) async {
          final index = entry.key;
          final stack = entry.value;
          
          final testFile = await PipelineTestFactory.createTestFile(
            tempDir, 
            'demo_concurrent_$index.mp4'
          );
          
          return await stack.executeFullPipeline(testFile: testFile);
        });
        
        final results = await Future.wait(futures);
        
        // ASSERT: Verify concurrent execution
        expect(results.length, scenarios.length);
        
        int successCount = 0;
        for (int i = 0; i < results.length; i++) {
          final result = results[i];
          if (result.success) successCount++;
          
          Log.debug('  📊 Concurrent ${i + 1}: ${result.success ? 'SUCCESS' : 'FAILED'} in ${result.duration?.inMilliseconds}ms');
        }
        
        expect(successCount, greaterThan(0)); // At least some should succeed
        Log.debug('  ✅ Concurrent operations: $successCount/${{results.length}} succeeded');
        
        // Verify all services remain stable
        for (final stack in stacks) {
          expect(stack.videoEventPublisher.publishingStats['is_polling_active'], true);
        }
        
        Log.debug('  ✅ All services stable after concurrent operations');
        
      } finally {
        for (final stack in stacks) {
          await stack.dispose();
        }
      }
    });
  });
}
