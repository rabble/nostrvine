# TDD Video System Rebuild - Detailed Implementation Tasks

## 🎯 EXECUTION STRATEGY

**Test-Driven Development Approach**: Write tests first, implement to make tests pass, refactor, repeat.

**Timeline**: 5 weeks total, working in strict TDD cycles

---

## 📅 WEEK 1: TEST FOUNDATION

### 🔥 TASK 1.1: Project Setup & Test Infrastructure (Day 1)

**Duration**: 4-6 hours  
**Prerequisites**: None  
**Goal**: Set up comprehensive testing framework

#### Specific Steps:
- [ ] **Install testing dependencies**
  ```yaml
  # pubspec.yaml additions
  dev_dependencies:
    flutter_test:
    mockito: ^5.4.0
    build_runner: ^2.4.0
    integration_test:
    flutter_driver:
    test: ^1.21.0
  ```

- [ ] **Create test directory structure**
  ```
  test/
  ├── unit/
  │   ├── models/
  │   ├── services/
  │   └── utils/
  ├── widget/
  │   ├── screens/
  │   └── widgets/
  ├── integration/
  ├── mocks/
  └── helpers/
  ```

- [ ] **Set up mock generation**
  ```dart
  // test/mocks/mock_annotations.dart
  @GenerateMocks([
    VideoPlayerController,
    ChangeNotifier,
    INostrService,
  ])
  void main() {}
  ```

- [ ] **Create test helpers**
  ```dart
  // test/helpers/test_helpers.dart
  class TestHelpers {
    static VideoEvent createMockVideoEvent({String? id, String? url});
    static Event createMockNostrEvent({int? kind, String? content});
    static Future<void> pumpUntilFound(WidgetTester tester, Finder finder);
  }
  ```

- [ ] **Run test generation**
  ```bash
  flutter packages pub run build_runner build
  ```

**✅ Done Criteria**: 
- [ ] All dependencies installed
- [ ] Test directory structure created
- [ ] Mock generation working
- [ ] Basic test helpers implemented
- [ ] `flutter test` runs successfully (even if no tests yet)

---

### 🔥 TASK 1.2: Core Behavior Test Specification (Day 2)

**Duration**: 6-8 hours  
**Prerequisites**: Task 1.1 complete  
**Goal**: Define expected behavior through failing tests

#### Specific Steps:

- [ ] **Create VideoState lifecycle tests**
  ```dart
  // test/unit/models/video_state_test.dart
  void main() {
    group('VideoState', () {
      testWidgets('should transition through states correctly', (tester) async {
        // ARRANGE: Create initial state
        final videoEvent = TestHelpers.createMockVideoEvent();
        final initialState = VideoState(
          event: videoEvent,
          loadingState: VideoLoadingState.notLoaded,
          lastUpdated: DateTime.now(),
        );
        
        // ACT & ASSERT: Test state transitions
        expect(initialState.loadingState, VideoLoadingState.notLoaded);
        expect(initialState.isReady, false);
        expect(initialState.isLoading, false);
        
        final loadingState = initialState.copyWith(
          loadingState: VideoLoadingState.loading,
        );
        expect(loadingState.isLoading, true);
        expect(loadingState.isReady, false);
        
        // This will fail until VideoState is implemented
      });
      
      testWidgets('should handle error states correctly', (tester) async {
        // Test error state behavior
        // Test retry logic
        // Test permanent failure
      });
      
      testWidgets('should manage controller lifecycle', (tester) async {
        // Test controller assignment
        // Test controller disposal
        // Test null controller handling
      });
    });
  }
  ```

- [ ] **Create VideoManager interface tests**
  ```dart
  // test/unit/services/video_manager_interface_test.dart
  void main() {
    group('IVideoManager Contract', () {
      testWidgets('should maintain single source of truth', (tester) async {
        // This will test the interface contract
        // Will fail until interface and implementation exist
        
        final manager = MockVideoManager(); // Will create this
        
        // ACT: Add video events
        final event1 = TestHelpers.createMockVideoEvent(id: 'video1');
        final event2 = TestHelpers.createMockVideoEvent(id: 'video2');
        
        await manager.addVideoEvent(event1);
        await manager.addVideoEvent(event2);
        
        // ASSERT: Videos should be in correct order
        expect(manager.videos.length, 2);
        expect(manager.videos[0].id, 'video2'); // Newest first
        expect(manager.videos[1].id, 'video1');
        
        // ASSERT: No index mismatches
        expect(manager.getVideoState('video1'), isNotNull);
        expect(manager.getVideoState('video2'), isNotNull);
      });
      
      testWidgets('should handle memory limits correctly', (tester) async {
        final manager = MockVideoManager();
        
        // ACT: Add more videos than memory limit
        for (int i = 0; i < 150; i++) {
          final event = TestHelpers.createMockVideoEvent(id: 'video$i');
          await manager.addVideoEvent(event);
        }
        
        // ASSERT: Should not exceed memory limit
        expect(manager.videos.length, lessThanOrEqualTo(100));
        
        // ASSERT: Should keep newest videos
        expect(manager.videos.first.id, 'video149');
      });
      
      testWidgets('should preload videos correctly', (tester) async {
        final manager = MockVideoManager();
        final event = TestHelpers.createMockVideoEvent(id: 'video1');
        
        await manager.addVideoEvent(event);
        
        // ACT: Preload video
        await manager.preloadVideo('video1');
        
        // ASSERT: Video should be ready
        final state = manager.getVideoState('video1');
        expect(state?.isReady, true);
        expect(state?.controller, isNotNull);
      });
    });
  }
  ```

- [ ] **Create UI integration tests**
  ```dart
  // test/widget/screens/feed_screen_test.dart
  void main() {
    group('FeedScreen Integration', () {
      testWidgets('should display videos correctly', (tester) async {
        // This will fail until new UI is implemented
        
        final mockManager = MockVideoManager();
        // Set up mock to return test videos
        
        await tester.pumpWidget(
          MaterialApp(
            home: Provider<IVideoManager>.value(
              value: mockManager,
              child: FeedScreenV2(), // New implementation
            ),
          ),
        );
        
        // ASSERT: Should show loading initially
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        
        // ACT: Provide videos to mock
        mockManager.addMockVideos([
          TestHelpers.createMockVideoEvent(id: 'video1'),
          TestHelpers.createMockVideoEvent(id: 'video2'),
        ]);
        
        await tester.pump();
        
        // ASSERT: Should show video widgets
        expect(find.byType(VideoFeedItemV2), findsWidgets);
        expect(find.byType(PageView), findsOneWidget);
      });
      
      testWidgets('should handle index bounds correctly', (tester) async {
        // Test that scrolling beyond bounds doesn't crash
        // Test error handling for invalid indices
      });
      
      testWidgets('should trigger preloading correctly', (tester) async {
        // Test that scrolling triggers preload calls
        // Test preload timing and logic
      });
    });
  }
  ```

- [ ] **Create performance tests**
  ```dart
  // test/integration/performance_test.dart
  void main() {
    group('Performance Tests', () {
      testWidgets('should handle 100+ videos without memory issues', (tester) async {
        final manager = VideoManagerService(); // Real implementation
        
        // ACT: Add many videos
        final stopwatch = Stopwatch()..start();
        for (int i = 0; i < 100; i++) {
          final event = TestHelpers.createMockVideoEvent(id: 'video$i');
          await manager.addVideoEvent(event);
        }
        stopwatch.stop();
        
        // ASSERT: Performance targets
        expect(stopwatch.elapsedMilliseconds, lessThan(5000)); // <5 seconds
        
        // ASSERT: Memory targets (this will need platform-specific implementation)
        // expect(manager.estimatedMemoryUsageMB, lessThan(500));
      });
      
      testWidgets('should handle rapid scrolling', (tester) async {
        // Test rapid PageView changes
        // Test preloading under stress
        // Test memory cleanup during rapid scrolling
      });
    });
  }
  ```

**✅ Done Criteria**:
- [ ] All test files created and failing appropriately
- [ ] Test scenarios cover all major behaviors
- [ ] Performance benchmarks defined
- [ ] Mock objects specified
- [ ] Test coverage targets defined (>90%)

---

### 🔥 TASK 1.3: Mock Data & Test Utilities (Day 3)

**Duration**: 4-6 hours  
**Prerequisites**: Task 1.2 complete  
**Goal**: Create comprehensive test data and utilities

#### Specific Steps:

- [ ] **Create comprehensive mock data**
  ```dart
  // test/helpers/mock_data.dart
  class MockData {
    static VideoEvent createVideoEvent({
      String? id,
      String? videoUrl,
      String? title,
      String? author,
      bool isGif = false,
      DateTime? createdAt,
    }) {
      return VideoEvent(
        id: id ?? 'mock_${DateTime.now().millisecondsSinceEpoch}',
        videoUrl: videoUrl ?? 'https://example.com/video.mp4',
        title: title ?? 'Mock Video Title',
        author: author ?? 'mock_author',
        isGif: isGif,
        createdAt: createdAt ?? DateTime.now(),
        // ... other required fields
      );
    }
    
    static Event createNostrEvent({
      String? id,
      int kind = 22,
      String? content,
      List<List<String>>? tags,
    }) {
      return Event(
        id: id ?? 'mock_event_id',
        kind: kind,
        content: content ?? 'Mock video content',
        tags: tags ?? [
          ['url', 'https://example.com/video.mp4'],
          ['m', 'video/mp4'],
          ['size', '1024000'],
        ],
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        pubkey: 'mock_pubkey',
        sig: 'mock_signature',
      );
    }
    
    static List<VideoEvent> createVideoList(int count) {
      return List.generate(count, (index) => createVideoEvent(
        id: 'video_$index',
        title: 'Test Video $index',
      ));
    }
    
    // Create videos with specific states for testing
    static VideoEvent createFailingVideoEvent() {
      return createVideoEvent(
        videoUrl: 'https://invalid-url-that-will-fail.com/video.mp4',
      );
    }
    
    static VideoEvent createSlowVideoEvent() {
      return createVideoEvent(
        videoUrl: 'https://httpbin.org/delay/5', // 5 second delay
      );
    }
  }
  ```

- [ ] **Create test utilities**
  ```dart
  // test/helpers/test_utilities.dart
  class TestUtilities {
    /// Pump widget until specific condition is met or timeout
    static Future<void> pumpUntilCondition(
      WidgetTester tester,
      bool Function() condition, {
      Duration timeout = const Duration(seconds: 10),
    }) async {
      final stopwatch = Stopwatch()..start();
      while (!condition() && stopwatch.elapsed < timeout) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      if (!condition()) {
        throw TimeoutException('Condition not met within timeout', timeout);
      }
    }
    
    /// Wait for video to be in specific state
    static Future<void> waitForVideoState(
      WidgetTester tester,
      IVideoManager manager,
      String videoId,
      VideoLoadingState expectedState, {
      Duration timeout = const Duration(seconds: 10),
    }) async {
      await pumpUntilCondition(
        tester,
        () => manager.getVideoState(videoId)?.loadingState == expectedState,
        timeout: timeout,
      );
    }
    
    /// Simulate network connectivity changes
    static void simulateNetworkChange(bool isConnected) {
      // Mock network connectivity for testing
    }
    
    /// Create a test app wrapper with all required providers
    static Widget createTestApp({
      required Widget child,
      IVideoManager? videoManager,
      INostrService? nostrService,
    }) {
      return MaterialApp(
        home: MultiProvider(
          providers: [
            Provider<IVideoManager>.value(
              value: videoManager ?? MockVideoManager(),
            ),
            Provider<INostrService>.value(
              value: nostrService ?? MockNostrService(),
            ),
          ],
          child: child,
        ),
      );
    }
  }
  ```

- [ ] **Create mock implementations**
  ```dart
  // test/mocks/mock_video_manager.dart
  class MockVideoManager extends Mock implements IVideoManager {
    final List<VideoEvent> _videos = [];
    final Map<String, VideoState> _videoStates = {};
    
    @override
    List<VideoEvent> get videos => _videos;
    
    @override
    VideoState? getVideoState(String videoId) => _videoStates[videoId];
    
    @override
    Future<void> addVideoEvent(VideoEvent event) async {
      _videos.insert(0, event); // Newest first
      _videoStates[event.id] = VideoState(
        event: event,
        loadingState: VideoLoadingState.notLoaded,
        lastUpdated: DateTime.now(),
      );
    }
    
    @override
    Future<void> preloadVideo(String videoId) async {
      final state = _videoStates[videoId];
      if (state != null) {
        _videoStates[videoId] = state.copyWith(
          loadingState: VideoLoadingState.ready,
          controller: MockVideoPlayerController(), // Mock controller
        );
      }
    }
    
    // Additional helper methods for testing
    void addMockVideos(List<VideoEvent> videos) {
      for (final video in videos) {
        addVideoEvent(video);
      }
    }
    
    void simulateVideoLoad(String videoId, {bool success = true}) {
      final state = _videoStates[videoId];
      if (state != null) {
        _videoStates[videoId] = state.copyWith(
          loadingState: success 
            ? VideoLoadingState.ready 
            : VideoLoadingState.failed,
          errorMessage: success ? null : 'Mock load failure',
        );
      }
    }
  }
  ```

- [ ] **Create test configuration**
  ```dart
  // test/test_config.dart
  class TestConfig {
    static const Duration defaultTimeout = Duration(seconds: 10);
    static const Duration videoLoadTimeout = Duration(seconds: 5);
    static const int maxTestVideos = 100;
    static const int memoryLimitMB = 500;
    
    // Test environment flags
    static bool get useRealNetwork => false;
    static bool get enablePerformanceTests => true;
    static bool get enableMemoryTests => true;
  }
  ```

**✅ Done Criteria**:
- [ ] Comprehensive mock data created
- [ ] Test utilities implemented and working
- [ ] Mock implementations created
- [ ] Test configuration established
- [ ] All tests can be run with mocks (even if failing)

---

### 🔥 TASK 1.4: Test Execution & Baseline (Day 4)

**Duration**: 4-6 hours  
**Prerequisites**: Tasks 1.1-1.3 complete  
**Goal**: Run all tests, establish baseline, ensure proper test infrastructure

#### Specific Steps:

- [ ] **Run all tests and document failures**
  ```bash
  # Run all tests
  flutter test --coverage
  
  # Generate coverage report
  genhtml coverage/lcov.info -o coverage/html
  open coverage/html/index.html
  ```

- [ ] **Document expected test failures**
  ```markdown
  # Test Status Baseline (Week 1 End)
  
  ## Expected Failures (These should fail - no implementation yet):
  - [ ] VideoState model tests (no model exists)
  - [ ] VideoManager interface tests (no implementation)
  - [ ] UI integration tests (no new UI components)
  - [ ] Performance tests (no system to test)
  
  ## Should Pass:
  - [ ] Mock data creation
  - [ ] Test utilities
  - [ ] Test infrastructure
  
  ## Coverage Target:
  - Current: 0% (no implementation)
  - Target by Week 5: >90%
  ```

- [ ] **Validate test infrastructure**
  ```dart
  // test/infrastructure_test.dart
  void main() {
    group('Test Infrastructure Validation', () {
      test('Mock data creation works', () {
        final video = MockData.createVideoEvent();
        expect(video.id, isNotEmpty);
        expect(video.videoUrl, isNotEmpty);
      });
      
      test('Test utilities work', () {
        final app = TestUtilities.createTestApp(
          child: Container(),
        );
        expect(app, isA<MaterialApp>());
      });
      
      test('Mock implementations work', () {
        final manager = MockVideoManager();
        expect(manager.videos, isEmpty);
      });
    });
  }
  ```

- [ ] **Set up continuous testing**
  ```bash
  # Add to .github/workflows/test.yml (if using GitHub)
  name: Tests
  on: [push, pull_request]
  jobs:
    test:
      runs-on: ubuntu-latest
      steps:
        - uses: actions/checkout@v2
        - uses: subosito/flutter-action@v2
        - run: flutter test --coverage
        - run: flutter test integration_test/
  ```

- [ ] **Create test documentation**
  ```markdown
  # Testing Strategy Documentation
  
  ## Test Types:
  1. **Unit Tests**: Individual components (models, services)
  2. **Widget Tests**: UI components in isolation
  3. **Integration Tests**: Full system behavior
  4. **Performance Tests**: Memory, speed, reliability
  
  ## Running Tests:
  - Unit tests: `flutter test test/unit/`
  - Widget tests: `flutter test test/widget/`
  - Integration tests: `flutter test integration_test/`
  - Coverage: `flutter test --coverage`
  
  ## Test-Driven Development Process:
  1. Write failing test
  2. Write minimal implementation
  3. Verify test passes
  4. Refactor if needed
  5. Add more tests
  ```

**✅ Done Criteria**:
- [ ] All tests run successfully (even if many fail)
- [ ] Test infrastructure validated
- [ ] Coverage reporting working
- [ ] Baseline documentation created
- [ ] CI/CD setup (if applicable)
- [ ] Ready to begin implementation in Week 2

---

## 📅 WEEK 2: CORE MODELS

### 🔥 TASK 2.1: VideoState Model Implementation (Day 1)

**Duration**: 6-8 hours  
**Prerequisites**: Week 1 complete  
**Goal**: Implement VideoState model to pass all related tests

#### Specific Steps:

- [ ] **Create VideoState enum**
  ```dart
  // lib/models/video_loading_state.dart
  enum VideoLoadingState {
    /// Video just created, no controller yet
    notLoaded,
    
    /// Controller being created/initialized
    loading,
    
    /// Ready to play, controller initialized
    ready,
    
    /// Failed to load (temporary, can retry)
    failed,
    
    /// Failed multiple times (permanent, don't retry)
    permanentlyFailed,
    
    /// Cleaned up, controller disposed
    disposed,
  }
  
  extension VideoLoadingStateX on VideoLoadingState {
    bool get canRetry => this == VideoLoadingState.failed;
    bool get isTerminal => this == VideoLoadingState.permanentlyFailed || 
                           this == VideoLoadingState.disposed;
  }
  ```

- [ ] **Implement VideoState model**
  ```dart
  // lib/models/video_state.dart
  import 'package:video_player/video_player.dart';
  import 'package:equatable/equatable.dart';
  import '../models/video_event.dart';
  import 'video_loading_state.dart';
  
  class VideoState extends Equatable {
    final VideoEvent event;
    final VideoPlayerController? controller;
    final VideoLoadingState loadingState;
    final String? errorMessage;
    final DateTime lastUpdated;
    final int failureCount;
    
    const VideoState({
      required this.event,
      this.controller,
      required this.loadingState,
      this.errorMessage,
      required this.lastUpdated,
      this.failureCount = 0,
    });
    
    // Convenience getters
    bool get isReady => loadingState == VideoLoadingState.ready && 
                       controller?.value.isInitialized == true;
    
    bool get isLoading => loadingState == VideoLoadingState.loading;
    
    bool get hasFailed => loadingState == VideoLoadingState.failed || 
                         loadingState == VideoLoadingState.permanentlyFailed;
    
    bool get canRetry => loadingState.canRetry && failureCount < 3;
    
    bool get isDisposed => loadingState == VideoLoadingState.disposed;
    
    // Immutable updates
    VideoState copyWith({
      VideoPlayerController? controller,
      VideoLoadingState? loadingState,
      String? errorMessage,
      int? failureCount,
    }) {
      return VideoState(
        event: event,
        controller: controller ?? this.controller,
        loadingState: loadingState ?? this.loadingState,
        errorMessage: errorMessage ?? this.errorMessage,
        lastUpdated: DateTime.now(),
        failureCount: failureCount ?? this.failureCount,
      );
    }
    
    // Create initial state
    factory VideoState.initial(VideoEvent event) {
      return VideoState(
        event: event,
        loadingState: VideoLoadingState.notLoaded,
        lastUpdated: DateTime.now(),
      );
    }
    
    // Create loading state
    VideoState toLoading() {
      return copyWith(loadingState: VideoLoadingState.loading);
    }
    
    // Create ready state
    VideoState toReady(VideoPlayerController controller) {
      return copyWith(
        controller: controller,
        loadingState: VideoLoadingState.ready,
        errorMessage: null,
      );
    }
    
    // Create failed state
    VideoState toFailed(String error) {
      final newFailureCount = failureCount + 1;
      return copyWith(
        loadingState: newFailureCount >= 3 
          ? VideoLoadingState.permanentlyFailed 
          : VideoLoadingState.failed,
        errorMessage: error,
        failureCount: newFailureCount,
      );
    }
    
    // Create disposed state
    VideoState toDisposed() {
      return copyWith(
        controller: null,
        loadingState: VideoLoadingState.disposed,
      );
    }
    
    @override
    List<Object?> get props => [
      event.id,
      loadingState,
      errorMessage,
      failureCount,
      controller?.hashCode, // Don't use controller directly in equality
    ];
    
    @override
    String toString() {
      return 'VideoState('
        'id: ${event.id.substring(0, 8)}..., '
        'state: $loadingState, '
        'failures: $failureCount, '
        'hasController: ${controller != null}'
        ')';
    }
  }
  ```

- [ ] **Run VideoState tests and make them pass**
  ```bash
  flutter test test/unit/models/video_state_test.dart
  ```

- [ ] **Add additional VideoState tests**
  ```dart
  // Add to test/unit/models/video_state_test.dart
  group('VideoState Edge Cases', () {
    test('should handle null controller correctly', () {
      final event = MockData.createVideoEvent();
      final state = VideoState.initial(event);
      
      expect(state.controller, isNull);
      expect(state.isReady, false);
    });
    
    test('should increment failure count correctly', () {
      final event = MockData.createVideoEvent();
      final state = VideoState.initial(event);
      
      final failed1 = state.toFailed('Error 1');
      expect(failed1.failureCount, 1);
      expect(failed1.canRetry, true);
      
      final failed2 = failed1.toFailed('Error 2');
      expect(failed2.failureCount, 2);
      expect(failed2.canRetry, true);
      
      final failed3 = failed2.toFailed('Error 3');
      expect(failed3.failureCount, 3);
      expect(failed3.canRetry, false);
      expect(failed3.loadingState, VideoLoadingState.permanentlyFailed);
    });
    
    test('should maintain immutability', () {
      final event = MockData.createVideoEvent();
      final state1 = VideoState.initial(event);
      final state2 = state1.toLoading();
      
      expect(state1.loadingState, VideoLoadingState.notLoaded);
      expect(state2.loadingState, VideoLoadingState.loading);
      expect(identical(state1, state2), false);
    });
  });
  ```

**✅ Done Criteria**:
- [ ] All VideoState tests passing
- [ ] Model properly handles all state transitions
- [ ] Immutability maintained
- [ ] Edge cases covered
- [ ] Documentation complete

---

### 🔥 TASK 2.2: IVideoManager Interface (Day 2)

**Duration**: 4-6 hours  
**Prerequisites**: Task 2.1 complete  
**Goal**: Define and test the VideoManager interface contract

#### Specific Steps:

- [ ] **Create IVideoManager interface**
  ```dart
  // lib/services/video_manager_interface.dart
  import '../models/video_event.dart';
  import '../models/video_state.dart';
  import 'package:video_player/video_player.dart';
  
  /// Interface for managing video state and lifecycle
  /// 
  /// This is the single source of truth for all video-related state.
  /// Replaces the dual-list system (VideoEventService + VideoCacheService).
  abstract class IVideoManager {
    /// Get ordered list of videos for display (newest first)
    /// This is the single source of truth - no more dual lists!
    List<VideoEvent> get videos;
    
    /// Get videos that are ready to play immediately
    List<VideoEvent> get readyVideos;
    
    /// Get current state of a specific video
    VideoState? getVideoState(String videoId);
    
    /// Get controller for playback (null if not ready)
    VideoPlayerController? getController(String videoId);
    
    /// Add new video event (from Nostr or other source)
    Future<void> addVideoEvent(VideoEvent event);
    
    /// Preload video for smooth playback
    Future<void> preloadVideo(String videoId);
    
    /// Preload videos around current position
    void preloadAroundIndex(int currentIndex);
    
    /// Dispose specific video controller
    void disposeVideo(String videoId);
    
    /// Get debug information for monitoring
    Map<String, dynamic> getDebugInfo();
    
    /// Clean up all resources
    void dispose();
    
    /// Stream of state changes for UI updates
    Stream<void> get stateChanges;
  }
  
  /// Configuration for VideoManager behavior
  class VideoManagerConfig {
    final int maxVideos;
    final int preloadAhead;
    final int maxRetries;
    final Duration preloadTimeout;
    final bool enableMemoryManagement;
    
    const VideoManagerConfig({
      this.maxVideos = 100,
      this.preloadAhead = 3,
      this.maxRetries = 3,
      this.preloadTimeout = const Duration(seconds: 10),
      this.enableMemoryManagement = true,
    });
  }
  
  /// Exceptions thrown by video manager
  class VideoManagerException implements Exception {
    final String message;
    final String? videoId;
    final dynamic originalError;
    
    const VideoManagerException(
      this.message, {
      this.videoId,
      this.originalError,
    });
    
    @override
    String toString() => 'VideoManagerException: $message'
        '${videoId != null ? ' (video: $videoId)' : ''}'
        '${originalError != null ? ' (caused by: $originalError)' : ''}';
  }
  ```

- [ ] **Create interface contract tests**
  ```dart
  // test/unit/services/video_manager_interface_test.dart
  import 'package:flutter_test/flutter_test.dart';
  import 'package:nostrvine_app/services/video_manager_interface.dart';
  import '../../helpers/mock_data.dart';
  import '../../mocks/mock_video_manager.dart';
  
  /// Tests that define the contract that any IVideoManager implementation must follow
  void main() {
    group('IVideoManager Contract Tests', () {
      late IVideoManager manager;
      
      setUp(() {
        manager = MockVideoManager(); // Will create improved version
      });
      
      group('Single Source of Truth', () {
        test('should maintain consistent video list', () async {
          // ARRANGE
          final event1 = MockData.createVideoEvent(id: 'video1');
          final event2 = MockData.createVideoEvent(id: 'video2');
          
          // ACT
          await manager.addVideoEvent(event1);
          await manager.addVideoEvent(event2);
          
          // ASSERT: Videos in correct order (newest first)
          expect(manager.videos.length, 2);
          expect(manager.videos[0].id, 'video2');
          expect(manager.videos[1].id, 'video1');
          
          // ASSERT: All videos have state
          expect(manager.getVideoState('video1'), isNotNull);
          expect(manager.getVideoState('video2'), isNotNull);
        });
        
        test('should prevent duplicate videos', () async {
          // ARRANGE
          final event = MockData.createVideoEvent(id: 'duplicate');
          
          // ACT
          await manager.addVideoEvent(event);
          await manager.addVideoEvent(event); // Same event again
          
          // ASSERT: Only one copy
          expect(manager.videos.length, 1);
        });
      });
      
      group('Memory Management', () {
        test('should enforce video limits', () async {
          // ARRANGE: Add more videos than limit
          final config = VideoManagerConfig(maxVideos: 10);
          // Note: Would need to pass config to manager constructor
          
          // ACT: Add 15 videos
          for (int i = 0; i < 15; i++) {
            final event = MockData.createVideoEvent(id: 'video$i');
            await manager.addVideoEvent(event);
          }
          
          // ASSERT: Should not exceed limit
          expect(manager.videos.length, lessThanOrEqualTo(10));
          
          // ASSERT: Should keep newest videos
          expect(manager.videos.first.id, 'video14');
        });
        
        test('should clean up disposed controllers', () async {
          // ARRANGE
          final event = MockData.createVideoEvent(id: 'test');
          await manager.addVideoEvent(event);
          await manager.preloadVideo('test');
          
          // Verify video is ready
          expect(manager.getVideoState('test')?.isReady, true);
          
          // ACT: Dispose video
          manager.disposeVideo('test');
          
          // ASSERT: Controller should be null, state should be disposed
          expect(manager.getController('test'), isNull);
          expect(manager.getVideoState('test')?.isDisposed, true);
        });
      });
      
      group('Video Preloading', () {
        test('should preload video correctly', () async {
          // ARRANGE
          final event = MockData.createVideoEvent(id: 'test');
          await manager.addVideoEvent(event);
          
          // Initial state should be notLoaded
          expect(manager.getVideoState('test')?.loadingState, 
                 VideoLoadingState.notLoaded);
          
          // ACT: Preload video
          await manager.preloadVideo('test');
          
          // ASSERT: Video should be ready
          final state = manager.getVideoState('test');
          expect(state?.isReady, true);
          expect(manager.getController('test'), isNotNull);
        });
        
        test('should handle preload failures', () async {
          // ARRANGE: Create video that will fail to load
          final event = MockData.createFailingVideoEvent();
          await manager.addVideoEvent(event);
          
          // ACT: Try to preload
          await manager.preloadVideo(event.id);
          
          // ASSERT: Should be in failed state
          final state = manager.getVideoState(event.id);
          expect(state?.hasFailed, true);
          expect(state?.errorMessage, isNotNull);
          expect(manager.getController(event.id), isNull);
        });
        
        test('should not preload same video twice', () async {
          // ARRANGE
          final event = MockData.createVideoEvent(id: 'test');
          await manager.addVideoEvent(event);
          
          // ACT: Preload twice
          await manager.preloadVideo('test');
          await manager.preloadVideo('test'); // Should be no-op
          
          // ASSERT: Should still work correctly
          expect(manager.getVideoState('test')?.isReady, true);
        });
      });
      
      group('Error Handling', () {
        test('should handle invalid video IDs gracefully', () {
          // ACT & ASSERT: Should not throw
          expect(() => manager.getVideoState('nonexistent'), returnsNormally);
          expect(manager.getVideoState('nonexistent'), isNull);
          expect(manager.getController('nonexistent'), isNull);
        });
        
        test('should implement circuit breaker for failed videos', () async {
          // ARRANGE: Video that always fails
          final event = MockData.createFailingVideoEvent();
          await manager.addVideoEvent(event);
          
          // ACT: Try to preload multiple times
          await manager.preloadVideo(event.id);
          await manager.preloadVideo(event.id);
          await manager.preloadVideo(event.id);
          
          // ASSERT: Should eventually mark as permanently failed
          final state = manager.getVideoState(event.id);
          expect(state?.loadingState, VideoLoadingState.permanentlyFailed);
          expect(state?.canRetry, false);
        });
      });
      
      group('Performance', () {
        test('should handle large video lists efficiently', () async {
          // ARRANGE & ACT: Add many videos and measure time
          final stopwatch = Stopwatch()..start();
          
          for (int i = 0; i < 100; i++) {
            final event = MockData.createVideoEvent(id: 'video$i');
            await manager.addVideoEvent(event);
          }
          
          stopwatch.stop();
          
          // ASSERT: Should be reasonably fast
          expect(stopwatch.elapsedMilliseconds, lessThan(1000)); // <1 second
          expect(manager.videos.length, lessThanOrEqualTo(100));
        });
      });
    });
  }
  ```

- [ ] **Run interface tests**
  ```bash
  flutter test test/unit/services/video_manager_interface_test.dart
  ```

**✅ Done Criteria**:
- [ ] Interface fully defined with documentation
- [ ] Contract tests written and failing appropriately
- [ ] Error handling specified
- [ ] Performance requirements defined
- [ ] Ready for implementation

---

### 🔥 TASK 2.3: Enhanced Mock VideoManager (Day 3)

**Duration**: 4-6 hours  
**Prerequisites**: Task 2.2 complete  
**Goal**: Create sophisticated mock that passes interface tests

#### Specific Steps:

- [ ] **Create enhanced MockVideoManager**
  ```dart
  // test/mocks/mock_video_manager.dart
  import 'dart:async';
  import 'package:flutter/foundation.dart';
  import 'package:nostrvine_app/services/video_manager_interface.dart';
  import 'package:nostrvine_app/models/video_event.dart';
  import 'package:nostrvine_app/models/video_state.dart';
  import 'package:video_player/video_player.dart';
  import '../helpers/mock_data.dart';
  import 'mock_video_player_controller.dart';
  
  class MockVideoManager implements IVideoManager {
    final VideoManagerConfig _config;
    final Map<String, VideoState> _videoStates = {};
    final List<String> _orderedVideoIds = []; // Newest first
    final StreamController<void> _stateController = StreamController.broadcast();
    
    MockVideoManager({VideoManagerConfig? config}) 
        : _config = config ?? const VideoManagerConfig();
    
    @override
    List<VideoEvent> get videos => _orderedVideoIds
        .map((id) => _videoStates[id])
        .where((state) => state != null && !state.hasFailed)
        .map((state) => state!.event)
        .toList();
    
    @override
    List<VideoEvent> get readyVideos => _videoStates.values
        .where((state) => state.isReady)
        .map((state) => state.event)
        .toList();
    
    @override
    VideoState? getVideoState(String videoId) => _videoStates[videoId];
    
    @override
    VideoPlayerController? getController(String videoId) {
      final state = _videoStates[videoId];
      return state?.isReady == true ? state!.controller : null;
    }
    
    @override
    Future<void> addVideoEvent(VideoEvent event) async {
      // Prevent duplicates
      if (_videoStates.containsKey(event.id)) {
        return;
      }
      
      // Create initial state
      _videoStates[event.id] = VideoState.initial(event);
      _orderedVideoIds.insert(0, event.id); // Newest first
      
      // Handle GIFs immediately (they don't need preloading)
      if (event.isGif) {
        _videoStates[event.id] = _videoStates[event.id]!.toReady(
          MockVideoPlayerController(), // GIFs get mock controller immediately
        );
      }
      
      // Enforce memory limits
      _enforceMemoryLimits();
      
      _notifyStateChange();
    }
    
    @override
    Future<void> preloadVideo(String videoId) async {
      final state = _videoStates[videoId];
      if (state == null) return;
      
      // Skip if already loading/ready/permanently failed
      if (state.isLoading || state.isReady || 
          state.loadingState == VideoLoadingState.permanentlyFailed) {
        return;
      }
      
      // Update to loading
      _videoStates[videoId] = state.toLoading();
      _notifyStateChange();
      
      try {
        // Simulate loading delay
        await Future.delayed(const Duration(milliseconds: 100));
        
        // Check if this is a failing video
        if (state.event.videoUrl?.contains('invalid-url') == true) {
          throw Exception('Mock network error');
        }
        
        // Create mock controller and mark as ready
        final controller = MockVideoPlayerController();
        _videoStates[videoId] = state.toReady(controller);
        
      } catch (e) {
        // Handle failure
        _videoStates[videoId] = state.toFailed(e.toString());
      }
      
      _notifyStateChange();
    }
    
    @override
    void preloadAroundIndex(int currentIndex) {
      // Preload current + next N videos
      for (int i = currentIndex; 
           i <= currentIndex + _config.preloadAhead && i < _orderedVideoIds.length; 
           i++) {
        final videoId = _orderedVideoIds[i];
        preloadVideo(videoId);
      }
    }
    
    @override
    void disposeVideo(String videoId) {
      final state = _videoStates[videoId];
      if (state != null) {
        // Dispose controller if it exists
        state.controller?.dispose();
        
        // Update to disposed state
        _videoStates[videoId] = state.toDisposed();
        _notifyStateChange();
      }
    }
    
    @override
    Map<String, dynamic> getDebugInfo() {
      final totalVideos = _videoStates.length;
      final readyCount = _videoStates.values.where((s) => s.isReady).length;
      final loadingCount = _videoStates.values.where((s) => s.isLoading).length;
      final failedCount = _videoStates.values.where((s) => s.hasFailed).length;
      final controllerCount = _videoStates.values
          .where((s) => s.controller != null).length;
      
      return {
        'totalVideos': totalVideos,
        'readyVideos': readyCount,
        'loadingVideos': loadingCount,
        'failedVideos': failedCount,
        'controllers': controllerCount,
        'estimatedMemoryMB': controllerCount * 30,
        'maxVideos': _config.maxVideos,
        'preloadAhead': _config.preloadAhead,
      };
    }
    
    @override
    Stream<void> get stateChanges => _stateController.stream;
    
    @override
    void dispose() {
      // Dispose all controllers
      for (final state in _videoStates.values) {
        state.controller?.dispose();
      }
      
      _videoStates.clear();
      _orderedVideoIds.clear();
      _stateController.close();
    }
    
    /// Enforce memory limits by removing old videos
    void _enforceMemoryLimits() {
      if (_videoStates.length <= _config.maxVideos) return;
      
      final videosToRemove = _orderedVideoIds.skip(_config.maxVideos).toList();
      
      for (final videoId in videosToRemove) {
        final state = _videoStates.remove(videoId);
        state?.controller?.dispose();
        _orderedVideoIds.remove(videoId);
      }
    }
    
    void _notifyStateChange() {
      if (!_stateController.isClosed) {
        _stateController.add(null);
      }
    }
    
    // Helper methods for testing
    void addMockVideos(List<VideoEvent> videos) {
      for (final video in videos) {
        addVideoEvent(video);
      }
    }
    
    void simulateVideoLoad(String videoId, {bool success = true}) {
      final state = _videoStates[videoId];
      if (state != null) {
        if (success) {
          _videoStates[videoId] = state.toReady(MockVideoPlayerController());
        } else {
          _videoStates[videoId] = state.toFailed('Mock load failure');
        }
        _notifyStateChange();
      }
    }
    
    void simulateMemoryPressure() {
      // Force cleanup by setting low limit temporarily
      final originalLimit = _config.maxVideos;
      // Can't modify const config, so implement differently
      // Remove half the videos
      final toRemove = _orderedVideoIds.skip(_orderedVideoIds.length ~/ 2).toList();
      for (final videoId in toRemove) {
        disposeVideo(videoId);
        _videoStates.remove(videoId);
        _orderedVideoIds.remove(videoId);
      }
      _notifyStateChange();
    }
  }
  ```

- [ ] **Create MockVideoPlayerController**
  ```dart
  // test/mocks/mock_video_player_controller.dart
  import 'package:video_player/video_player.dart';
  import 'package:flutter/services.dart';
  
  class MockVideoPlayerController extends VideoPlayerController.network {
    static const String _mockUrl = 'https://mock-video-url.com/video.mp4';
    
    MockVideoPlayerController() : super(_mockUrl);
    
    @override
    Future<void> initialize() async {
      // Mock successful initialization
      value = value.copyWith(
        isInitialized: true,
        duration: const Duration(seconds: 30),
        size: const Size(640, 480),
      );
    }
    
    @override
    Future<void> play() async {
      value = value.copyWith(isPlaying: true);
    }
    
    @override
    Future<void> pause() async {
      value = value.copyWith(isPlaying: false);
    }
    
    @override
    Future<void> setLooping(bool looping) async {
      value = value.copyWith(isLooping: looping);
    }
    
    @override
    Future<void> dispose() async {
      // Mock disposal
      super.dispose();
    }
  }
  ```

- [ ] **Run tests with enhanced mock**
  ```bash
  flutter test test/unit/services/video_manager_interface_test.dart
  ```

- [ ] **Verify all interface tests pass**

**✅ Done Criteria**:
- [ ] Enhanced mock passes all interface tests
- [ ] Mock properly simulates real behavior
- [ ] Test utilities work with mock
- [ ] Performance characteristics realistic
- [ ] Ready for real implementation

---

## ⏰ TIMELINE CONTINUATION

This covers the first 3 days of Week 2. The remaining tasks would follow the same pattern:

- **Day 4**: Video Event Processing implementation
- **Day 5**: Error handling and validation

Each task would follow the same TDD pattern:
1. Write comprehensive tests
2. Implement minimal code to pass tests
3. Refactor and improve
4. Add more tests for edge cases
5. Verify coverage targets

The key is to **never proceed with failing tests** and always **write tests first** before implementation.

**✅ Week 2 Success Criteria**:
- [ ] All core models implemented and tested
- [ ] 95%+ test coverage on new code
- [ ] Zero failing tests
- [ ] Performance benchmarks met
- [ ] Ready for VideoManager implementation in Week 3