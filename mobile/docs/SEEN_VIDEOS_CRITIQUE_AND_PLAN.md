Status: Historical

> Historical note
> Preserved for context during the P1 documentation refresh. This file may reference deleted screens, older branding, or superseded implementation details. Start with docs/README.md and docs/archive/README.md for current guidance.

# SeenVideosService Documentation Critique & Implementation Plan

## Executive Summary

The existing `SEEN_VIDEOS_SERVICE_USAGE.md` documentation provides good API reference but **fundamentally misunderstands the OpenVine architecture** and provides non-functional implementation examples. This document provides a critical analysis and actionable implementation plan.

---

## 🔴 Critical Issues

### 1. **Architecture Mismatch: Imperative vs Reactive**

**Problem**: Documentation shows imperative code patterns that don't work with OpenVine's Riverpod stream architecture.

**Example from docs**:
```dart
// ❌ This won't work - videoEventsProvider is a Stream<List<VideoEvent>>
final allVideos = ref.read(videoEventsProvider);
final freshFeed = buildFreshFirstFeed(allVideos);
```

**Reality**:
```dart
// ✅ videoEventsProvider is @Riverpod Stream<List<VideoEvent>>
// It continuously emits new video lists as they arrive from Nostr
```

**Impact**: All implementation examples in the doc are non-functional.

---

### 2. **Missing Context: Stream Transformation**

**Problem**: The docs don't explain how to transform Riverpod stream providers.

**What's needed**:
- Create a new Riverpod provider that wraps `videoEventsProvider`
- Transform the stream to reorder videos based on seen metrics
- Handle continuous stream emissions properly

**Missing concepts**:
- `StreamProvider` vs `FutureProvider` vs `Provider`
- `.when()` pattern for async data
- Provider composition and transformation
- Caching transformed results

---

### 3. **Broken Code Examples**

**Issue 1: Undefined variable**
```dart
List<VideoEvent> buildFreshFirstFeed(List<VideoEvent> videos) {
  // ...
  if (seenVideosService.hasSeenVideo(video.id)) {  // ❌ Where does seenVideosService come from?
```

**Issue 2: Empty setState**
```dart
setState(() {
  // Update your feed display  // ❌ What exactly gets updated?
});
```

**Issue 3: Wrong provider access**
```dart
final allVideos = ref.read(videoEventsProvider);  // ❌ Can't ref.read() a Stream provider
```

---

### 4. **Doesn't Account for Real Feed Behavior**

**Missing considerations**:

1. **Continuous stream updates**: Videos arrive constantly from Nostr relays
2. **Infinite scroll**: Users scroll through feeds, triggering pagination
3. **PageView indices**: Reordering breaks PageController position tracking
4. **Preloading**: VideoManager preloads adjacent videos - reordering breaks this
5. **Multiple feed types**: Home feed (follows), Discovery feed (all), Hashtag feeds
6. **Tab navigation**: ExploreScreen has 3 tabs, each with different content

---

### 5. **Performance Not Addressed**

**Problems**:
- Sorting 1000+ videos on every stream emission
- No caching strategy
- Accessing SeenVideosService synchronously in hot path
- No consideration of UI thread blocking

**Solutions needed**:
- Debouncing stream transformations
- Caching sorted order with invalidation strategy
- Background sorting for large lists
- Lazy evaluation

---

### 6. **UX Unclear**

**Questions not answered**:

1. **When to apply sorting?**
   - On app resume only?
   - On pull-to-refresh?
   - Continuously as videos arrive?
   - On explicit user action?

2. **What about scroll position?**
   - Jump to top after resorting?
   - Insert new videos above current position?
   - Preserve position and sort below?

3. **Multiple feed contexts?**
   - Apply to home feed (follows only)?
   - Apply to discovery feed (all videos)?
   - Apply to hashtag feeds?
   - All of the above?

---

## ✅ What's Actually Good

1. **SeenVideoMetrics model design** - Well structured with proper serialization
2. **Migration logic** - Handles legacy format correctly
3. **Storage strategy** - SharedPreferences + JSON is appropriate
4. **API method names** - Clear and intuitive
5. **VideoMetricsTracker integration** - Correctly captures engagement data

---

## 📋 Implementation Plan

### Phase 1: Create Fresh-First Provider (Core Infrastructure)

**Objective**: Build a Riverpod provider that transforms video streams to prioritize unwatched content.

#### Prompt 1A: Create FreshFirstVideoProvider
```
Create lib/providers/fresh_first_video_provider.dart that:

1. Takes a base video stream provider (videoEventsProvider or homeFeedProvider)
2. Listens to seenVideosServiceProvider
3. Transforms the video list to prioritize:
   - Unwatched videos first
   - Then videos not seen in last 7 days (stalest first)
   - Then recently seen videos (oldest first)
4. Debounces transformations (500ms) to avoid excessive sorting
5. Caches the sorted list and only re-sorts when:
   - New videos arrive in base provider
   - App resumes from background (via app lifecycle)
   - User explicitly refreshes

Requirements:
- Use Riverpod @riverpod annotation
- Return StreamProvider<List<VideoEvent>>
- Handle null/uninitialized seenVideosService gracefully
- Add logging for debugging sort operations
- Keep performance <100ms for 1000 videos
```

#### Prompt 1B: Add App Resume Detection
```
Modify lib/providers/fresh_first_video_provider.dart to:

1. Watch app lifecycle state changes
2. Set a flag when app resumes from background
3. Trigger re-sort on next stream emission after resume
4. Clear the flag after re-sort completes
5. Add provider method: invalidateSortCache() for manual refresh

Use WidgetsBindingObserver pattern integrated with Riverpod lifecycle.
```

---

### Phase 2: Integrate with Video Feed Screens

#### Prompt 2A: Add Toggle to VideoFeedScreen
```
Modify lib/screens/video_feed_screen.dart to:

1. Add optional parameter: useFreshFirstSorting (default: false for now)
2. When true, use freshFirstHomeFeedProvider instead of homeFeedProvider
3. Preserve all existing functionality:
   - PageView scrolling
   - Video preloading
   - Lifecycle management
   - Error boundaries
4. Add pull-to-refresh handler that calls invalidateSortCache()
5. Handle loading states with shimmer/skeleton

Keep changes minimal and backward-compatible.
```

#### Prompt 2B: Add Toggle to ExploreScreen
```
Modify lib/screens/explore_screen.dart to:

1. Add settings button in AppBar
2. Settings menu with toggle: "Show Fresh Content First"
3. Store preference in SharedPreferences
4. When enabled, use freshFirstVideoEventsProvider
5. When disabled, use standard videoEventsProvider
6. Add visual indicator when fresh-first mode is active

Maintain all existing tab navigation and grid/feed mode switching.
```

---

### Phase 3: Settings & User Control

#### Prompt 3A: Add Feed Preferences Screen
```
Create lib/screens/settings/feed_preferences_screen.dart with:

1. Toggle: "Prioritize Unwatched Videos"
2. Slider: "Show videos not seen in X days" (1-30 days)
3. Toggle: "Apply to Home Feed"
4. Toggle: "Apply to Discovery Feed"
5. Button: "Reset Viewing History"
6. Statistics display:
   - Total videos watched
   - Total watch time
   - Average loops per video

Save preferences to SharedPreferences.
Create provider: feedPreferencesProvider for reactive access.
```

#### Prompt 3B: Wire Settings to Main Settings Screen
```
Modify lib/screens/settings_screen.dart to add:

1. New menu item: "Feed Preferences"
2. Navigate to FeedPreferencesScreen
3. Show badge if fresh-first mode is enabled
4. Add icon (sparkle/star to indicate "new content")
```

---

### Phase 4: UX Polish & Testing

#### Prompt 4A: Add Visual Indicators
```
Modify lib/widgets/video_feed_item.dart to:

1. Add subtle badge for unwatched videos (small dot in corner)
2. Add "NEW" label for videos never seen
3. Add "FRESH" label for videos not seen in 7+ days
4. Make badges configurable via FeedPreferences
5. Animate badges with gentle pulse

Design should match VineTheme colors and feel.
```

#### Prompt 4B: Performance Testing
```
Create test/integration/fresh_first_feed_performance_test.dart to verify:

1. Sorting 1000 videos completes in <100ms
2. Memory usage stays under 50MB for sorted feed
3. No UI jank during sort operations
4. Stream transformations are properly debounced
5. Cache invalidation works correctly

Use flutter_driver for performance profiling.
```

#### Prompt 4C: Integration Testing
```
Create test/integration/fresh_first_feed_integration_test.dart to verify:

1. Unwatched videos appear first in feed
2. Watching a video moves it down in next load
3. App resume triggers re-sort
4. Pull-to-refresh updates sorting
5. Settings changes apply immediately
6. Multiple feed contexts work independently
```

---

### Phase 5: Feature Flag & Rollout

#### Prompt 5A: Add Feature Flag
```
Use existing feature flag system in lib/features/feature_flags/ to:

1. Add flag: "fresh_first_feed_enabled"
2. Default to false (opt-in beta)
3. Add A/B test support (50/50 split)
4. Add remote config support for rollout control
5. Log analytics event when feature is used

Wire flag to feed preference toggles.
```

#### Prompt 5B: Analytics Events
```
Add analytics tracking in lib/services/analytics_service.dart:

1. Event: "fresh_first_feed_enabled" (when user enables)
2. Event: "fresh_first_feed_sort_triggered" (with video count)
3. Event: "unwatched_video_viewed" (to measure engagement)
4. Property: "feed_sort_mode" on all video views

Use existing AnalyticsService patterns.
```

---

## 🎯 Success Metrics

**Technical**:
- Sort performance <100ms for 1000 videos
- No memory leaks or excessive memory usage
- No impact on video loading/playback
- Clean Riverpod provider composition

**User Experience**:
- Users see fewer repeat videos on app reopen
- Engagement with "new" videos increases
- Pull-to-refresh provides clear value
- Settings are discoverable and intuitive

**Business**:
- Increased session duration
- Higher video completion rates
- More unique videos viewed per session
- Positive user feedback on feature

---

## ⚠️ Risks & Mitigation

### Risk 1: Breaking Preloading
**Impact**: Video playback becomes janky
**Mitigation**: Keep original provider as default, test thoroughly

### Risk 2: Scroll Position Loss
**Impact**: Users lose their place in feed
**Mitigation**: Only apply sorting on explicit actions (refresh, app resume)

### Risk 3: Performance Degradation
**Impact**: UI becomes sluggish
**Mitigation**: Profile with DevTools, implement background sorting if needed

### Risk 4: User Confusion
**Impact**: Users don't understand why feed order changed
**Mitigation**: Clear visual indicators, settings documentation, onboarding

---

## 📚 Updated Documentation Needed

Once implementation is complete, update `SEEN_VIDEOS_SERVICE_USAGE.md` with:

1. **Real Riverpod stream transformation examples**
2. **Actual provider composition patterns**
3. **Performance considerations and benchmarks**
4. **UX recommendations for when to apply sorting**
5. **Troubleshooting section for common issues**

---

## 🚀 Recommended Rollout

1. **Week 1**: Implement Phase 1 (provider infrastructure)
2. **Week 2**: Implement Phase 2 (UI integration)
3. **Week 3**: Implement Phase 3 (settings & preferences)
4. **Week 4**: Implement Phase 4 (testing & polish)
5. **Week 5**: Beta rollout to 10% of users
6. **Week 6**: Analyze metrics, iterate
7. **Week 7**: Full rollout or rollback decision

---

## 💡 Alternative Approaches

### Option A: Server-Side Sorting
**Pros**: No client performance impact, consistent across devices
**Cons**: Requires backend changes, doesn't work offline, privacy concerns

### Option B: ML-Based Recommendations
**Pros**: Smarter than simple "unwatched" logic, personalized
**Cons**: Complex, requires training data, overkill for MVP

### Option C: User-Controlled Sort Menu
**Pros**: Explicit user control, no assumptions
**Cons**: More UI complexity, decision fatigue

**Recommendation**: Start with client-side sorting (current plan), evaluate others based on user feedback.
