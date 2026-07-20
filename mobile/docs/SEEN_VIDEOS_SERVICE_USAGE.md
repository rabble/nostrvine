# SeenVideosService Usage Guide

## Overview

`SeenVideosService` tracks which videos users have watched with rich engagement metrics including:
- **First seen timestamp** - When user first viewed the video
- **Last seen timestamp** - Most recent view
- **Loop count** - How many times video looped
- **Watch duration** - Total and last session watch time

This enables features like:
- Prioritizing unwatched content in feeds
- Showing "fresh" videos when reopening the app
- Understanding user engagement patterns

## Basic Usage

### Check if Video Was Seen

```dart
final seenVideosService = ref.read(seenVideosServiceProvider);

if (seenVideosService.hasSeenVideo(videoId)) {
  // Video has been seen before
}
```

### Get Detailed Metrics

```dart
final metrics = seenVideosService.getVideoMetrics(videoId);
if (metrics != null) {
  print('First seen: ${metrics.firstSeenAt}');
  print('Last seen: ${metrics.lastSeenAt}');
  print('Loop count: ${metrics.loopCount}');
  print('Total watch time: ${metrics.totalWatchDuration}');
}
```

### Check Recent Views

```dart
// Check if seen in last 24 hours
if (seenVideosService.wasSeenRecently(videoId, within: Duration(hours: 24))) {
  // Recently viewed
}
```

## Prioritizing Fresh Content

### Filter Unwatched Videos

```dart
// Filter feed to show only unwatched videos
final unwatchedVideos = allVideos.where((video) {
  return !seenVideosService.hasSeenVideo(video.id);
}).toList();
```

### Prioritize Videos Not Seen Recently

```dart
// Get videos not seen in last 7 days
final staleVideoIds = seenVideosService.getVideosNotSeenSince(
  Duration(days: 7)
);

// Sort feed: unwatched first, then stale, then recently seen
final sortedFeed = allVideos.toList()..sort((a, b) {
  final aMetrics = seenVideosService.getVideoMetrics(a.id);
  final bMetrics = seenVideosService.getVideoMetrics(b.id);

  // Unwatched videos first
  if (aMetrics == null && bMetrics != null) return -1;
  if (aMetrics != null && bMetrics == null) return 1;
  if (aMetrics == null && bMetrics == null) return 0;

  // Then sort by last seen (oldest first = freshest to user)
  return aMetrics.lastSeenAt.compareTo(bMetrics.lastSeenAt);
});
```

### Simple "Fresh First" Feed

```dart
List<VideoEvent> buildFreshFirstFeed(List<VideoEvent> videos) {
  final seenVideos = <VideoEvent>[];
  final unseenVideos = <VideoEvent>[];

  for (final video in videos) {
    if (seenVideosService.hasSeenVideo(video.id)) {
      seenVideos.add(video);
    } else {
      unseenVideos.add(video);
    }
  }

  // Sort seen videos by last seen date (oldest first)
  seenVideos.sort((a, b) {
    final aMetrics = seenVideosService.getVideoMetrics(a.id)!;
    final bMetrics = seenVideosService.getVideoMetrics(b.id)!;
    return aMetrics.lastSeenAt.compareTo(bMetrics.lastSeenAt);
  });

  // Return unseen first, then seen (oldest to newest)
  return [...unseenVideos, ...seenVideos];
}
```

## Automatic Tracking

Video viewing is tracked automatically via `DivineVideoMetricsTracker` widget. When a video finishes playing or user navigates away, metrics are saved:

```dart
// This happens automatically in DivineVideoMetricsTracker
seenVideosService.recordVideoView(
  videoId,
  loopCount: loopCount,
  watchDuration: totalWatchDuration,
);
```

## Statistics

Get aggregate statistics about viewing history:

```dart
final stats = seenVideosService.getStatistics();

print('Total videos seen: ${stats['totalSeen']}');
print('Total loops: ${stats['totalLoops']}');
print('Total watch time: ${stats['totalWatchTimeMinutes']} minutes');
print('Average loops per video: ${stats['averageLoopsPerVideo']}');
```

## Data Persistence

- **Storage**: SharedPreferences with JSON serialization
- **Limit**: 1000 most recent videos (automatically trimmed)
- **Migration**: Automatically migrates from legacy `Set<String>` format
- **Persistence**: Survives app restarts

## Implementation Example: Fresh Feed on App Reopen

```dart
class VideoFeedScreen extends ConsumerStatefulWidget {
  @override
  ConsumerState<VideoFeedScreen> createState() => _VideoFeedScreenState();
}

class _VideoFeedScreenState extends ConsumerState<VideoFeedScreen>
    with WidgetsBindingObserver {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App reopened - refresh feed with fresh content prioritized
      _refreshFeedWithFreshContent();
    }
  }

  void _refreshFeedWithFreshContent() {
    final seenVideosService = ref.read(seenVideosServiceProvider);
    final allVideos = ref.read(videoEventsProvider);

    // Build feed with unwatched videos first
    final freshFeed = buildFreshFirstFeed(allVideos);

    // Update feed state
    setState(() {
      // Update your feed display
    });
  }
}
```

## Advanced: Engagement-Based Sorting

Sort by engagement to show videos user might want to rewatch:

```dart
// Sort by total engagement (loops + watch time)
final sortedByEngagement = videos.toList()..sort((a, b) {
  final aMetrics = seenVideosService.getVideoMetrics(a.id);
  final bMetrics = seenVideosService.getVideoMetrics(b.id);

  if (aMetrics == null && bMetrics == null) return 0;
  if (aMetrics == null) return -1;
  if (bMetrics == null) return 1;

  final aScore = aMetrics.loopCount +
                 (aMetrics.totalWatchDuration.inSeconds / 60);
  final bScore = bMetrics.loopCount +
                 (bMetrics.totalWatchDuration.inSeconds / 60);

  return bScore.compareTo(aScore);
});
```
