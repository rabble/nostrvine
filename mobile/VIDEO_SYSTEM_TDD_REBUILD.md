# NostrVine Video System - Complete TDD Rebuild Plan

## 🎯 PHILOSOPHY: Test-Driven Complete Rebuild

**Approach**: Stop trying to fix a fundamentally broken system. Rebuild it correctly with TDD from scratch.

**Strategy**: 
1. **Write comprehensive tests** for the behavior we want
2. **Build the new system** to pass those tests 
3. **Swap out the old system** once the new one works perfectly
4. **Delete the old code** completely

---

## 📋 PHASE 1: TEST FOUNDATION (Week 1)

### 🎯 GOAL: Define and test the behavior we want

### Task 1.1: Define Video System Requirements (Day 1)
- [ ] **Create test specification document**
  - [ ] Video loading behavior requirements
  - [ ] Memory management requirements  
  - [ ] Error handling requirements
  - [ ] Performance requirements
- [ ] **Create mock data for testing**
  - [ ] Mock Nostr events (NIP-71 video events)
  - [ ] Mock video URLs (working and broken)
  - [ ] Mock network conditions
- [ ] **Set up testing framework**
  - [ ] Configure flutter_test
  - [ ] Add mockito for mocking
  - [ ] Add integration_test for E2E testing
  - [ ] Add memory profiling tools

### Task 1.2: Write Core Behavior Tests (Day 2-3)
- [ ] **Test: Video State Management**
  ```dart
  testWidgets('VideoState manages lifecycle correctly', (tester) async {
    // Test: notLoaded -> loading -> ready -> disposed
    // Test: Error states and recovery
    // Test: Memory cleanup
  });
  ```
- [ ] **Test: Single Source of Truth**
  ```dart
  testWidgets('Video list is always consistent', (tester) async {
    // Test: No index mismatches
    // Test: No dual list problems
    // Test: Ordered video list
  });
  ```
- [ ] **Test: Memory Management**
  ```dart
  testWidgets('Memory usage stays under limits', (tester) async {
    // Test: Controller disposal
    // Test: Maximum video count
    // Test: Cleanup when memory pressure
  });
  ```
- [ ] **Test: Error Handling**
  ```dart
  testWidgets('Failed videos are handled gracefully', (tester) async {
    // Test: Network failures
    // Test: Invalid URLs
    // Test: Circuit breaker behavior
  });
  ```

### Task 1.3: Write Integration Tests (Day 4)
- [ ] **Test: Complete Video Flow**
  ```dart
  testWidgets('Complete video flow works end-to-end', (tester) async {
    // Test: Nostr event -> VideoState -> UI display
    // Test: User scrolling triggers preloading
    // Test: Video plays when active
  });
  ```
- [ ] **Test: Performance Under Load**
  ```dart
  testWidgets('System handles rapid scrolling', (tester) async {
    // Test: Load 100+ videos
    // Test: Rapid scroll through all
    // Test: Memory stays under limit
  });
  ```
- [ ] **Test: Network Conditions**
  ```dart
  testWidgets('System handles network issues', (tester) async {
    // Test: Offline/online transitions
    // Test: Slow network conditions
    // Test: Network failures during loading
  });
  ```

### Task 1.4: Write UI Tests (Day 5)
- [ ] **Test: VideoFeedItem Behavior**
  ```dart
  testWidgets('VideoFeedItem displays correct states', (tester) async {
    // Test: Loading spinner shown
    // Test: Video player shown when ready
    // Test: Error widget shown on failure
    // Test: Retry functionality works
  });
  ```
- [ ] **Test: FeedScreen Behavior**
  ```dart
  testWidgets('FeedScreen handles video list correctly', (tester) async {
    // Test: PageView builds correctly
    // Test: Index bounds checking
    // Test: Preloading triggered correctly
  });
  ```

### ✅ Week 1 Success Criteria:
- [ ] All tests written and failing (no implementation yet)
- [ ] Test coverage plan for 90%+ of new code
- [ ] Mock data and testing infrastructure ready
- [ ] Performance benchmarks defined

---

## 📋 PHASE 2: CORE MODELS (Week 2)

### 🎯 GOAL: Build rock-solid foundation models that pass tests

### Task 2.1: VideoState Model (Day 1)
- [ ] **Create VideoState enum and class**
  ```dart
  // lib/models/video_state.dart
  enum VideoLoadingState {
    notLoaded, loading, ready, failed, permanentlyFailed, disposed
  }
  ```
- [ ] **Run tests and make them pass**
  - [ ] `test/models/video_state_test.dart`
  - [ ] Test state transitions
  - [ ] Test immutability
  - [ ] Test validation logic
- [ ] **Add comprehensive documentation**
- [ ] **Verify test coverage >95%**

### Task 2.2: VideoManager Interface (Day 2)
- [ ] **Define VideoManager abstract interface**
  ```dart
  // lib/services/video_manager_interface.dart
  abstract class IVideoManager {
    List<VideoEvent> get videos;
    VideoState? getVideoState(String videoId);
    Future<void> addVideoEvent(VideoEvent event);
    Future<void> preloadVideo(String videoId);
    void dispose();
  }
  ```
- [ ] **Write interface contract tests**
  - [ ] Test expected behaviors
  - [ ] Test error conditions
  - [ ] Test edge cases
- [ ] **Document interface contracts**

### Task 2.3: Mock VideoManager (Day 3)
- [ ] **Create MockVideoManager for testing**
  ```dart
  // test/mocks/mock_video_manager.dart
  class MockVideoManager implements IVideoManager {
    // Fully controllable mock for testing
  }
  ```
- [ ] **Verify all interface tests pass**
- [ ] **Create test scenarios**
  - [ ] Success scenarios
  - [ ] Failure scenarios  
  - [ ] Edge cases

### Task 2.4: Video Event Processing (Day 4-5)
- [ ] **Create VideoEventProcessor**
  ```dart
  // lib/services/video_event_processor.dart
  class VideoEventProcessor {
    static VideoEvent fromNostrEvent(Event event);
    static bool isValidVideoEvent(Event event);
  }
  ```
- [ ] **Write comprehensive tests**
  - [ ] Valid Nostr events
  - [ ] Invalid events
  - [ ] Edge cases and malformed data
- [ ] **Make tests pass**
- [ ] **Verify test coverage >95%**

### ✅ Week 2 Success Criteria:
- [ ] All core models implemented and tested
- [ ] 95%+ test coverage on new code
- [ ] Zero failing tests
- [ ] Mock implementations working for UI testing

---

## 📋 PHASE 3: VIDEO MANAGER IMPLEMENTATION (Week 3)

### 🎯 GOAL: Build the single-source-of-truth VideoManager

### Task 3.1: Core VideoManager Service (Day 1-2)
- [ ] **Implement VideoManagerService**
  ```dart
  // lib/services/video_manager_service.dart
  class VideoManagerService implements IVideoManager {
    final Map<String, VideoState> _videos = {};
    final List<String> _orderedVideoIds = [];
    // Single source of truth implementation
  }
  ```
- [ ] **Make core tests pass**
  - [ ] Video addition
  - [ ] State management
  - [ ] Video retrieval
- [ ] **Add logging and debugging**
- [ ] **Test memory behavior**

### Task 3.2: Video Preloading (Day 3)
- [ ] **Implement preloading logic**
  ```dart
  Future<void> preloadVideo(String videoId) async {
    // State: notLoaded -> loading -> ready/failed
  }
  ```
- [ ] **Make preloading tests pass**
  - [ ] Successful preloading
  - [ ] Network failure handling
  - [ ] Duplicate prevention
- [ ] **Add circuit breaker logic**
- [ ] **Test error recovery**

### Task 3.3: Memory Management (Day 4)
- [ ] **Implement memory limits**
  ```dart
  void _enforceMemoryLimits() {
    // Cleanup old videos
    // Dispose unused controllers
  }
  ```
- [ ] **Make memory tests pass**
  - [ ] Controller disposal
  - [ ] Video count limits
  - [ ] Memory pressure handling
- [ ] **Add memory monitoring**
- [ ] **Test cleanup behavior**

### Task 3.4: Error Handling & Recovery (Day 5)
- [ ] **Implement comprehensive error handling**
  ```dart
  void _handleVideoError(String videoId, Exception error) {
    // Circuit breaker logic
    // Retry logic
    // Permanent failure marking
  }
  ```
- [ ] **Make error tests pass**
  - [ ] Network errors
  - [ ] Invalid URLs
  - [ ] Recovery scenarios
- [ ] **Add error reporting**
- [ ] **Test edge cases**

### ✅ Week 3 Success Criteria:
- [ ] VideoManagerService fully implemented
- [ ] All core behavior tests passing
- [ ] Memory management working correctly
- [ ] Error handling comprehensive
- [ ] 95%+ test coverage maintained

---

## 📋 PHASE 4: UI INTEGRATION (Week 4)

### 🎯 GOAL: Connect new VideoManager to UI with TDD

### Task 4.1: VideoFeedProvider Rebuild (Day 1-2)
- [ ] **Create new VideoFeedProvider**
  ```dart
  // lib/providers/video_feed_provider_v2.dart
  class VideoFeedProviderV2 extends ChangeNotifier {
    final IVideoManager _videoManager;
    // Simple wrapper around VideoManager
  }
  ```
- [ ] **Write provider tests**
  - [ ] State management
  - [ ] Notification behavior
  - [ ] Video list consistency
- [ ] **Make provider tests pass**
- [ ] **Test integration with VideoManager**

### Task 4.2: VideoFeedItem Rebuild (Day 3)
- [ ] **Create new VideoFeedItem**
  ```dart
  // lib/widgets/video_feed_item_v2.dart
  class VideoFeedItemV2 extends StatelessWidget {
    // Simple state-based rendering
  }
  ```
- [ ] **Write widget tests**
  - [ ] Loading state display
  - [ ] Ready state display
  - [ ] Error state display
  - [ ] State transitions
- [ ] **Make widget tests pass**
- [ ] **Test with mock VideoManager**

### Task 4.3: FeedScreen Integration (Day 4)
- [ ] **Create new FeedScreen**
  ```dart
  // lib/screens/feed_screen_v2.dart
  class FeedScreenV2 extends StatefulWidget {
    // Clean PageView implementation
  }
  ```
- [ ] **Write screen tests**
  - [ ] PageView behavior
  - [ ] Index handling
  - [ ] Preloading triggers
  - [ ] Error boundaries
- [ ] **Make screen tests pass**
- [ ] **Test full integration**

### Task 4.4: Integration Testing (Day 5)
- [ ] **Write full-stack integration tests**
  ```dart
  // integration_test/video_system_test.dart
  testWidgets('Complete video system integration', (tester) async {
    // Test: Nostr events -> UI display
    // Test: User interactions
    // Test: Error scenarios
  });
  ```
- [ ] **Test performance scenarios**
  - [ ] Load 100+ videos
  - [ ] Rapid scrolling
  - [ ] Memory usage
- [ ] **Test error scenarios**
  - [ ] Network failures
  - [ ] Invalid data
  - [ ] Recovery behavior

### ✅ Week 4 Success Criteria:
- [ ] New UI components fully implemented
- [ ] All integration tests passing
- [ ] Performance tests meeting targets
- [ ] Error handling working in UI
- [ ] Ready for system swap

---

## 📋 PHASE 5: SYSTEM SWAP (Week 5)

### 🎯 GOAL: Replace old system with new system

### Task 5.1: Parallel Testing (Day 1)
- [ ] **Run both systems in parallel**
  ```dart
  // Compare outputs for consistency
  final oldVideos = oldVideoCache.readyToPlayQueue;
  final newVideos = newVideoManager.videos;
  _compareVideoLists(oldVideos, newVideos);
  ```
- [ ] **Compare behavior**
  - [ ] Video lists match
  - [ ] Performance comparison
  - [ ] Memory usage comparison
- [ ] **Fix any discrepancies**
- [ ] **Validate new system superiority**

### Task 5.2: Feature Flag Deployment (Day 2)
- [ ] **Add feature flag system**
  ```dart
  // lib/config/feature_flags.dart
  class FeatureFlags {
    static bool get useNewVideoSystem => _newVideoSystemEnabled;
  }
  ```
- [ ] **Implement gradual rollout**
  - [ ] 10% users get new system
  - [ ] Monitor crash rates
  - [ ] Monitor performance
- [ ] **Add monitoring/analytics**
- [ ] **Prepare rollback plan**

### Task 5.3: Full Deployment (Day 3)
- [ ] **Deploy to 100% users**
- [ ] **Monitor system health**
  - [ ] Crash rates
  - [ ] Memory usage
  - [ ] Video load success rates
  - [ ] User engagement
- [ ] **Fix any issues quickly**
- [ ] **Validate success metrics**

### Task 5.4: Old System Removal (Day 4-5)
- [ ] **Remove old services**
  - [ ] Delete `VideoEventService`
  - [ ] Delete `VideoCacheService`
  - [ ] Delete old `VideoFeedProvider`
- [ ] **Clean up imports**
- [ ] **Remove feature flags**
- [ ] **Update documentation**
- [ ] **Clean up tests**

### ✅ Week 5 Success Criteria:
- [ ] New system deployed to 100% users
- [ ] Old system completely removed
- [ ] All success metrics met
- [ ] Zero regressions detected
- [ ] Code base simplified significantly

---

## 📋 DETAILED TASK CHECKLISTS

### 🧪 TDD Workflow for Each Task

**For EVERY implementation task:**

1. **Write the test first** ✅
   - [ ] Test should fail initially
   - [ ] Test should be specific and focused
   - [ ] Test should cover edge cases

2. **Write minimal implementation** ✅
   - [ ] Just enough to make test pass
   - [ ] Don't over-engineer
   - [ ] Keep it simple

3. **Refactor if needed** ✅
   - [ ] Clean up code
   - [ ] Add documentation
   - [ ] Verify test still passes

4. **Add more tests** ✅
   - [ ] Cover edge cases
   - [ ] Cover error conditions
   - [ ] Verify high coverage

### 📊 Success Metrics Dashboard

Track these metrics throughout the rebuild:

```dart
// Track during development
class VideoSystemMetrics {
  // Performance
  static int get averageVideoLoadTimeMs;
  static double get videoLoadSuccessRate; // Target: >95%
  static int get memoryUsageMB;          // Target: <500MB
  
  // Reliability  
  static int get crashesPerSession;      // Target: 0
  static int get indexMismatchBugs;      // Target: 0
  static int get raceConditions;         // Target: 0
  
  // Code Quality
  static double get testCoverage;        // Target: >90%
  static int get cyclomaticComplexity;   // Target: <10
  static int get linesOfCode;            // Target: 50% reduction
}
```

### 🚨 Risk Mitigation Plan

**If tests are failing:**
- [ ] Stop implementation
- [ ] Fix tests first
- [ ] Never proceed with failing tests

**If integration issues arise:**
- [ ] Roll back to last working state
- [ ] Fix integration
- [ ] Re-run full test suite

**If performance targets not met:**
- [ ] Profile and identify bottlenecks
- [ ] Optimize specific areas
- [ ] Re-test performance

### 📝 Documentation Requirements

**For each component built:**
- [ ] **API documentation** with examples
- [ ] **Architecture decision records** (ADRs)
- [ ] **Test documentation** explaining scenarios
- [ ] **Performance characteristics** documented
- [ ] **Error handling** behavior documented

---

## 🎯 FINAL SUCCESS CRITERIA

### Technical Metrics
- [ ] **Test Coverage**: >90% on all new code
- [ ] **Memory Usage**: <500MB peak (down from 3GB)
- [ ] **Video Load Success**: >95% (up from ~80%)
- [ ] **Index Mismatch Bugs**: 0 detected
- [ ] **Race Conditions**: 0 detected
- [ ] **Crash Rate**: <0.1%

### Code Quality Metrics
- [ ] **Lines of Code**: 50% reduction in video system
- [ ] **Cyclomatic Complexity**: <10 per method
- [ ] **Duplicate Code**: 0 detected
- [ ] **Technical Debt**: Eliminated in video system

### User Experience Metrics
- [ ] **Video Loading**: <2 seconds average
- [ ] **Smooth Scrolling**: 60fps maintained
- [ ] **App Stability**: Zero video-related crashes
- [ ] **Memory Efficiency**: No memory warnings

This TDD approach ensures we build exactly what we need, with confidence that it works correctly, and comprehensive test coverage to prevent regressions.