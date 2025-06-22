// ABOUTME: Test factory for creating consistent mock services and test scenarios  
// ABOUTME: Provides reusable test configurations for pipeline integration testing

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:http/http.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:nostrvine_app/services/upload_manager.dart';
import 'package:nostrvine_app/services/direct_upload_service.dart';
import 'package:nostrvine_app/services/video_event_publisher.dart';
import 'package:nostrvine_app/services/api_service.dart';
import 'package:nostrvine_app/services/notification_service.dart';
import 'package:nostrvine_app/services/nostr_service_interface.dart';
import 'package:nostrvine_app/models/pending_upload.dart';
import 'package:nostrvine_app/models/ready_event_data.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

// Mock classes
class MockHttpClient extends Mock implements http.Client {}
class MockResponse extends Mock implements http.Response {}
class MockNostrService extends Mock implements INostrService {}
class MockEvent extends Mock implements Event {}
class MockFile extends Mock implements File {}

/// Test scenarios for different pipeline states
enum PipelineTestScenario {
  success,
  uploadFailure,
  processingFailure, 
  nostrFailure,
  networkTimeout,
  malformedResponse,
  partialSuccess,
}

/// Configuration for pipeline test scenarios
class PipelineTestConfig {
  final PipelineTestScenario scenario;
  final String uploadId;
  final String videoId;
  final String nostrEventId;
  final String cdnUrl;
  final Duration? networkDelay;
  final Map<String, dynamic>? customMetadata;
  
  const PipelineTestConfig({
    required this.scenario,
    this.uploadId = 'test-upload-123',
    this.videoId = 'test-video-456',
    this.nostrEventId = 'test-event-789',
    this.cdnUrl = 'https://cdn.openvine.co/test-video-456.mp4',
    this.networkDelay,
    this.customMetadata,
  });
}

/// Factory for creating consistent test services and scenarios
class PipelineTestFactory {
  static final Map<String, Box> _openBoxes = {};
  
  /// Create a complete test service stack with mocked dependencies
  static Future<PipelineTestStack> createTestStack({
    required String testName,
    PipelineTestConfig? config,
  }) async {
    final stackConfig = config ?? const PipelineTestConfig(scenario: PipelineTestScenario.success);
    
    // Create mocks
    final mockHttpClient = MockHttpClient();
    final mockNostrService = MockNostrService();
    
    // Setup mock behaviors based on scenario
    _setupMockBehaviors(mockHttpClient, mockNostrService, stackConfig);
    
    // Create real services with mocked dependencies
    final apiService = ApiService(client: mockHttpClient);
    final uploadService = DirectUploadService();
    final notificationService = NotificationService.instance;
    
    // Create Hive box for this test
    final boxName = 'test_${testName}_${DateTime.now().millisecondsSinceEpoch}';
    final uploadsBox = await Hive.openBox<PendingUpload>(boxName);
    _openBoxes[boxName] = uploadsBox;
    
    final uploadManager = UploadManager(uploadService: uploadService);
    await uploadManager.initialize();
    
    final videoEventPublisher = VideoEventPublisher(
      uploadManager: uploadManager,
      nostrService: mockNostrService,
      fetchReadyEvents: () => apiService.getReadyEvents(),
      cleanupRemoteEvent: (publicId) => apiService.cleanupRemoteEvent(publicId),
    );
    
    return PipelineTestStack(
      uploadManager: uploadManager,
      uploadService: uploadService,
      videoEventPublisher: videoEventPublisher,
      apiService: apiService,
      notificationService: notificationService,
      mockHttpClient: mockHttpClient,
      mockNostrService: mockNostrService,
      uploadsBox: uploadsBox,
      config: stackConfig,
      boxName: boxName,
    );
  }
  
  /// Setup mock behaviors based on test scenario
  static void _setupMockBehaviors(
    MockHttpClient mockHttpClient,
    MockNostrService mockNostrService,
    PipelineTestConfig config,
  ) {
    switch (config.scenario) {
      case PipelineTestScenario.success:
        _setupSuccessScenario(mockHttpClient, mockNostrService, config);
        break;
      case PipelineTestScenario.uploadFailure:
        _setupUploadFailureScenario(mockHttpClient, mockNostrService, config);
        break;
      case PipelineTestScenario.processingFailure:
        _setupProcessingFailureScenario(mockHttpClient, mockNostrService, config);
        break;
      case PipelineTestScenario.nostrFailure:
        _setupNostrFailureScenario(mockHttpClient, mockNostrService, config);
        break;
      case PipelineTestScenario.networkTimeout:
        _setupNetworkTimeoutScenario(mockHttpClient, mockNostrService, config);
        break;
      case PipelineTestScenario.malformedResponse:
        _setupMalformedResponseScenario(mockHttpClient, mockNostrService, config);
        break;
      case PipelineTestScenario.partialSuccess:
        _setupPartialSuccessScenario(mockHttpClient, mockNostrService, config);
        break;
    }
  }
  
  static void _setupSuccessScenario(
    MockHttpClient mockHttpClient,
    MockNostrService mockNostrService,
    PipelineTestConfig config,
  ) {
    // Successful direct upload
    final uploadResponse = MockResponse();
    when(() => uploadResponse.statusCode).thenReturn(200);
    when(() => uploadResponse.body).thenReturn(jsonEncode({
      'videoId': config.videoId,
      'cdnUrl': config.cdnUrl,
      'metadata': {
        'bytes': 1024000,
        'width': 1920,
        'height': 1080,
        'duration': 6.5,
        ...?config.customMetadata,
      },
    }));
    
    when(() => mockHttpClient.post(
      any(),
      headers: any(named: 'headers'),
      body: any(named: 'body'),
    )).thenAnswer((_) async {
      if (config.networkDelay != null) {
        await Future.delayed(config.networkDelay!);
      }
      return uploadResponse;
    });
    
    // Successful ready events API (for direct upload, events are immediately ready)
    final readyEventResponse = MockResponse();
    when(() => readyEventResponse.statusCode).thenReturn(200);
    when(() => readyEventResponse.body).thenReturn(jsonEncode({
      'events': [{
        'videoId': config.videoId,
        'cdnUrl': config.cdnUrl,
        'content_suggestion': 'Test video content',
        'tags': [['url', config.cdnUrl], ['m', 'video/mp4']],
        'metadata': {'width': 1920, 'height': 1080},
        'processed_at': DateTime.now().toIso8601String(),
        'original_upload_id': config.uploadId,
        'mime_type': 'video/mp4',
        'file_size': 1024000,
      }]
    }));
    
    when(() => mockHttpClient.get(any(), headers: any(named: 'headers')))
        .thenAnswer((_) async {
          if (config.networkDelay != null) {
            await Future.delayed(config.networkDelay!);
          }
          return readyEventResponse;
        });
    
    // Successful Nostr broadcast
    when(() => mockNostrService.broadcastEvent(any()))
        .thenAnswer((_) async => NostrBroadcastResult(
          event: MockEvent(),
          successCount: 1,
          totalRelays: 1,
          results: {'relay1': true},
          errors: {},
        ));
    
    // Successful cleanup
    final cleanupResponse = MockResponse();
    when(() => cleanupResponse.statusCode).thenReturn(200);
    when(() => mockHttpClient.delete(any(), headers: any(named: 'headers')))
        .thenAnswer((_) async => cleanupResponse);
  }
  
  static void _setupUploadFailureScenario(
    MockHttpClient mockHttpClient,
    MockNostrService mockNostrService,
    PipelineTestConfig config,
  ) {
    // Failed Cloudinary upload
    final failedResponse = MockResponse();
    when(() => failedResponse.statusCode).thenReturn(400);
    when(() => failedResponse.body).thenReturn(jsonEncode({
      'error': {'message': 'Invalid file format'}
    }));
    
    when(() => mockHttpClient.post(
      any(),
      headers: any(named: 'headers'),
      body: any(named: 'body'),
    )).thenAnswer((_) async => failedResponse);
  }
  
  static void _setupProcessingFailureScenario(
    MockHttpClient mockHttpClient,
    MockNostrService mockNostrService,
    PipelineTestConfig config,
  ) {
    // Successful upload but no ready events (processing stuck)
    _setupSuccessScenario(mockHttpClient, mockNostrService, config);
    
    // Override ready events to return empty
    final emptyResponse = MockResponse();
    when(() => emptyResponse.statusCode).thenReturn(204);
    when(() => emptyResponse.body).thenReturn('');
    
    when(() => mockHttpClient.get(any(), headers: any(named: 'headers')))
        .thenAnswer((_) async => emptyResponse);
  }
  
  static void _setupNostrFailureScenario(
    MockHttpClient mockHttpClient,
    MockNostrService mockNostrService,
    PipelineTestConfig config,
  ) {
    // Successful upload and processing but Nostr broadcast fails
    _setupSuccessScenario(mockHttpClient, mockNostrService, config);
    
    // Override Nostr broadcast to fail
    when(() => mockNostrService.broadcastEvent(any()))
        .thenThrow(Exception('Relay connection failed'));
  }
  
  static void _setupNetworkTimeoutScenario(
    MockHttpClient mockHttpClient,
    MockNostrService mockNostrService,
    PipelineTestConfig config,
  ) {
    // Network requests that timeout
    when(() => mockHttpClient.get(any(), headers: any(named: 'headers')))
        .thenAnswer((_) async {
          await Future.delayed(const Duration(seconds: 35)); // Longer than timeout
          return MockResponse();
        });
    
    when(() => mockHttpClient.post(
      any(),
      headers: any(named: 'headers'),
      body: any(named: 'body'),
    )).thenAnswer((_) async {
      await Future.delayed(const Duration(seconds: 35));
      return MockResponse();
    });
  }
  
  static void _setupMalformedResponseScenario(
    MockHttpClient mockHttpClient,
    MockNostrService mockNostrService,
    PipelineTestConfig config,
  ) {
    // Valid HTTP response but malformed JSON
    final malformedResponse = MockResponse();
    when(() => malformedResponse.statusCode).thenReturn(200);
    when(() => malformedResponse.body).thenReturn('{"malformed": json, "missing": }');
    
    when(() => mockHttpClient.get(any(), headers: any(named: 'headers')))
        .thenAnswer((_) async => malformedResponse);
  }
  
  static void _setupPartialSuccessScenario(
    MockHttpClient mockHttpClient,
    MockNostrService mockNostrService,
    PipelineTestConfig config,
  ) {
    // Successful upload and processing, partial Nostr success
    _setupSuccessScenario(mockHttpClient, mockNostrService, config);
    
    // Override Nostr broadcast for partial success
    when(() => mockNostrService.broadcastEvent(any()))
        .thenAnswer((_) async => NostrBroadcastResult(
          event: MockEvent(),
          successCount: 1,
          totalRelays: 3, // Only 1 out of 3 relays succeeded
          results: {'relay1': true, 'relay2': false, 'relay3': false},
          errors: {'relay2': 'Connection timeout', 'relay3': 'Invalid event'},
        ));
  }
  
  /// Create a test file for upload scenarios
  static Future<File> createTestFile(Directory tempDir, String filename, {int? sizeBytes}) async {
    final file = File('${tempDir.path}/$filename');
    
    if (sizeBytes != null) {
      // Create file with specific size
      final data = List.generate(sizeBytes, (i) => i % 256);
      await file.writeAsBytes(data);
    } else {
      // Create minimal MP4 file
      await file.writeAsBytes(_createMinimalMp4());
    }
    
    return file;
  }
  
  /// Create a ReadyEventData for testing
  static ReadyEventData createTestReadyEvent({
    String? publicId,
    String? uploadId,
    String? videoUrl,
    Map<String, dynamic>? metadata,
  }) {
    return ReadyEventData(
      publicId: publicId ?? 'test-public-id',
      secureUrl: videoUrl ?? 'https://cloudinary.com/test.mp4',
      contentSuggestion: 'Test video for pipeline testing',
      tags: [
        ['url', videoUrl ?? 'https://cloudinary.com/test.mp4'],
        ['m', 'video/mp4'],
        ['size', '1024000'],
      ],
      metadata: metadata ?? {'width': 1920, 'height': 1080},
      processedAt: DateTime.now(),
      originalUploadId: uploadId ?? 'test-upload-id',
      mimeType: 'video/mp4',
      fileSize: 1024000,
      width: 1920,
      height: 1080,
      duration: 6.5,
    );
  }
  
  /// Clean up test resources
  static Future<void> cleanup() async {
    for (final box in _openBoxes.values) {
      try {
        await box.close();
      } catch (_) {}
    }
    _openBoxes.clear();
  }
  
  /// Helper to create minimal MP4 data
  static List<int> _createMinimalMp4() {
    // Minimal MP4 header that passes basic validation
    return [
      // ftyp box
      0x00, 0x00, 0x00, 0x20, // box size (32 bytes)
      0x66, 0x74, 0x79, 0x70, // 'ftyp'
      0x6d, 0x70, 0x34, 0x32, // 'mp42' major brand
      0x00, 0x00, 0x00, 0x00, // minor version
      0x6d, 0x70, 0x34, 0x32, // 'mp42' compatible brand
      // mdat box
      0x00, 0x00, 0x00, 0x0c, // box size (12 bytes)
      0x6d, 0x64, 0x61, 0x74, // 'mdat'
      0x00, 0x00, 0x00, 0x00, // empty media data
    ];
  }
}

/// Container for all test services and mocks
class PipelineTestStack {
  final UploadManager uploadManager;
  final DirectUploadService uploadService;
  final VideoEventPublisher videoEventPublisher;
  final ApiService apiService;
  final NotificationService notificationService;
  final MockHttpClient mockHttpClient;
  final MockNostrService mockNostrService;
  final Box<PendingUpload> uploadsBox;
  final PipelineTestConfig config;
  final String boxName;
  
  const PipelineTestStack({
    required this.uploadManager,
    required this.uploadService,
    required this.videoEventPublisher,
    required this.apiService,
    required this.notificationService,
    required this.mockHttpClient,
    required this.mockNostrService,
    required this.uploadsBox,
    required this.config,
    required this.boxName,
  });
  
  /// Initialize all services for testing
  Future<void> initialize() async {
    await notificationService.initialize();
    await videoEventPublisher.initialize();
  }
  
  /// Dispose all test resources
  Future<void> dispose() async {
    videoEventPublisher.dispose();
    uploadManager.dispose();
    apiService.dispose();
    await uploadsBox.close();
    try {
      await Hive.deleteBoxFromDisk(boxName);
    } catch (_) {}
  }
  
  /// Execute a complete pipeline test with this stack
  Future<PipelineTestResult> executeFullPipeline({
    required File testFile,
    String? uploadTitle,
    List<String>? hashtags,
  }) async {
    final result = PipelineTestResult();
    
    try {
      // Step 1: Start upload
      result.startTime = DateTime.now();
      final upload = await uploadManager.startUpload(
        videoFile: testFile,
        nostrPubkey: 'test-pubkey-${DateTime.now().millisecondsSinceEpoch}',
        title: uploadTitle ?? 'Pipeline Test Video',
        hashtags: hashtags ?? ['test'],
      );
      result.upload = upload;
      result.uploadCreated = true;
      
      // Step 2: Simulate processing completion (for direct upload, it's immediately ready)
      await uploadManager.markUploadReadyToPublish(upload.id, config.videoId);
      result.markedReady = true;
      
      // Step 3: Trigger background publishing
      await videoEventPublisher.forceCheck();
      result.publishingTriggered = true;
      
      // Wait for processing
      await Future.delayed(const Duration(milliseconds: 200));
      
      // Step 4: Check final state
      final finalUpload = uploadManager.getUpload(upload.id);
      result.finalUpload = finalUpload;
      result.finalStatus = finalUpload?.status;
      
      result.success = finalUpload?.status == UploadStatus.published;
      result.endTime = DateTime.now();
      
    } catch (e, stackTrace) {
      result.error = e;
      result.stackTrace = stackTrace;
      result.endTime = DateTime.now();
    }
    
    return result;
  }
}

/// Result of a pipeline test execution
class PipelineTestResult {
  DateTime? startTime;
  DateTime? endTime;
  PendingUpload? upload;
  PendingUpload? finalUpload;
  UploadStatus? finalStatus;
  bool uploadCreated = false;
  bool markedReady = false;
  bool publishingTriggered = false;
  bool success = false;
  Object? error;
  StackTrace? stackTrace;
  
  Duration? get duration => startTime != null && endTime != null 
      ? endTime!.difference(startTime!) 
      : null;
      
  Map<String, dynamic> toSummary() {
    return {
      'success': success,
      'duration_ms': duration?.inMilliseconds,
      'upload_created': uploadCreated,
      'marked_ready': markedReady,
      'publishing_triggered': publishingTriggered,
      'final_status': finalStatus?.toString(),
      'error': error?.toString(),
      'upload_id': upload?.id,
    };
  }
}