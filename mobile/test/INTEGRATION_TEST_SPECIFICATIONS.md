# Integration Test Specifications for Video System Rebuild

## ✅ TDD Red Phase Complete - Integration Tests

**Status**: All integration tests written and properly failing as expected in TDD methodology.

## 📋 Integration Test Coverage Summary

### 1. Complete Video Flow Tests (`test/integration/complete_video_flow_test.dart`)
**Purpose**: Test the entire pipeline from Nostr events to UI display

**Key Scenarios Tested**:
- **Nostr Event Processing**: VideoEvent creation from NIP-71 events
- **VideoManager Integration**: Event processing through single source of truth
- **UI Display Pipeline**: Feed rendering and video item display
- **User Interaction Flow**: Scrolling, video activation, pause/resume
- **Error Handling**: Invalid events, loading failures, network interruptions
- **Data Consistency**: Video ordering, duplicate prevention throughout pipeline

**Critical Flow Requirements**:
```
Nostr Event → VideoEvent.fromNostrEvent() → VideoManager.addVideoEvent() → UI Update
User Scroll → VideoManager.preloadAroundIndex() → Controller Management → Video Ready
```

### 2. Performance Tests (`test/integration/performance_test.dart`)
**Purpose**: Verify system performance under load and stress conditions

**Key Performance Requirements**:
- **Memory Usage**: <500MB with 100+ videos loaded
- **Controller Lifecycle**: Max 15 active controllers at any time
- **Scrolling Performance**: 60fps during smooth scrolling
- **Concurrent Loading**: Efficient parallel video preloading
- **Network Adaptation**: WiFi vs cellular preloading strategies
- **Stress Testing**: Graceful handling of extreme loads (500+ videos)

**Performance Benchmarks**:
```
- Loading 100 videos: <10 seconds
- Rapid scrolling 20 positions: <5 seconds  
- Concurrent preloading 10 videos: <15 seconds
- Frame timing: >90% frames under 16.67ms (60fps)
```

### 3. Network Conditions Tests (`test/integration/network_conditions_test.dart`)
**Purpose**: Test system behavior under various network scenarios

**Network Scenarios Covered**:
- **Offline/Online Transitions**: Graceful degradation and recovery
- **Network Quality Adaptation**: WiFi vs cellular vs slow connections
- **Error Handling**: DNS failures, timeouts, HTTP errors
- **Retry Logic**: Exponential backoff for failed requests
- **Nostr Relay Management**: Disconnection/reconnection handling
- **CDN Failures**: Video hosting service unavailability

**Network Requirements**:
```
- Offline state: Previously loaded videos remain playable
- Network recovery: Automatic reconnection within 5 seconds
- Slow connections: Graceful loading with progress indication
- Relay failures: Continue working with remaining relays
```

## 🎯 Integration Test Success Criteria

### End-to-End Flow Requirements
- ✅ **Complete Pipeline**: Nostr event → VideoState → UI display works flawlessly
- ✅ **User Interactions**: Scrolling, video activation, preloading work smoothly
- ✅ **Error Recovery**: System handles failures without crashes
- ✅ **Data Consistency**: Single source of truth prevents dual list problems

### Performance Requirements  
- ✅ **Memory Efficiency**: <500MB usage regardless of video count
- ✅ **Responsive UI**: Smooth 60fps scrolling and interactions
- ✅ **Fast Loading**: Aggressive preloading for instant playback
- ✅ **Stress Resilience**: Graceful handling of extreme loads

### Network Resilience Requirements
- ✅ **Offline Support**: App remains functional when offline
- ✅ **Adaptive Loading**: Smart preloading based on connection type
- ✅ **Error Recovery**: Robust handling of network failures
- ✅ **Relay Management**: Seamless Nostr relay switching

## 🔧 Implementation Guidance

### Required Service Implementations
```dart
// Core services needed for integration tests to pass
- VideoManagerService (single source of truth)
- NetworkService (connection monitoring)
- NostrService (relay management)  
- VideoEventService (NIP-71 event processing)
```

### UI Components Required
```dart
// UI components needed for integration tests to pass
- FeedScreenV2 (main video feed)
- VideoFeedItemV2 (individual video display)
- NetworkStatusIndicator (connection state)
- ErrorBoundaryWidget (graceful error handling)
```

### Key Integration Points
1. **Nostr Event → VideoEvent**: Robust parsing of NIP-71 events
2. **VideoManager ↔ UI**: Reactive state management and updates
3. **Network ↔ VideoManager**: Adaptive behavior based on connectivity
4. **Memory Management**: Automatic controller disposal and cleanup

## 🚨 Critical Requirements from Integration Tests

### Memory Management (From performance_test.dart)
- **Hard Limit**: Never exceed 500MB memory usage
- **Controller Limit**: Max 15 active VideoPlayerControllers
- **Cleanup Strategy**: Dispose videos >3 positions from current
- **Memory Pressure**: Aggressive cleanup when system memory low

### Error Handling (From all integration tests)
- **Network Failures**: Graceful degradation, no crashes
- **Invalid Data**: Robust parsing with proper error states
- **Race Conditions**: Thread-safe operations and state management
- **Recovery**: Automatic retry with exponential backoff

### Performance (From performance_test.dart)
- **Loading Time**: <10s for 100 videos, <15s for concurrent preloading
- **UI Responsiveness**: <100ms response to user interactions
- **Scrolling**: 60fps smooth scrolling through large feeds
- **Memory Stability**: Bounded memory usage under all conditions

## 📝 Notes for Implementation Teams

### Test Execution Strategy
- **Unit Tests First**: Implement core classes to pass unit tests
- **Integration Tests Second**: Wire components together for end-to-end flows
- **Performance Tests Last**: Optimize after functionality is complete

### Mock Services for Testing
- Create `MockNostrService` for controlled event generation
- Implement `MockNetworkService` for simulating network conditions  
- Build `TestVideoEventFactory` for generating test scenarios

### Continuous Integration
- All integration tests must pass before merging
- Performance benchmarks must be met
- Memory usage monitoring in CI pipeline

---

**VidTesterPro** - Integration Test Specification Complete  
**Issue**: #83 Integration Tests  
**Phase**: Red ✅ | Green 🔄 | Refactor ⏳

**Dependencies**: Core Behavior Tests (#82) ✅  
**Next**: UI Tests (#84) and Implementation Phase (Week 2+)