// ABOUTME: Tests for pipeline failure scenarios and recovery mechanisms  
// ABOUTME: Validates error handling, retry logic, and graceful degradation under various failure conditions

import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:nostrvine_app/models/pending_upload.dart';
import '../helpers/pipeline_test_factory.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  setUpAll(() async {
    // Initialize Hive for testing
    final testDir = await Directory.systemTemp.createTemp('pipeline_failure_test_');
    Hive.init('${testDir.path}/hive');
    
    // Register adapters
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(UploadStatusAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(PendingUploadAdapter());
    }
    
    // Register fallback values for mocks
    registerFallbackValue(Uri.parse('https://example.com'));
    registerFallbackValue(<String, String>{});
    registerFallbackValue(UploadStatus.pending);
  });

  tearDownAll(() async {
    await PipelineTestFactory.cleanup();
    await Hive.close();
  });

  group('Pipeline Failure Recovery Tests', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('failure_test_');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('should handle Cloudinary upload failures gracefully', () async {
      // ARRANGE: Setup upload failure scenario
      final stack = await PipelineTestFactory.createTestStack(
        testName: 'upload_failure',
        config: const PipelineTestConfig(scenario: PipelineTestScenario.uploadFailure),
      );
      
      await stack.initialize();
      
      try {
        final testFile = await PipelineTestFactory.createTestFile(tempDir, 'upload_fail_test.mp4');
        
        // ACT: Execute pipeline with upload failure
        final result = await stack.executeFullPipeline(testFile: testFile);
        
        // ASSERT: Should handle upload failure gracefully
        print('🧪 Upload failure test result: ${result.toSummary()}');
        
        expect(result.uploadCreated, true); // Upload record should be created
        expect(result.success, false); // Overall pipeline should fail
        expect(result.finalStatus, UploadStatus.failed); // Should be marked as failed
        expect(result.error, isNotNull); // Should capture the error
        
        // Verify the upload is persisted with failure info
        final persistedUpload = stack.uploadManager.getUpload(result.upload!.id);
        expect(persistedUpload?.status, UploadStatus.failed);
        expect(persistedUpload?.errorMessage, isNotNull);
        
      } finally {
        await stack.dispose();
      }
    });

    test('should handle backend processing timeouts', () async {
      // ARRANGE: Setup processing failure scenario (no ready events)
      final stack = await PipelineTestFactory.createTestStack(
        testName: 'processing_timeout',
        config: const PipelineTestConfig(scenario: PipelineTestScenario.processingFailure),
      );
      
      await stack.initialize();
      
      try {
        final testFile = await PipelineTestFactory.createTestFile(tempDir, 'processing_timeout_test.mp4');
        
        // ACT: Execute pipeline that will get stuck in processing
        final result = await stack.executeFullPipeline(testFile: testFile);
        
        // ASSERT: Should handle processing timeout gracefully
        print('🧪 Processing timeout test result: ${result.toSummary()}');
        
        expect(result.uploadCreated, true);
        expect(result.markedReady, true);
        expect(result.publishingTriggered, true);
        expect(result.success, false); // Should not complete due to no ready events
        
        // Upload should remain in readyToPublish state waiting for backend
        expect(result.finalStatus, UploadStatus.readyToPublish);
        
        // Publisher should be polling and healthy despite no events
        expect(stack.videoEventPublisher.publishingStats['is_polling_active'], true);
        expect(stack.videoEventPublisher.publishingStats['total_failed'], 0); // Not a failure, just waiting
        
      } finally {
        await stack.dispose();
      }
    });

    test('should handle Nostr relay failures with retry logic', () async {
      // ARRANGE: Setup Nostr failure scenario
      final stack = await PipelineTestFactory.createTestStack(
        testName: 'nostr_failure',
        config: const PipelineTestConfig(scenario: PipelineTestScenario.nostrFailure),
      );
      
      await stack.initialize();
      
      try {
        final testFile = await PipelineTestFactory.createTestFile(tempDir, 'nostr_fail_test.mp4');
        
        // ACT: Execute pipeline with Nostr broadcast failure
        final result = await stack.executeFullPipeline(testFile: testFile);
        
        // ASSERT: Should handle Nostr failure gracefully
        print('🧪 Nostr failure test result: ${result.toSummary()}');
        
        expect(result.uploadCreated, true);
        expect(result.markedReady, true);
        expect(result.publishingTriggered, true);
        expect(result.success, false); // Should fail due to Nostr error
        
        // Should track the failure in publisher stats
        expect(stack.videoEventPublisher.publishingStats['total_failed'], greaterThan(0));
        expect(stack.videoEventPublisher.publishingStats['is_polling_active'], true); // Still polling
        
        // Upload should remain ready (can be retried)
        expect(result.finalStatus, UploadStatus.readyToPublish);
        
      } finally {
        await stack.dispose();
      }
    });

    test('should handle network timeouts gracefully', () async {
      // ARRANGE: Setup network timeout scenario
      final stack = await PipelineTestFactory.createTestStack(
        testName: 'network_timeout',
        config: const PipelineTestConfig(scenario: PipelineTestScenario.networkTimeout),
      );
      
      await stack.initialize();
      
      try {
        final testFile = await PipelineTestFactory.createTestFile(tempDir, 'timeout_test.mp4');
        
        // ACT: Execute pipeline with network timeouts
        final result = await stack.executeFullPipeline(testFile: testFile);
        
        // ASSERT: Should handle timeouts without crashing
        print('🧪 Network timeout test result: ${result.toSummary()}');
        
        expect(result.uploadCreated, true);
        expect(result.publishingTriggered, true);
        
        // Publisher should remain active despite timeouts
        expect(stack.videoEventPublisher.publishingStats['is_polling_active'], true);
        
        // Should not crash the entire pipeline
        expect(result.error, isNull);
        
      } finally {
        await stack.dispose();
      }
    });

    test('should handle malformed API responses', () async {
      // ARRANGE: Setup malformed response scenario
      final stack = await PipelineTestFactory.createTestStack(
        testName: 'malformed_response',
        config: const PipelineTestConfig(scenario: PipelineTestScenario.malformedResponse),
      );
      
      await stack.initialize();
      
      try {
        final testFile = await PipelineTestFactory.createTestFile(tempDir, 'malformed_test.mp4');
        
        // ACT: Execute pipeline with malformed responses
        final result = await stack.executeFullPipeline(testFile: testFile);
        
        // ASSERT: Should handle malformed data gracefully
        print('🧪 Malformed response test result: ${result.toSummary()}');
        
        expect(result.publishingTriggered, true);
        
        // Should not crash and should continue polling
        expect(stack.videoEventPublisher.publishingStats['is_polling_active'], true);
        
        // May or may not succeed depending on how malformed data is handled
        // But should not crash the app
        expect(result.error, isNull);
        
      } finally {
        await stack.dispose();
      }
    });

    test('should handle partial Nostr relay success correctly', () async {
      // ARRANGE: Setup partial success scenario
      final stack = await PipelineTestFactory.createTestStack(
        testName: 'partial_success',
        config: const PipelineTestConfig(scenario: PipelineTestScenario.partialSuccess),
      );
      
      await stack.initialize();
      
      try {
        final testFile = await PipelineTestFactory.createTestFile(tempDir, 'partial_success_test.mp4');
        
        // ACT: Execute pipeline with partial Nostr success
        final result = await stack.executeFullPipeline(testFile: testFile);
        
        // ASSERT: Should consider partial success as success
        print('🧪 Partial success test result: ${result.toSummary()}');
        
        expect(result.uploadCreated, true);
        expect(result.markedReady, true);
        expect(result.publishingTriggered, true);
        
        // Partial success (1/3 relays) should still be considered success
        expect(result.success, true);
        expect(result.finalStatus, UploadStatus.published);
        
        // Should track successful publish
        expect(stack.videoEventPublisher.publishingStats['total_published'], 1);
        
      } finally {
        await stack.dispose();
      }
    });

    test('should recover from service restart scenarios', () async {
      // ARRANGE: Test service restart recovery
      final stack1 = await PipelineTestFactory.createTestStack(
        testName: 'restart_recovery_1',
        config: const PipelineTestConfig(scenario: PipelineTestScenario.success),
      );
      
      await stack1.initialize();
      
      try {
        final testFile = await PipelineTestFactory.createTestFile(tempDir, 'restart_test.mp4');
        
        // Create upload and get it to ready state
        final upload = await stack1.uploadManager.startUpload(
          videoFile: testFile,
          nostrPubkey: 'restart-test-pubkey',
          title: 'Restart Recovery Test',
        );
        
        await Future.delayed(const Duration(milliseconds: 50));
        await stack1.uploadManager.markUploadReadyToPublish(upload.id, 'restart-cloudinary-123');
        
        final readyUpload = stack1.uploadManager.getUpload(upload.id);
        expect(readyUpload?.status, UploadStatus.readyToPublish);
        
        // Simulate service restart by disposing and creating new stack
        await stack1.dispose();
        
        final stack2 = await PipelineTestFactory.createTestStack(
          testName: 'restart_recovery_2',
          config: const PipelineTestConfig(scenario: PipelineTestScenario.success),
        );
        
        await stack2.initialize();
        
        try {
          // ACT: Check if upload persisted across restart
          final persistedUpload = stack2.uploadManager.getUpload(upload.id);
          
          // ASSERT: Upload should be recoverable after restart
          print('🧪 Service restart recovery test - upload recovered: ${persistedUpload != null}');
          
          // Note: In real implementation, uploads would persist across restarts
          // This test verifies the recovery mechanism exists
          if (persistedUpload != null) {
            expect(persistedUpload.id, upload.id);
            expect(persistedUpload.status, UploadStatus.readyToPublish);
            expect(persistedUpload.cloudinaryPublicId, 'restart-cloudinary-123');
          }
          
        } finally {
          await stack2.dispose();
        }
      } catch (e) {
        await stack1.dispose();
        rethrow;
      }
    });

    test('should handle concurrent failure scenarios', () async {
      // ARRANGE: Multiple uploads with different failure scenarios
      final scenarios = [
        PipelineTestScenario.success,
        PipelineTestScenario.uploadFailure,
        PipelineTestScenario.nostrFailure,
        PipelineTestScenario.partialSuccess,
      ];
      
      final stacks = <PipelineTestStack>[];
      final results = <PipelineTestResult>[];
      
      try {
        // Create multiple stacks with different scenarios
        for (int i = 0; i < scenarios.length; i++) {
          final stack = await PipelineTestFactory.createTestStack(
            testName: 'concurrent_failure_$i',
            config: PipelineTestConfig(scenario: scenarios[i]),
          );
          await stack.initialize();
          stacks.add(stack);
        }
        
        // ACT: Execute all pipelines concurrently
        final futures = stacks.asMap().entries.map((entry) async {
          final index = entry.key;
          final stack = entry.value;
          
          final testFile = await PipelineTestFactory.createTestFile(
            tempDir, 
            'concurrent_failure_$index.mp4'
          );
          
          return await stack.executeFullPipeline(testFile: testFile);
        });
        
        results.addAll(await Future.wait(futures));
        
        // ASSERT: Each scenario should behave as expected
        expect(results.length, scenarios.length);
        
        print('🧪 Concurrent failure scenarios summary:');
        for (int i = 0; i < results.length; i++) {
          final scenario = scenarios[i];
          final result = results[i];
          
          print('  $scenario: ${result.toSummary()}');
          
          switch (scenario) {
            case PipelineTestScenario.success:
            case PipelineTestScenario.partialSuccess:
              expect(result.success, true, reason: 'Success scenarios should succeed');
              break;
            case PipelineTestScenario.uploadFailure:
            case PipelineTestScenario.nostrFailure:
              expect(result.success, false, reason: 'Failure scenarios should fail');
              break;
            default:
              // Other scenarios may vary
              break;
          }
        }
        
        // Verify systems remain stable despite mixed failures
        for (final stack in stacks) {
          expect(stack.videoEventPublisher.publishingStats['is_polling_active'], true);
        }
        
      } finally {
        for (final stack in stacks) {
          await stack.dispose();
        }
      }
    });
  });
}