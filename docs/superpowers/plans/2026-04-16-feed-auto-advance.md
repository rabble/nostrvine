# Feed Auto Advance Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a feed-scoped `Auto` playback mode that advances after one play, suppresses on non-swipe interactions, resumes on swipe, paginates when more content exists, and wraps to the first item only when the feed is exhausted.

**Architecture:** Keep `Auto` in the feed layer, not the shared player package. Use a small feed-session runtime model plus a reusable completion listener so fullscreen and home feeds can share the same rules while still owning their own pagination and navigation decisions. The action rail gets a lightweight `Auto` button wired into the current feed session only.

**Tech Stack:** Flutter, flutter_bloc, flutter_riverpod, pooled_video_player, media_kit `Player` streams, Flutter l10n ARB files, widget tests.

---

## File Map

### New files

- `mobile/lib/screens/feed/feed_auto_advance_session.dart`
  Feed-scoped runtime model for `autoEnabled`, `autoSuppressed`, and resume/suppress transitions.
- `mobile/lib/screens/feed/feed_auto_advance_policy.dart`
  Pure decision helper that turns `(currentIndex, itemCount, hasMore, isLoadingMore)` into `next`, `paginate`, `wrap`, or `noop`.
- `mobile/lib/screens/feed/feed_auto_advance_completion_listener.dart`
  Reusable widget/helper that watches a `Player` for one completed play (loop boundary) and invokes a callback once per cycle.
- `mobile/lib/widgets/video_feed_item/actions/auto_action_button.dart`
  Rail button for `Auto`.
- `mobile/test/screens/feed/feed_auto_advance_session_test.dart`
  Unit tests for feed-session state transitions.
- `mobile/test/screens/feed/feed_auto_advance_policy_test.dart`
  Unit tests for next/paginate/wrap decisions.
- `mobile/test/widgets/video_feed_item/actions/auto_action_button_test.dart`
  Widget tests for button state, label, and semantics.

### Existing files to modify

- `mobile/lib/widgets/video_feed_item/actions/actions.dart`
  Export the new `AutoActionButton`.
- `mobile/lib/widgets/video_feed_item/actions/video_action_button.dart`
  Support a small optional caption under the icon so the rail can show `Auto` without pretending it is a count.
- `mobile/lib/widgets/video_feed_item/actions/like_action_button.dart`
  Add an optional interaction callback fired before toggling like.
- `mobile/lib/widgets/video_feed_item/actions/comment_action_button.dart`
  Add an optional interaction callback fired before opening comments.
- `mobile/lib/widgets/video_feed_item/actions/repost_action_button.dart`
  Add an optional interaction callback fired before toggling repost.
- `mobile/lib/widgets/video_feed_item/actions/share_action_button.dart`
  Add an optional interaction callback fired before opening the share sheet.
- `mobile/lib/widgets/video_feed_item/actions/more_action_button.dart`
  Add an optional interaction callback fired before opening metadata.
- `mobile/lib/widgets/video_feed_item/video_feed_item.dart`
  Extend `VideoOverlayActionColumn` to accept auto state and interaction hooks; wire profile and description taps into suppression for legacy/other surfaces without enabling auto by default.
- `mobile/lib/screens/feed/feed_video_overlay.dart`
  Thread feed-session callbacks into the rail and the profile/metadata tap affordances used by the pooled home feed.
- `mobile/lib/screens/feed/pooled_fullscreen_video_feed_screen.dart`
  Own fullscreen auto session, drive advance/paginate/wrap behavior, clear suppression on swipe, and attach completion listeners to active players.
- `mobile/lib/blocs/fullscreen_feed/fullscreen_feed_event.dart`
  Add events only if needed to represent source exhaustion updates or queued auto-continuation after pagination.
- `mobile/lib/blocs/fullscreen_feed/fullscreen_feed_state.dart`
  Track real `hasMore` rather than assuming `onLoadMore != null` means more items always exist.
- `mobile/lib/blocs/fullscreen_feed/fullscreen_feed_bloc.dart`
  Subscribe to a `hasMore` stream/value from the source and expose it to fullscreen runtime decisions.
- `mobile/lib/screens/feed/video_feed_page.dart`
  Own home-feed auto session and advance logic for the main in-shell feed.
- `mobile/lib/widgets/for_you_tab.dart`
  Pass source `hasMore` information into fullscreen args if not already available through the upstream feed bloc.
- `mobile/lib/widgets/new_videos_tab.dart`
  Pass source `hasMore` information into fullscreen args.
- `mobile/lib/widgets/popular_videos_tab.dart`
  Pass source `hasMore` information into fullscreen args.
- `mobile/lib/screens/hashtag_feed_screen.dart`
  Pass source `hasMore` information into fullscreen args.
- `mobile/lib/screens/profile_screen_router.dart`
  Pass source `hasMore` information into fullscreen args for profile feeds.
- `mobile/lib/widgets/profile/profile_videos_grid.dart`
  Pass source `hasMore` information into fullscreen args.
- `mobile/lib/widgets/profile/profile_liked_grid.dart`
  Pass source `hasMore` information into fullscreen args.
- `mobile/lib/widgets/profile/profile_reposts_grid.dart`
  Pass source `hasMore` information into fullscreen args.
- `mobile/lib/widgets/profile/profile_collabs_grid.dart`
  Pass source `hasMore` information into fullscreen args.
- `mobile/lib/screens/liked_videos_screen_router.dart`
  Pass source `hasMore` information into fullscreen args.
- `mobile/lib/screens/explore_screen.dart`
  Pass source `hasMore` information into fullscreen args if the source can paginate.
- `mobile/lib/screens/pure/search_screen_pure.dart`
  Pass explicit non-paginable state for fullscreen args if search/video detail sources are finite.
- `mobile/lib/screens/video_detail_screen.dart`
  Pass explicit non-paginable state for fullscreen args if this remains a finite sequence.
- `mobile/lib/screens/curated_list_feed_screen.dart`
  Pass explicit non-paginable or real `hasMore` state, depending on source behavior.
- `mobile/lib/screens/sound_detail_screen.dart`
  Pass explicit non-paginable state for fullscreen args if this feed is finite.
- `mobile/lib/screens/search_results/widgets/videos_section.dart`
  Pass explicit pagination/exhaustion state.
- `mobile/lib/screens/search_results/widgets/video_search_view.dart`
  Pass explicit pagination/exhaustion state.
- `mobile/lib/screens/category_gallery_screen.dart`
  Pass explicit pagination/exhaustion state.
- `mobile/lib/widgets/classic_vines_tab.dart`
  Pass explicit pagination/exhaustion state.
- `mobile/lib/screens/notifications_screen.dart`
  Pass explicit pagination/exhaustion state where notification-driven fullscreen opens a feed.
- `mobile/lib/notifications/view/notifications_view.dart`
  Same as above if this path constructs fullscreen args directly.
- `mobile/lib/l10n/app_en.arb`
  Add `Auto` rail label and semantics keys.
- `mobile/lib/l10n/app_*.arb`
  Mirror the new keys across every locale file so `flutter gen-l10n` succeeds.
- `mobile/test/screens/feed/pooled_fullscreen_video_feed_screen_test.dart`
  Add fullscreen auto-advance, suppression, swipe-resume, paginate, and wrap tests.
- `mobile/test/screens/feed/feed_video_overlay_test.dart`
  Add overlay wiring tests for auto rail rendering and suppression callbacks.
- `mobile/test/widgets/video_feed_item/actions/video_action_button_test.dart`
  Cover optional caption rendering.
- `mobile/test/widgets/video_feed_item/actions/like_action_button_test.dart`
  Cover the interaction callback.
- `mobile/test/widgets/video_feed_item/actions/comment_action_button_test.dart`
  Cover the interaction callback.
- `mobile/test/widgets/video_feed_item/actions/repost_action_button_test.dart`
  Cover the interaction callback.
- `mobile/test/widgets/video_feed_item/actions/share_action_button_test.dart`
  Cover the interaction callback.

## Chunk 1: Shared Feed-Session Model And Rail UI

### Task 1: Add a pure feed-session state model and advance policy

**Files:**
- Create: `mobile/lib/screens/feed/feed_auto_advance_session.dart`
- Create: `mobile/lib/screens/feed/feed_auto_advance_policy.dart`
- Test: `mobile/test/screens/feed/feed_auto_advance_session_test.dart`
- Test: `mobile/test/screens/feed/feed_auto_advance_policy_test.dart`

- [ ] **Step 1: Write failing tests for session defaults and interaction transitions**

```dart
test('fresh session starts disabled and unsuppressed', () {
  final session = FeedAutoAdvanceSession();

  expect(session.autoEnabled, isFalse);
  expect(session.autoSuppressed, isFalse);
  expect(session.isEffectivelyActive, isFalse);
});

test('non-swipe interaction suppresses enabled auto until swipe resumes it', () {
  final session = FeedAutoAdvanceSession()..setEnabled(true);

  session.suppressForInteraction();
  expect(session.isEffectivelyActive, isFalse);

  session.resumeAfterSwipe();
  expect(session.isEffectivelyActive, isTrue);
});
```

- [ ] **Step 2: Run the new tests to verify they fail**

Run: `flutter test test/screens/feed/feed_auto_advance_session_test.dart test/screens/feed/feed_auto_advance_policy_test.dart`

Expected: FAIL because the new session/policy files do not exist yet.

- [ ] **Step 3: Implement the minimal pure model and policy**

```dart
enum FeedAutoAdvanceInstruction { next, paginate, wrap, noop }

final class FeedAutoAdvanceSession extends ChangeNotifier {
  bool _autoEnabled = false;
  bool _autoSuppressed = false;

  bool get autoEnabled => _autoEnabled;
  bool get autoSuppressed => _autoSuppressed;
  bool get isEffectivelyActive => _autoEnabled && !_autoSuppressed;

  void setEnabled(bool value) {
    if (_autoEnabled == value) return;
    _autoEnabled = value;
    if (!value) _autoSuppressed = false;
    notifyListeners();
  }

  void toggle() => setEnabled(!_autoEnabled);

  void suppressForInteraction() {
    if (!_autoEnabled || _autoSuppressed) return;
    _autoSuppressed = true;
    notifyListeners();
  }

  void resumeAfterSwipe() {
    if (!_autoEnabled || !_autoSuppressed) return;
    _autoSuppressed = false;
    notifyListeners();
  }
}

FeedAutoAdvanceInstruction decideFeedAutoAdvance({
  required int currentIndex,
  required int itemCount,
  required bool hasMore,
  required bool isLoadingMore,
}) {
  if (itemCount == 0) return FeedAutoAdvanceInstruction.noop;
  if (currentIndex < itemCount - 1) return FeedAutoAdvanceInstruction.next;
  if (hasMore && !isLoadingMore) return FeedAutoAdvanceInstruction.paginate;
  return FeedAutoAdvanceInstruction.wrap;
}
```

- [ ] **Step 4: Re-run the unit tests**

Run: `flutter test test/screens/feed/feed_auto_advance_session_test.dart test/screens/feed/feed_auto_advance_policy_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit the pure model**

```bash
git add \
  mobile/lib/screens/feed/feed_auto_advance_session.dart \
  mobile/lib/screens/feed/feed_auto_advance_policy.dart \
  mobile/test/screens/feed/feed_auto_advance_session_test.dart \
  mobile/test/screens/feed/feed_auto_advance_policy_test.dart
git commit -m "feat(feed): add auto advance session model"
```

### Task 2: Add the `Auto` rail control and suppression plumbing

**Files:**
- Create: `mobile/lib/widgets/video_feed_item/actions/auto_action_button.dart`
- Modify: `mobile/lib/widgets/video_feed_item/actions/actions.dart`
- Modify: `mobile/lib/widgets/video_feed_item/actions/video_action_button.dart`
- Modify: `mobile/lib/widgets/video_feed_item/actions/like_action_button.dart`
- Modify: `mobile/lib/widgets/video_feed_item/actions/comment_action_button.dart`
- Modify: `mobile/lib/widgets/video_feed_item/actions/repost_action_button.dart`
- Modify: `mobile/lib/widgets/video_feed_item/actions/share_action_button.dart`
- Modify: `mobile/lib/widgets/video_feed_item/actions/more_action_button.dart`
- Modify: `mobile/lib/widgets/video_feed_item/video_feed_item.dart`
- Modify: `mobile/lib/screens/feed/feed_video_overlay.dart`
- Modify: `mobile/lib/l10n/app_en.arb`
- Modify: `mobile/lib/l10n/app_*.arb`
- Test: `mobile/test/widgets/video_feed_item/actions/auto_action_button_test.dart`
- Test: `mobile/test/widgets/video_feed_item/actions/video_action_button_test.dart`
- Test: `mobile/test/widgets/video_feed_item/actions/like_action_button_test.dart`
- Test: `mobile/test/widgets/video_feed_item/actions/comment_action_button_test.dart`
- Test: `mobile/test/widgets/video_feed_item/actions/repost_action_button_test.dart`
- Test: `mobile/test/widgets/video_feed_item/actions/share_action_button_test.dart`
- Test: `mobile/test/screens/feed/feed_video_overlay_test.dart`

- [ ] **Step 1: Write failing widget tests for the new rail button and interaction callback hooks**

```dart
testWidgets('AutoActionButton shows caption and active styling', (tester) async {
  await tester.pumpWidget(buildAutoButton(isEnabled: true));

  expect(find.text('Auto'), findsOneWidget);
  expect(find.bySemanticsLabel('Disable auto advance'), findsOneWidget);
});

testWidgets('LikeActionButton calls onInteracted before toggling', (tester) async {
  var interacted = false;
  await tester.pumpWidget(buildLikeButton(onInteracted: () => interacted = true));

  await tester.tap(find.byType(IconButton));
  expect(interacted, isTrue);
});
```

- [ ] **Step 2: Run only the affected widget tests**

Run: `flutter test test/widgets/video_feed_item/actions test/screens/feed/feed_video_overlay_test.dart`

Expected: FAIL because `AutoActionButton`, caption support, and interaction hooks are not implemented yet.

- [ ] **Step 3: Implement the rail button and callback plumbing**

```dart
class AutoActionButton extends StatelessWidget {
  const AutoActionButton({
    required this.isEnabled,
    required this.onPressed,
    super.key,
  });

  final bool isEnabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return VideoActionButton(
      icon: DivineIconName.caretDoubleRight,
      semanticIdentifier: 'auto_button',
      semanticLabel: isEnabled
          ? context.l10n.videoActionDisableAutoAdvance
          : context.l10n.videoActionEnableAutoAdvance,
      iconColor: isEnabled ? VineTheme.vineGreen : VineTheme.whiteText,
      caption: context.l10n.videoActionAutoLabel,
      onPressed: onPressed,
    );
  }
}
```

Implementation notes:
- Extend `VideoActionButton` with `String? caption`; render it below the icon when present and keep count behavior unchanged.
- Add `VoidCallback? onInteracted` to like/comment/repost/share/more buttons and invoke it before opening sheets or dispatching bloc events.
- Extend `VideoOverlayActionColumn` with:
  - `bool showAutoButton = false`
  - `bool isAutoEnabled = false`
  - `VoidCallback? onAutoPressed`
  - `VoidCallback? onInteracted`
- Place `AutoActionButton` above the like button when `showAutoButton == true`.
- In `feed_video_overlay.dart` and `video_feed_item.dart`, call the suppression callback before profile navigation and before opening metadata/details from the description tap.
- Add ARB keys such as:
  - `videoActionAutoLabel`
  - `videoActionEnableAutoAdvance`
  - `videoActionDisableAutoAdvance`

- [ ] **Step 4: Regenerate localizations**

Run: `flutter gen-l10n`

Expected: Generated `mobile/lib/l10n/generated/*` files update cleanly.

- [ ] **Step 5: Re-run the targeted widget tests**

Run: `flutter test test/widgets/video_feed_item/actions test/screens/feed/feed_video_overlay_test.dart`

Expected: PASS.

- [ ] **Step 6: Commit the rail UI slice**

```bash
git add \
  mobile/lib/widgets/video_feed_item/actions/auto_action_button.dart \
  mobile/lib/widgets/video_feed_item/actions/actions.dart \
  mobile/lib/widgets/video_feed_item/actions/video_action_button.dart \
  mobile/lib/widgets/video_feed_item/actions/like_action_button.dart \
  mobile/lib/widgets/video_feed_item/actions/comment_action_button.dart \
  mobile/lib/widgets/video_feed_item/actions/repost_action_button.dart \
  mobile/lib/widgets/video_feed_item/actions/share_action_button.dart \
  mobile/lib/widgets/video_feed_item/actions/more_action_button.dart \
  mobile/lib/widgets/video_feed_item/video_feed_item.dart \
  mobile/lib/screens/feed/feed_video_overlay.dart \
  mobile/lib/l10n/app_*.arb \
  mobile/lib/l10n/generated \
  mobile/test/widgets/video_feed_item/actions \
  mobile/test/screens/feed/feed_video_overlay_test.dart
git commit -m "feat(feed): add auto advance rail control"
```

## Chunk 2: Runtime Integration In Fullscreen And Home Feeds

### Task 3: Teach fullscreen feeds the difference between “can request more” and “is exhausted”

**Files:**
- Modify: `mobile/lib/screens/feed/pooled_fullscreen_video_feed_screen.dart`
- Modify: `mobile/lib/blocs/fullscreen_feed/fullscreen_feed_event.dart`
- Modify: `mobile/lib/blocs/fullscreen_feed/fullscreen_feed_state.dart`
- Modify: `mobile/lib/blocs/fullscreen_feed/fullscreen_feed_bloc.dart`
- Modify: every `PooledFullscreenVideoFeedArgs(...)` construction site that currently knows whether the source still has more content
- Test: `mobile/test/screens/feed/pooled_fullscreen_video_feed_screen_test.dart`

- [ ] **Step 1: Write failing tests for fullscreen paginate-versus-wrap behavior**

```dart
testWidgets('requests more content at end when source still has more', (tester) async {
  final bloc = buildReadyBloc(
    videos: createTestVideos(count: 1),
    currentIndex: 0,
    canLoadMore: true,
    isLoadingMore: false,
  );

  await tester.pumpWidget(buildFullscreen(bloc: bloc, autoEnabled: true));
  await fireCompletedPlayForCurrentVideo(tester);

  verify(() => bloc.add(const FullscreenFeedLoadMoreRequested())).called(1);
});

testWidgets('wraps to index 0 when source is exhausted', (tester) async {
  // expect animateToPage(0)
});
```

- [ ] **Step 2: Run the fullscreen test file**

Run: `flutter test test/screens/feed/pooled_fullscreen_video_feed_screen_test.dart`

Expected: FAIL because fullscreen still treats `canLoadMore` as “callback exists” instead of true source exhaustion state.

- [ ] **Step 3: Extend fullscreen args and bloc state to carry real source exhaustion**

```dart
class PooledFullscreenVideoFeedArgs {
  const PooledFullscreenVideoFeedArgs({
    required this.videosStream,
    required this.initialIndex,
    required this.hasMoreStream,
    this.onLoadMore,
    ...
  });

  final Stream<bool> hasMoreStream;
}
```

Implementation notes:
- Rename the fullscreen state field from `canLoadMore` to `hasMore` if that reads more truthfully.
- Subscribe to the new `hasMoreStream` alongside `videosStream`, or thread it into the bloc through a dedicated event like `FullscreenFeedHasMoreChanged`.
- Update each fullscreen launch site:
  - sources backed by blocs/providers with real `hasMore` should pass a live stream/value
  - finite sources should pass `Stream.value(false)` or equivalent
- Keep `onLoadMore` as the imperative action and `hasMore` as the truth about exhaustion.

- [ ] **Step 4: Re-run the fullscreen test file**

Run: `flutter test test/screens/feed/pooled_fullscreen_video_feed_screen_test.dart`

Expected: the new exhaustion-state tests still fail on missing runtime behavior, but the state shape compiles and test scaffolding can assert against real `hasMore`.

- [ ] **Step 5: Commit the fullscreen source-state plumbing**

```bash
git add \
  mobile/lib/screens/feed/pooled_fullscreen_video_feed_screen.dart \
  mobile/lib/blocs/fullscreen_feed/fullscreen_feed_event.dart \
  mobile/lib/blocs/fullscreen_feed/fullscreen_feed_state.dart \
  mobile/lib/blocs/fullscreen_feed/fullscreen_feed_bloc.dart \
  mobile/lib/screens \
  mobile/lib/widgets \
  mobile/test/screens/feed/pooled_fullscreen_video_feed_screen_test.dart
git commit -m "refactor(feed): thread fullscreen source exhaustion state"
```

### Task 4: Implement fullscreen auto-advance runtime

**Files:**
- Create: `mobile/lib/screens/feed/feed_auto_advance_completion_listener.dart`
- Modify: `mobile/lib/screens/feed/pooled_fullscreen_video_feed_screen.dart`
- Test: `mobile/test/screens/feed/pooled_fullscreen_video_feed_screen_test.dart`

- [ ] **Step 1: Add failing tests for fullscreen session behavior**

```dart
testWidgets('non-swipe interaction suppresses auto until swipe resumes it', (tester) async {
  // enable auto, tap like, fire completed-play signal, verify no navigation
  // then simulate swipe/index change and verify the next completed-play advances
});

testWidgets('fresh fullscreen session starts with auto off', (tester) async {
  await tester.pumpWidget(buildFullscreen(autoEnabled: false));
  expect(find.bySemanticsLabel('Enable auto advance'), findsOneWidget);
});
```

- [ ] **Step 2: Run the fullscreen test file again**

Run: `flutter test test/screens/feed/pooled_fullscreen_video_feed_screen_test.dart`

Expected: FAIL because fullscreen does not own an auto session yet.

- [ ] **Step 3: Implement the completion listener and fullscreen session wiring**

```dart
class FeedAutoAdvanceCompletionListener extends StatefulWidget {
  const FeedAutoAdvanceCompletionListener({
    required this.player,
    required this.videoId,
    required this.isActive,
    required this.isAutoActive,
    required this.onCompletedPlay,
    required this.child,
    super.key,
  });

  // detect one completed play by watching position reset from near-end to near-start
}
```

Fullscreen integration notes:
- Create a `FeedAutoAdvanceSession` in `_FullscreenFeedContentState`.
- Clear suppression in `onActiveVideoChanged` when the index actually changes by swipe or programmatic navigation.
- For manual pause/play, stop using `enableTapToPause` and provide an explicit `onTap` that:
  - suppresses the session
  - calls `VideoPoolProvider.feedOf(context).togglePlayPause()`
- Pass `showAutoButton`, `isAutoEnabled`, `onAutoPressed`, and `onInteracted` into `VideoOverlayActions`.
- Track `_pendingAutoAdvanceAfterPagination` so a completed play at the last loaded item can:
  - request load more
  - wait for `videos.length` to increase
  - then animate to the newly loaded next item
- When the policy returns `wrap`, call `animateToPage(0)`.
- Guard against duplicate triggers by resetting the completion listener whenever the active video ID changes.

- [ ] **Step 4: Re-run fullscreen tests**

Run: `flutter test test/screens/feed/pooled_fullscreen_video_feed_screen_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit fullscreen runtime**

```bash
git add \
  mobile/lib/screens/feed/feed_auto_advance_completion_listener.dart \
  mobile/lib/screens/feed/pooled_fullscreen_video_feed_screen.dart \
  mobile/test/screens/feed/pooled_fullscreen_video_feed_screen_test.dart
git commit -m "feat(feed): add fullscreen auto advance runtime"
```

### Task 5: Implement home-feed auto-advance runtime and final verification

**Files:**
- Modify: `mobile/lib/screens/feed/video_feed_page.dart`
- Modify: `mobile/lib/screens/feed/feed_video_overlay.dart`
- Reuse: `mobile/lib/screens/feed/feed_auto_advance_session.dart`
- Reuse: `mobile/lib/screens/feed/feed_auto_advance_policy.dart`
- Reuse: `mobile/lib/screens/feed/feed_auto_advance_completion_listener.dart`
- Test: `mobile/test/screens/feed/video_feed_page_test.dart`
- Test: `mobile/test/screens/feed/feed_video_overlay_test.dart`

- [ ] **Step 1: Write failing tests for the in-shell home feed**

```dart
testWidgets('home feed auto mode advances after one completed play', (tester) async {
  // enable auto from rail, emit completed-play signal, verify feed controller/page state advances
});

testWidgets('home feed wraps to first item when exhausted', (tester) async {
  // state.hasMore == false, currentIndex is last item, expect animateToPage(0)
});
```

- [ ] **Step 2: Run the home-feed test files**

Run: `flutter test test/screens/feed/video_feed_page_test.dart test/screens/feed/feed_video_overlay_test.dart`

Expected: FAIL because the in-shell feed does not own an auto session yet.

- [ ] **Step 3: Implement home-feed session ownership**

Implementation notes:
- Add `FeedAutoAdvanceSession` to `VideoFeedPageState`.
- Pass session state and callbacks into `_PooledVideoFeedItem` / `_PooledVideoFeedItemContent` and `FeedVideoOverlay`.
- Wrap the active player's video layer with `FeedAutoAdvanceCompletionListener`.
- On completed play:
  - use `decideFeedAutoAdvance(...)` with `state.hasMore`
  - call `context.read<VideoFeedBloc>().add(const VideoFeedLoadMoreRequested())` for paginate
  - wrap to page `0` when exhausted
- Resume after swipe inside `onActiveVideoChanged`.
- Suppress before pause/play tap by supplying a custom `onTap` to `PooledVideoPlayer` and calling the feed controller directly.

- [ ] **Step 4: Re-run the home-feed tests**

Run: `flutter test test/screens/feed/video_feed_page_test.dart test/screens/feed/feed_video_overlay_test.dart`

Expected: PASS.

- [ ] **Step 5: Run focused end-to-end verification from `mobile/`**

Run: `flutter test test/screens/feed/pooled_fullscreen_video_feed_screen_test.dart test/screens/feed/video_feed_page_test.dart test/screens/feed/feed_video_overlay_test.dart test/widgets/video_feed_item/actions`

Expected: PASS.

- [ ] **Step 6: Commit the home-feed slice**

```bash
git add \
  mobile/lib/screens/feed/video_feed_page.dart \
  mobile/lib/screens/feed/feed_video_overlay.dart \
  mobile/test/screens/feed/video_feed_page_test.dart \
  mobile/test/screens/feed/feed_video_overlay_test.dart
git commit -m "feat(feed): add in-feed auto advance behavior"
```

## Final Verification

- [ ] Run: `flutter test test/screens/feed/pooled_fullscreen_video_feed_screen_test.dart test/screens/feed/video_feed_page_test.dart test/screens/feed/feed_video_overlay_test.dart test/widgets/video_feed_item/actions`
- [ ] Run: `git status --short`
- [ ] Confirm only intended files are modified
- [ ] If localization files changed, confirm generated l10n outputs are staged too
- [ ] Review the combined diff before opening implementation PR
