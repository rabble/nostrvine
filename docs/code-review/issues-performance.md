# Performance Issues

Issues related to app startup, video playback, list scrolling, memory management, and rendering efficiency.

Note: These 7 issues are concentrated on the video feed (the app's highest-traffic path), app startup, and relay communication. Several compound in the feed scroll path, but most are low-to-medium effort fixes.

---

### Android release build has R8 minification and shrinking disabled
**Problem**: The Android release build explicitly disables code shrinking and minification, resulting in larger APK sizes.

**Evidence**: `mobile/android/app/build.gradle.kts` lines 80–82: `// TEMPORARILY DISABLE R8 minification for debugging`, `isMinifyEnabled = false`, `isShrinkResources = false`. Without R8, unused code and resources are not stripped from the release APK.

**Impact**: Medium. Release APK is significantly larger than necessary. R8 tree-shaking and resource shrinking typically reduce APK size by 30–50%. Note: since the project is open source, there is no reverse-engineering concern; this is purely a size optimization.

**Effort**: Low. Remove the "temporarily disable" comment and re-enable `isMinifyEnabled = true` and `isShrinkResources = true`.

**GitHub ticket**: TBD

---

### Video feed rendering has multiple hot-path inefficiencies

**Problem**: The video feed's scroll and pagination paths contain several O(n) and O(n²) operations that run on every rebuild or page load, plus a resource leak on web.

**Evidence**:

1. **O(n²) new-video detection**: `pooled_fullscreen_video_feed_screen.dart` lines 332–334: `_handleVideosChanged()` uses `.where((v) => !_lastPooledVideos!.any((old) => old.id == v.id))`. Every new video checks against every existing video via nested iteration.

2. **O(n) lookup per visible item**: `pooled_fullscreen_video_feed_screen.dart` lines 548–566: `itemBuilder` calls `state.videos.firstWhere((v) => v.id == video.id)` for each item Flutter builds during scroll. With 50+ videos, each card triggers a linear scan.

3. **Events-by-ID map rebuilt every render**: `video_feed_page.dart` lines 439–441: `final eventsById = { for (final event in state.videos) event.id: event }` is reconstructed on every `BlocBuilder` rebuild, even when the video list hasn't changed.

4. **Filter list rebuilt every render (web)**: `video_feed_page.dart` lines 450–452: `state.videos.where((v) => v.videoUrl != null).toList()` allocates a new filtered list on each rebuild.

5. **VideoPlayerControllers never disposed (web)**: `web_video_feed.dart` lines 78, 88–91: `_controllers` map accumulates `VideoPlayerController` instances as users scroll, but `dispose()` only cleans up `_pageController`. Controllers for previously-viewed videos are never released.

**Impact**: High. Items 1–4 cause increasing jank as the feed grows (each page load and scroll rebuild gets slower). Item 5 is a memory leak that grows linearly with videos watched on web.

**Effort**: Medium. Use a `Set<String>` for dedup (#1), pre-build an ID→event map once per state change (#2, #3), memoize filtered list or move to BLoC (#4), dispose all controllers in `dispose()` and evict off-screen ones (#5).

**Related**: Items #1 and #2 live in `pooled_fullscreen_video_feed_screen.dart`, which is part of the `pooled_video_player` system being replaced by `divine_video_player` (see [issues-dependencies.md](issues-dependencies.md#migrate-to-divine_video_player-replace-media_kit-fork-with-native-platform-apis)). These should be addressed during the feed integration work for the new player to avoid carrying the same patterns into the new implementation. Items #3–5 are in the feed orchestration layer (`video_feed_page.dart`, `web_video_feed.dart`) and need separate fixes regardless of the player migration.

**GitHub ticket**: TBD

---

### Profile grid runs expensive de-duplication logic inside build()

**Problem**: `ProfileVideosGrid.build()` performs DateTime parsing, Set membership checks, nested `.any()` iteration over active uploads, and a fire-and-forget `downloadFile()` call, all inside the build method on every rebuild.

**Evidence**: `profile_videos_grid.dart` lines 207–254:
- Lines 212–213: `DateTime.fromMillisecondsSinceEpoch()` parsed per video.
- Lines 219–223: `matchedTitles.contains()` + `activeUploads.any()` for each video, which is O(n×m) where n=videos and m=uploads.
- Lines 242–243: `openVineImageCache.downloadFile(url)` triggered inside `build()` as a side effect.
- Lines 251–254: Two `.map().toList()` calls to wrap results.

The code has a comment (lines 229–234) acknowledging the `downloadFile` placement and calling it "an acceptable trade-off," but the broader filtering logic is the bigger concern.

**Impact**: Medium. On profiles with many videos and active uploads, this adds latency to every rebuild. The side-effecting cache warm-up inside `build()` also violates the principle of keeping build methods pure.

**Effort**: Medium. Move the de-duplication into `didUpdateWidget` or a memoized helper that only recomputes when inputs change.

**Related**: Migrating this screen to BLoC would resolve this naturally. The de-duplication would run once in the event handler and the filtered list would be stored in state, eliminating recomputation on every rebuild.

**GitHub ticket**: TBD

---

### Untracked `Future.delayed` calls in VideoFeedItem

**Problem**: `_triggerPauseButtonFade()` fires two `Future.delayed` calls that cannot be cancelled when the widget is disposed. Although both check `mounted` before calling `setState`, the futures themselves remain alive in memory until they complete.

**Evidence**: `video_feed_item.dart` lines 182–196: Two `Future.delayed` calls (50ms and 550ms) drive a fade animation. If the user scrolls past the video quickly, both futures outlive the widget and run their `mounted` check uselessly. Under rapid scrolling, dozens of orphaned futures can accumulate.

**Impact**: Low. The `mounted` guard prevents crashes, but orphaned futures add unnecessary work to the event loop during fast scrolling. A minor contributor to scroll jank on lower-end devices.

**Effort**: Low. Store the futures or use a `Timer` and cancel in `dispose()`. Alternatively, replace with an `AnimationController` which integrates with the widget lifecycle.

**GitHub ticket**: TBD

---

### `context.watch` on full BLoC state causes unnecessary widget rebuilds
**Problem**: Some widgets use `context.watch<SomeBloc>()` to subscribe to an entire BLoC state but only read 1 field, causing rebuilds whenever any unrelated state field changes. `context.select` (or `BlocSelector`) should be used to subscribe to only the needed property.

**Evidence (examples)**:

1. **`profile_videos_grid.dart` line 199**: `context.watch<BackgroundPublishBloc>()` watches the full state but only uses `.state.uploads` (filtered to active ones). `BackgroundPublishState` emits on every upload progress tick (progress field changes per upload). The grid rebuilds on every tick even though it only cares about which uploads exist and whether they have a result. This is the highest-impact occurrence because progress updates are frequent during upload.

2. **`video_editor_draw_item_indicator.dart` line 18**: `context.watch<VideoEditorDrawBloc>().state.selectedTool` watches full state but only reads `selectedTool`. `VideoEditorDrawState` has 7 fields (`canUndo`, `canRedo`, `strokeWidth`, `opacity`, `selectedColor`, `selectedTool`, `mode`). The indicator rebuilds when undo/redo availability, color, or stroke width change, none of which affect it.

3. **`profile_header_widget.dart` line 73**: `context.watch<MyProfileBloc>().state` watches a sealed class with 5 variants but only pattern-matches the `profile` field from `MyProfileUpdated`. Rebuilds on loading-to-loaded transitions, `isFresh` changes, `extractedUsername` changes, and error states, all irrelevant to the header's rendering.

**Done well**: `comment_item.dart` uses `BlocSelector<CommentsBloc, CommentsState, ({bool isUpvoted, bool isDownvoted, ...})>` to select exactly the 4 vote-related fields. `comments_screen.dart` uses `BlocSelector<CommentsBloc, CommentsState, CommentsSortMode>`. `my_followers_screen.dart` uses `BlocSelector<MyFollowingBloc, MyFollowingState, bool>`. These demonstrate the correct pattern.

**Impact**: Medium. #1 has the most room for improvement since upload progress emits many times per second during active uploads, triggering full grid rebuilds. #2 and #3 cause extra rebuilds on moderately interactive screens. None cause visible jank in isolation, but they add up and are worth addressing to keep new code on the right track.

**Effort**: Low. Each fix is a one-line change from `context.watch<Bloc>()` to `context.select<Bloc, T>((bloc) => bloc.state.field)`. Fixes:
- #1: `context.select<BackgroundPublishBloc, List<BackgroundUpload>>((bloc) => bloc.state.uploads.where((u) => u.result == null).toList())`
- #2: `context.select<VideoEditorDrawBloc, DrawToolType>((bloc) => bloc.state.selectedTool)`
- #3: `context.select<MyProfileBloc, UserProfile?>((bloc) => switch (bloc.state) { MyProfileUpdated(:final profile) => profile, _ => null })`

**GitHub ticket**: TBD

---

### Startup cleanup runs synchronously on every cold start
**Problem**: `runStartupCleanup()` executes 4 delete queries on app startup. Combined with `_createMissingTables()`, the `beforeOpen` hook runs significant database work before the app can render.

**Evidence**: `mobile/packages/db_client/lib/src/database/app_database.dart` lines 66–76: `beforeOpen` calls both `_createMissingTables()` and `runStartupCleanup()` sequentially. Lines 481–507: `runStartupCleanup` runs 4 database operations. On devices with large caches (thousands of cached events), the cleanup queries could add noticeable latency to cold start.

**Impact**: Medium. Adds latency to cold start; the migration check adds another 50+ SQL statements before the app renders.

**Effort**: Low. Defer cleanup to a background isolate or schedule it after the first frame renders.

**Related**: See "Schema stuck at version 1 with ad-hoc migration logic" in [issues-architecture.md](issues-architecture.md). Fixing the migration approach would also resolve the `_createMissingTables()` startup cost.

**GitHub ticket**: TBD

---

### Video overlay fires 3 relay round-trips per video; Funnelcake has a single endpoint

**Problem**: Every video in the app fires 3 separate NIP-45 COUNT relay requests to get like count, repost count, and comment count. Funnelcake already has `GET /api/videos/{id}/stats` that returns all three in a single call, but it isn't wired.

**Evidence**: The video overlay calls `getReactionCount()`, `getRepostCount()`, and `getCommentsCount()` independently through the relay layer. Each is a separate WebSocket round-trip with relay fan-out. In a feed of 10 videos, this is 30 relay calls where 10 API calls (or fewer with batching) would suffice. The Funnelcake stats endpoint is already live and used by other features (e.g., search results return stats inline), but the video overlay doesn't use it.

**Related**: See "No documented data source strategy" in [issues-architecture.md](issues-architecture.md) for the broader pattern of unwired Funnelcake endpoints. This is the single highest-impact instance of that gap.

**Impact**: High. Every video in every feed pays 3x the network cost. On slow connections or under relay congestion, counts appear with visible delay as each response arrives independently. This is the most-executed read path in the entire app.

**Effort**: Low. Wire `GET /api/videos/{id}/stats` through the existing `FunnelcakeApiClient` into the video repository. Return all three counts in one call. Keep the relay path as fallback when the API is unavailable.

**GitHub ticket**: TBD
