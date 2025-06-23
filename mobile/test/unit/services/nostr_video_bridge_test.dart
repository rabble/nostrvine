// ABOUTME: Unit tests for NostrVideoBridge integration service
// ABOUTME: Tests event processing, filtering, VideoManager integration, and lifecycle management

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/services/nostr_video_bridge.dart';
import 'package:openvine/services/video_manager_interface.dart';
import 'package:openvine/services/nostr_service_interface.dart';
import 'package:openvine/services/seen_videos_service.dart';
import 'package:openvine/services/connection_status_service.dart';
import 'package:openvine/models/video_event.dart';
import '../../helpers/test_helpers.dart';
import '../../mocks/mock_video_manager.dart';

// Mock classes
class MockNostrService extends Mock implements INostrService {}
class MockSeenVideosService extends Mock implements SeenVideosService {}
class MockConnectionStatusService extends Mock implements ConnectionStatusService {}

void main() {
  group('NostrVideoBridge', () {
    late NostrVideoBridge bridge;
    late MockVideoManager mockVideoManager;
    late MockNostrService mockNostrService;
    late MockSeenVideosService? mockSeenVideosService;
    late MockConnectionStatusService mockConnectionService;

    setUpAll(() {
      // Register fallback values
      registerFallbackValue(TestHelpers.createVideoEvent());
    });

    setUp(() {
      mockVideoManager = MockVideoManager();
      mockNostrService = MockNostrService();
      mockSeenVideosService = MockSeenVideosService();
      mockConnectionService = MockConnectionStatusService();

      // Setup default mock behaviors (only what's actually needed)
      when(() => mockVideoManager.addVideoEvent(any())).thenAnswer((_) async {});
      when(() => mockVideoManager.getDebugInfo()).thenReturn({
        'totalVideos': 0,
        'controllers': 0,
        'estimatedMemoryMB': 0,
      });

      // Create bridge with all dependencies
      bridge = NostrVideoBridge(
        videoManager: mockVideoManager,
        nostrService: mockNostrService,
        seenVideosService: mockSeenVideosService,
        connectionService: mockConnectionService,
      );
    });

    tearDown(() {
      bridge.dispose();
    });

    group('Initialization and Lifecycle', () {
      test('should initialize with inactive state', () {
        expect(bridge.isActive, isFalse);
        
        final stats = bridge.processingStats;
        expect(stats['isActive'], isFalse);
        expect(stats['totalEventsReceived'], 0);
        expect(stats['totalEventsAdded'], 0);
        expect(stats['totalEventsFiltered'], 0);
      });

      test('should provide processing statistics', () {
        final stats = bridge.processingStats;
        
        expect(stats, containsPair('isActive', false));
        expect(stats, containsPair('totalEventsReceived', 0));
        expect(stats, containsPair('totalEventsAdded', 0));
        expect(stats, containsPair('totalEventsFiltered', 0));
        expect(stats, containsPair('processedEventIds', 0));
        expect(stats, containsPair('lastEventReceived', null));
        expect(stats, containsPair('videoEventServiceStats', isA<Map>()));
      });

      test('should provide debug information', () {
        final debugInfo = bridge.getDebugInfo();
        
        expect(debugInfo, containsPair('bridge', isA<Map>()));
        expect(debugInfo, containsPair('videoManager', isA<Map>()));
        expect(debugInfo, containsPair('videoEventService', isA<Map>()));
        expect(debugInfo, containsPair('connection', isA<bool>()));
      });

      test('should be disposable', () {
        expect(() => bridge.dispose(), returnsNormally);
        expect(bridge.isActive, isFalse);
      });
    });

    group('Factory Method', () {
      test('should create bridge with all dependencies', () {
        // ACT
        final factoryBridge = NostrVideoBridgeFactory.create(
          videoManager: mockVideoManager,
          nostrService: mockNostrService,
          seenVideosService: mockSeenVideosService,
          connectionService: mockConnectionService,
        );

        // ASSERT
        expect(factoryBridge, isA<NostrVideoBridge>());
        expect(factoryBridge.isActive, isFalse);
        
        factoryBridge.dispose();
      });

      test('should create bridge with minimal dependencies', () {
        // ACT
        final minimalBridge = NostrVideoBridgeFactory.create(
          videoManager: mockVideoManager,
          nostrService: mockNostrService,
        );

        // ASSERT
        expect(minimalBridge, isA<NostrVideoBridge>());
        expect(minimalBridge.isActive, isFalse);
        
        minimalBridge.dispose();
      });
    });

  });
}