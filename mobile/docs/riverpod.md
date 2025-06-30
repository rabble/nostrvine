# OpenVine Riverpod Migration Plan

## Executive Summary

This document outlines a comprehensive migration strategy from Provider-based state management to Riverpod 2.0 for the OpenVine Flutter application. The migration addresses critical architectural issues including manual state coordination, lack of reactive updates, and complex subscription management.

### Current Problems
- Manual coordination via VideoEventBridge causing maintenance overhead
- Following list changes don't automatically trigger video feed updates
- Complex subscription lifecycle management with timers and callbacks
- State synchronization issues across multiple services (Social, VideoEvent, VideoManager)

### Target Benefits
- Automatic reactive state updates through dependency graphs
- Eliminated manual coordination and kludgy solutions
- Simplified subscription and resource management
- Improved developer experience and maintainability

---

## Migration Architecture Overview

```
Current Provider Architecture           Target Riverpod Architecture
==========================             ==========================

[VideoEventBridge]                     [Reactive Provider Graph]
    |                                      |
    |-- Coordinates manually          Auto-dependency tracking
    |-- Timer-based updates           Reactive updates
    |-- Complex lifecycle             Auto-disposal
    |                                      |
[Multiple Services]                    [StateNotifier Providers]
    |-- SocialService                     |-- SocialDataProvider
    |-- VideoEventService                |-- VideoFeedProvider  
    |-- VideoManager                     |-- VideoManagerProvider
    |-- UserProfileService               |-- UserProfileProvider
```

---

## Phase 1: Foundation & Training

**Duration: 2 weeks**

### Week 1: Environment Setup

#### Dependencies Update
```yaml
# pubspec.yaml additions
dependencies:
  flutter_riverpod: ^2.5.1
  riverpod_annotation: ^2.3.5

dev_dependencies:
  riverpod_generator: ^2.4.0
  build_runner: ^2.4.9
  custom_lint: ^0.6.4
  riverpod_lint: ^2.3.10
```

#### Build Configuration
```yaml
# build.yaml
targets:
  $default:
    builders:
      riverpod_generator:
        options:
          # Generate providers in .g.dart files
          generate_riverpod_annotation: true
```

#### Project Structure Setup
```
lib/
├── providers/
│   ├── auth_providers.dart
│   ├── social_providers.dart
│   ├── video_providers.dart
│   └── user_providers.dart
├── state/
│   ├── social_state.dart
│   ├── video_state.dart
│   └── auth_state.dart
└── services/ (existing)
```

### Week 2: Proof of Concept & Training

#### Simple Service Migration Example
```dart
// Before: Provider-based AnalyticsService
class AnalyticsService extends ChangeNotifier {
  // Manual state management
}

// After: Riverpod provider
@riverpod
class Analytics extends _$Analytics {
  @override
  AnalyticsState build() {
    return const AnalyticsState.initial();
  }
  
  Future<void> trackEvent(String event) async {
    // Automatic UI updates
    state = state.copyWith(lastEvent: event);
  }
}
```

#### Training Materials
- Riverpod fundamentals workshop (8 hours)
- Code generation patterns training
- Migration best practices guide
- Testing strategies for providers

---

## Phase 2: Core Migration

**Duration: 4 weeks**

### Week 3: Independent Services Migration

#### SocialService to StateNotifier
```dart
@riverpod
class SocialData extends _$SocialData {
  @override
  SocialState build() {
    return const SocialState(
      followingPubkeys: [],
      likedEvents: {},
      isLoading: false,
    );
  }

  Future<void> toggleFollow(String pubkey) async {
    state = state.copyWith(isLoading: true);
    
    try {
      if (state.followingPubkeys.contains(pubkey)) {
        await _unfollowUser(pubkey);
        state = state.copyWith(
          followingPubkeys: state.followingPubkeys.where((p) => p != pubkey).toList(),
        );
      } else {
        await _followUser(pubkey);
        state = state.copyWith(
          followingPubkeys: [...state.followingPubkeys, pubkey],
        );
      }
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }
}
```

#### UserProfileService Migration
```dart
@riverpod
class UserProfile extends _$UserProfile {
  @override
  Future<UserProfileModel?> build(String pubkey) async {
    // Automatic caching and dependency management
    return await ref.watch(userProfileServiceProvider).getProfile(pubkey);
  }
}

// Family provider for multiple user profiles
@riverpod
class UserProfiles extends _$UserProfiles {
  @override
  Map<String, UserProfileModel> build() => {};
  
  void cacheProfile(String pubkey, UserProfileModel profile) {
    state = {...state, pubkey: profile};
  }
}
```

### Week 4: VideoEventBridge Analysis & Design

#### Current Dependencies Mapping
```
VideoEventBridge Dependencies:
├── VideoEventService (Nostr events)
├── VideoManager (UI state)  
├── SocialService (following list)
├── UserProfileService (profile data)
└── CurationService (content filtering)

Target Provider Dependencies:
├── videoEventsProvider (replaces VideoEventService)
├── videoFeedProvider (reactive video list)
├── socialDataProvider (following state)
└── filteredVideosProvider (context-aware filtering)
```

#### New Provider Architecture Design
```dart
// Core video feed provider - replaces VideoEventBridge
@riverpod
class VideoFeed extends _$VideoFeed {
  @override
  Future<List<VideoEvent>> build() async {
    final followingList = ref.watch(socialDataProvider.select((s) => s.followingPubkeys));
    final feedMode = ref.watch(feedModeProvider);
    final videoService = ref.watch(videoEventServiceProvider);
    
    return switch (feedMode) {
      FeedMode.following => await videoService.getVideosFromAuthors(followingList),
      FeedMode.curated => await videoService.getCuratedVideos(),
      FeedMode.discovery => await videoService.getDiscoveryVideos(),
    };
  }
}

// Context-aware filtered videos
@riverpod
class FilteredVideos extends _$FilteredVideos {
  @override
  List<VideoEvent> build(FeedContext context, String? contextValue) {
    final allVideos = ref.watch(videoFeedProvider).asData?.value ?? [];
    final blocklist = ref.watch(contentBlocklistProvider);
    
    // Apply context filtering
    var filtered = switch (context) {
      FeedContext.general => allVideos,
      FeedContext.hashtag => allVideos.where((v) => v.hashtags.contains(contextValue)),
      FeedContext.userProfile => allVideos.where((v) => v.pubkey == contextValue),
      FeedContext.editorsPicks => allVideos.where((v) => v.isEditorsPick),
    };
    
    // Apply blocklist filtering
    return filtered.where((v) => !blocklist.isBlocked(v.pubkey)).toList();
  }
}
```

### Weeks 5-6: VideoEventBridge Replacement Implementation

#### Hybrid Adapter for Gradual Migration
```dart
class VideoEventBridgeAdapter {
  final ProviderContainer _container;
  final VideoEventBridge? _legacyBridge;
  final bool _useRiverpod;
  
  VideoEventBridgeAdapter(this._container, {bool useRiverpod = false}) 
    : _useRiverpod = useRiverpod,
      _legacyBridge = useRiverpod ? null : VideoEventBridge();
  
  Stream<List<VideoEvent>> get videoStream {
    if (_useRiverpod) {
      return _container.read(videoFeedProvider.stream);
    } else {
      return _legacyBridge!.videoStream;
    }
  }
}
```

#### Feature Flag Implementation
```dart
@riverpod
class FeatureFlags extends _$FeatureFlags {
  @override
  FeatureFlagsState build() {
    return const FeatureFlagsState(
      useRiverpodVideoFeed: false, // Start disabled
      useRiverpodSocialService: false,
    );
  }
  
  void toggleRiverpodVideoFeed(bool enabled) {
    state = state.copyWith(useRiverpodVideoFeed: enabled);
  }
}
```

---

## Phase 3: Integration & Optimization

**Duration: 2 weeks**

### Week 7: VideoManager Integration

#### VideoManager Provider Migration
```dart
@riverpod
class VideoManager extends _$VideoManager {
  @override
  VideoManagerState build() {
    // Subscribe to video feed changes
    ref.listen(videoFeedProvider, (previous, next) {
      next.when(
        data: (videos) => _updateVideoList(videos),
        loading: () => _setLoading(true),
        error: (error, stack) => _handleError(error),
      );
    });
    
    return const VideoManagerState.initial();
  }
  
  void preloadAroundIndex(int index) {
    final videos = ref.read(videoFeedProvider).asData?.value ?? [];
    // Implement preloading logic with provider dependencies
  }
}
```

#### Legacy Provider Cleanup
```dart
// Remove these legacy providers:
// - VideoManagerProvider (replace with VideoManagerStateProvider)  
// - VideoFeedProvider (replace with reactive VideoFeedProvider)
// - Individual service providers (replace with StateNotifier providers)
```

### Week 8: Performance Optimization & Cleanup

#### Provider Optimization Patterns
```dart
// Use select() for granular updates
Consumer(
  builder: (context, ref, child) {
    final videoCount = ref.watch(videoFeedProvider.select((state) => 
      state.asData?.value.length ?? 0
    ));
    return Text('Videos: $videoCount');
  },
)

// Use family providers for parameterized state
@riverpod
class VideoState extends _$VideoState {
  @override
  VideoStateModel build(String videoId) {
    ref.keepAlive(); // Keep video state alive for better UX
    return VideoStateModel.initial(videoId);
  }
}

// Proper disposal with autoDispose
@riverpod
class TempVideoData extends _$TempVideoData {
  @override
  String build() {
    // Automatically disposed when no longer watched
    return '';
  }
}
```

#### Performance Monitoring Setup
```dart
class RiverpodPerformanceObserver extends ProviderObserver {
  @override
  void didUpdateProvider(
    ProviderBase provider,
    Object? previousValue,
    Object? newValue,
    ProviderContainer container,
  ) {
    Log.performance(
      'Provider ${provider.name} updated: ${previousValue} -> ${newValue}',
      name: 'RiverpodPerformance',
    );
  }
  
  @override
  void didDisposeProvider(ProviderBase provider, ProviderContainer container) {
    Log.performance('Provider ${provider.name} disposed', name: 'RiverpodPerformance');
  }
}
```

---

## Risk Management & Testing Strategy

### High-Risk Areas & Mitigation

#### 1. VideoEventBridge Replacement Risk
**Risk**: Breaking core video feed functionality during migration  
**Mitigation**:
- Feature flags for instant rollback
- Parallel running of old and new systems
- Comprehensive integration testing
- Gradual user rollout (10% -> 50% -> 100%)

#### 2. Performance Regression Risk  
**Risk**: Riverpod overhead causing UI slowdown  
**Mitigation**:
- Baseline performance measurements before migration
- Real-time performance monitoring during rollout
- Provider optimization (select(), autoDispose, keepAlive)
- Automated performance testing in CI/CD

#### 3. Team Adoption Risk
**Risk**: Learning curve impacting development velocity  
**Mitigation**:
- Comprehensive training program (40 hours)
- Pair programming during migration
- Code review guidelines for Riverpod patterns
- Internal documentation and examples

### Testing Strategy

#### Unit Testing Providers
```dart
// Provider testing example
void main() {
  group('SocialDataProvider', () {
    late ProviderContainer container;
    
    setUp(() {
      container = ProviderContainer(
        overrides: [
          socialServiceProvider.overrideWithValue(MockSocialService()),
        ],
      );
    });
    
    tearDown(() {
      container.dispose();
    });
    
    test('should update following list when toggleFollow is called', () async {
      final notifier = container.read(socialDataProvider.notifier);
      
      await notifier.toggleFollow('pubkey123');
      
      final state = container.read(socialDataProvider);
      expect(state.followingPubkeys, contains('pubkey123'));
    });
  });
}
```

#### Integration Testing
```dart
// Cross-provider dependency testing
testWidgets('video feed updates when following list changes', (tester) async {
  final container = ProviderContainer();
  
  await tester.pumpWidget(
    ProviderScope(
      parent: container,
      child: VideoFeedScreen(),
    ),
  );
  
  // Change following list
  container.read(socialDataProvider.notifier).toggleFollow('newUser');
  await tester.pump();
  
  // Verify video feed updates
  expect(find.byType(VideoWidget), findsWidgets);
});
```

### Performance Testing
- Memory usage monitoring (before/after migration)
- Widget rebuild frequency analysis  
- Provider dependency graph optimization
- Load testing with realistic data volumes

---

## Success Metrics & Validation

### Technical Success Criteria

#### Code Quality Metrics
- **Manual Coordination Elimination**: Complete removal of VideoEventBridge
- **State Synchronization**: 100% reactive updates for following list changes  
- **Subscription Management**: Automated provider lifecycle with no manual cleanup
- **Bug Reduction**: 50% reduction in state-related bugs

#### Performance Metrics  
- **Memory Usage**: No regression in peak memory consumption
- **UI Responsiveness**: Maintain <16ms frame times during state updates
- **App Launch Time**: No degradation in cold start performance
- **Video Feed Loading**: Maintain current loading speed benchmarks

### Developer Experience Metrics
- **Feature Delivery Velocity**: Measure sprint completion rates before/after
- **Code Review Time**: Reduced complexity should decrease review time
- **Bug Investigation Time**: Better state tracking should reduce debug time
- **New Developer Onboarding**: Faster understanding of state management

---

## Implementation Roadmap

### Immediate Actions (Week 1)
```
[ ] Team alignment meeting - present migration plan
[ ] Create dedicated migration branch: feature/riverpod-migration  
[ ] Update pubspec.yaml with Riverpod dependencies
[ ] Set up build_runner configuration
[ ] Create initial provider structure
[ ] Document migration RFC for team review
```

### Milestone Gates
```
Week 2: ✓ Proof of concept completed, team trained
Week 4: ✓ Independent services migrated, VideoEventBridge designed  
Week 6: ✓ VideoEventBridge replaced, feature flags operational
Week 8: ✓ Full migration complete, performance validated
```

### Rollback Procedures
```
Emergency Rollback (< 5 minutes):
1. Disable Riverpod feature flags via admin panel
2. Redeploy previous stable version
3. Monitor error rates and user metrics

Gradual Rollback (< 30 minutes):  
1. Reduce feature flag percentage to 0%
2. Validate legacy Provider system stability
3. Investigate and fix Riverpod issues
4. Re-enable when ready
```

---

## Long-term Benefits

### Architectural Improvements
- **Reactive State Management**: Automatic updates eliminate manual coordination
- **Simplified Dependencies**: Clear provider dependency graphs replace complex service interactions
- **Better Resource Management**: Automatic disposal prevents memory leaks
- **Enhanced Testability**: Provider overrides enable comprehensive testing

### Developer Experience
- **Reduced Complexity**: Eliminate VideoEventBridge coordination logic
- **Faster Development**: Reactive patterns reduce boilerplate code
- **Better Debugging**: Provider inspector tools improve state visibility  
- **Easier Onboarding**: Clearer state management patterns for new developers

### Scalability & Maintenance
- **Future-Proof Architecture**: Modern state management aligned with Flutter ecosystem
- **Performance Optimization**: Granular rebuilds and automatic optimizations
- **Code Maintainability**: Reduced coupling and clearer separation of concerns
- **Feature Development**: Easier to add new reactive features and integrations

---

## Conclusion

This migration plan provides a comprehensive, low-risk path from Provider to Riverpod 2.0 that directly addresses OpenVine's current state management challenges. The phased approach ensures system stability while delivering significant architectural improvements.

The elimination of manual coordination via VideoEventBridge, combined with automatic reactive updates and simplified resource management, will dramatically improve both developer experience and application maintainability.

**Next Steps**: Review this plan with the development team, get stakeholder approval, and begin Phase 1 implementation.