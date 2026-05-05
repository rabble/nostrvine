# Video Comments Revival Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Revive the half-shipped "post a video as a reply to a video" feature behind a `videoReplies` feature flag (default off), including the missing inline display of video comments in the comments sheet, without merging the stale `feat/video-comments-clean` branch (521 commits behind main).

> **2026-05-04 amendment:** Pre-flight verification (see Chunk 0) revealed that the comments sheet on main does NOT render video comments inline — `comment_item.dart` is text-only. The profile tab's `ProfileCommentsState.videoReplies` ships with display, but the in-feed comments sheet does not. Without inline display, a flag-on user posts a video reply and sees nothing appear in the very sheet they posted into. Display work has therefore been folded into this plan as Chunk 5; subsequent chunks renumbered.

**Architecture:** Reuse the existing recorder, editor, and clip pipeline unchanged. A `VideoReplyCubit` (state: `VideoReplyContext?`) provided at the app root holds the reply intent across navigation. At editor confirmation, a small `VideoReplyPublisher` reads the cubit and either hands off to `VideoCommentPublishService` (Blossom upload → NIP-92 imeta → Kind 1111 comment via `CommentsRepository`) or returns false so the editor falls through to the existing metadata-screen → Kind 34236 path. The editor itself stays unaware of replies.

**State management policy:** Per CLAUDE.md, new code is BLoC/Cubit; Riverpod is legacy only. The recorder (`video_recorder_provider.dart`) and editor (`video_editor_provider.dart`) are existing Riverpod and we deliberately do NOT migrate them in this plan — that is a separate effort. The seam between them and the new Cubit-based reply state is at the **widget/screen layer**, where `context` can read both `Ref` (via `ConsumerStatefulWidget`) and `BlocProvider`. The new code path (cubit, service, publisher, comment-input wiring) is 100% BLoC/Cubit and `RepositoryProvider`-injected; no new Riverpod providers are added.

**Tech Stack:** Flutter, `flutter_bloc` + `bloc_test` (all new code), Riverpod (read-only interop with the legacy recorder/editor at the widget layer), Nostr (NIP-22 Kind 1111 comments + NIP-92 imeta video metadata), Blossom (CDN/storage).

---

## Non-Goals (explicitly out of scope)

To prevent scope creep:

- **No new editor UI for replies.** No "replying to @user" banner, no shorter duration cap, no different post-button label. The editor is identical to a normal post until the moment of publish.
- **No metadata screen for replies.** Captions/hashtags/collaborators are not added to video replies in this iteration. We intentionally skip the metadata screen on the reply path. (If product later wants this, the divergence point is documented and tested.)
- ~~**No display work in this plan.**~~ **Display work IS in this plan** (Chunk 5). The Comment model on main has `videoUrl`, `thumbnailUrl`, `hasVideo`, etc., but `comment_item.dart` does not branch on those fields. We add a `CommentVideoPlayer` widget and a render branch in `CommentItem`. The profile tab's video-reply rendering remains as it is — out of scope for this plan.
- **No backend changes.** Funnelcake / relay already accept Kind 1111 with imeta tags.

## Debt Rules (must hold throughout)

These are the rules called out before approving the work. Every reviewer should check the implementation against them:

1. **`VideoReplyCubit` must be cleared on every exit path** — back button, cancel from recorder, cancel from editor, app resume to a non-reply route. Not just on successful publish. There MUST be a regression test for "start reply → cancel → start normal post → cubit state is null."
2. **No bloat in `video_editor_provider.dart`.** The editor decides "I have a rendered clip"; it must not know about Kind 1111 vs 34236. Routing the rendered clip is `VideoReplyPublisher`'s job (a thin class), and the actual upload+publish is `VideoCommentPublishService`'s job.
3. **One repository method, extended.** `CommentsRepository.postComment()` gains optional video-metadata params and emits NIP-92 imeta tags inline. No parallel `postVideoComment()` method.
4. **The flag has an exit criterion.** PR description must state "remove flag once X% rollout stable for 2 weeks." Open a tracking issue at PR time.
5. **Tests are written fresh against current main.** Do not port the stale tests from `feat/video-comments-clean`. Reference them only for intent.
6. **Skipping the metadata screen for replies is an explicit tested behavior**, not an accident.
7. **No new Riverpod providers.** All new state lives in a Cubit; all new services are injected via `RepositoryProvider` or constructor. The legacy recorder/editor Riverpod code stays untouched — interop happens only at the widget/screen layer.

---

## File Structure

### New Files

| Path | Responsibility |
|---|---|
| `mobile/lib/models/video_reply_context.dart` | Plain immutable data class: `rootEventId`, `rootEventKind`, `rootAuthorPubkey`, `rootAddressableId`, `parentCommentId?`, `parentAuthorPubkey?`. No behavior. |
| `mobile/lib/blocs/video_reply/video_reply_cubit.dart` | `Cubit<VideoReplyContext?>` with explicit `start(VideoReplyContext)` and `clear()` methods. Provided at the app root so it survives navigation between comments sheet → recorder → editor. |
| `mobile/lib/services/video_comment_publish_service.dart` | Stateless service: takes a rendered clip path + reply context + comment text → uploads to Blossom → builds NIP-92 imeta → calls `CommentsRepository.postComment()`. Owns the publish flow end-to-end. Plain Dart class, no Riverpod, injected via constructor. |
| `mobile/lib/services/video_reply_publisher.dart` | Thin class (~40 lines) called from the editor's "Done" handler. Constructor-injected with `VideoReplyCubit`, `VideoCommentPublishService`, and a `Future<String?> Function() getRenderedClipPath` callback that lets the caller (a `ConsumerStatefulWidget`) bridge to the legacy Riverpod editor without leaking `Ref` into this class. Returns `Future<bool>` — `true` if it consumed the clip; `false` means proceed to metadata screen. |
| `mobile/packages/comments_repository/lib/src/models/video_comment_media.dart` | Optional value type passed to `postComment()`: `url`, `sha256`, `mimeType`, `dimWidth`, `dimHeight`, `durationSeconds`, `thumbnailUrl?`, `blurhash?`. Pure data. |
| `mobile/lib/screens/comments/widgets/comment_video_player.dart` | Inline video player for a comment item. Takes the comment's video URL, thumbnail, blurhash, and dimensions and renders a tap-to-play preview. Reuses the project's existing video-player primitives (verify exact widget in pre-flight — likely the same player used elsewhere for inline playback). Constrained aspect ratio matching the comment's `videoDimensions`. |

### Modified Files

| Path | Change |
|---|---|
| `mobile/lib/features/feature_flags/models/feature_flag.dart` | Add `videoReplies('Video Replies', 'Allow recording and posting video replies in comments')` enum entry. |
| `mobile/lib/features/feature_flags/services/build_configuration.dart` | Add switch case `case FeatureFlag.videoReplies: return const bool.fromEnvironment('FF_VIDEO_REPLIES');` plus the env-key mapping case. Default `false`. |
| `mobile/packages/comments_repository/lib/src/comments_repository.dart` | `postComment()` gains optional `VideoCommentMedia? video` parameter. When present, adds NIP-92 `imeta` tag to the Kind 1111 event. |
| `mobile/packages/comments_repository/lib/comments_repository.dart` | Export `VideoCommentMedia` from barrel. |
| `mobile/lib/screens/comments/widgets/comment_input.dart` | Add optional `VoidCallback? onVideoReply`. When non-null, render a video-reply icon next to send. |
| `mobile/lib/screens/comments/widgets/comment_item.dart` | Branch on `comment.hasVideo`: when true, render `CommentVideoPlayer` above (or in place of) the existing text content; when false, render exactly as today. (Confirmed text-only on main as of pre-flight.) |
| `mobile/lib/screens/comments/comments_screen.dart` (or its caller — see pre-flight findings) | Read the flag; if on, pass `onVideoReply` that calls `context.read<VideoReplyCubit>().start(...)`, dismisses the sheet, and pushes the recorder route. The sheet is opened via `CommentsScreen.show(context, video)` from `pooled_fullscreen_video_feed_screen.dart:649` — wire the recorder navigation in the `whenComplete` of that call (or directly from the callback if simpler). |
| `mobile/lib/widgets/video_editor/main_editor/video_editor_canvas.dart:721` | At the existing `await context.push(VideoMetadataScreen.path)` site, first call `VideoReplyPublisher.handleEditorDone()`. If it returns `true`, do not push the metadata screen. The publisher is read via `context.read<VideoReplyPublisher>()`; the rendered-clip callback bridges to the Riverpod editor via `ref.read(videoEditorProvider).state.finalRenderedClip`. |
| `mobile/lib/screens/video_recorder_screen.dart` | In `dispose()` and the cancel handler, call `context.read<VideoReplyCubit>().clear()` to satisfy debt rule #1. The Riverpod recorder *notifier* itself is NOT modified — clearing happens at the screen widget layer where both `Ref` and `BlocProvider` are reachable. |
| `mobile/lib/main.dart` (root `MultiRepositoryProvider` at line 1590, `MultiBlocProvider` at line 1632 — verified in pre-flight) | Provide `VideoReplyCubit` (under `MultiBlocProvider`) and `VideoCommentPublishService` (under `MultiRepositoryProvider`) at the root so they survive navigation. |

### Test Files (mirror)

- `mobile/test/models/video_reply_context_test.dart`
- `mobile/test/blocs/video_reply/video_reply_cubit_test.dart` (uses `bloc_test`)
- `mobile/test/services/video_comment_publish_service_test.dart`
- `mobile/test/services/video_reply_publisher_test.dart`
- `mobile/packages/comments_repository/test/src/comments_repository_video_test.dart`
- `mobile/test/screens/comments/widgets/comment_input_video_reply_test.dart`
- `mobile/test/screens/comments/widgets/comment_video_player_test.dart`
- `mobile/test/screens/comments/widgets/comment_item_video_render_test.dart`
- `mobile/test/screens/comments/comments_screen_video_reply_entry_test.dart`
- `mobile/test/features/feature_flags/video_replies_flag_test.dart`

---

## Pre-Flight Verification Findings (2026-05-04)

Recorded so the rest of the plan and any subsequent reviewers can rely on these:

| Plan assumption | Verified location on `origin/main` |
|---|---|
| `FeatureFlag` enum | `mobile/lib/features/feature_flags/models/feature_flag.dart:4` |
| `CommentsRepository.postComment` | `mobile/packages/comments_repository/lib/src/comments_repository.dart:215` |
| Editor "Done" → metadata push | `mobile/lib/widgets/video_editor/main_editor/video_editor_canvas.dart:721` (`await context.push(VideoMetadataScreen.path)`) |
| Editor rendered-clip accessor | `videoEditorProvider`'s state exposes `finalRenderedClip` (see `video_editor_provider.dart:96, 849, 917`) |
| Comments sheet entry | `CommentsScreen.show(context, video)` (modal, used at `pooled_fullscreen_video_feed_screen.dart:649`) |
| `VideoMetadataScreen` location | `mobile/lib/screens/video_metadata/video_metadata_screen.dart` |
| Recorder screen | `mobile/lib/screens/video_recorder_screen.dart` |
| App-root providers | `mobile/lib/main.dart` — `MultiRepositoryProvider` at line 1590, `MultiBlocProvider` at line 1632 |
| Pre-existing `videoReplies` display | Profile only: `mobile/lib/blocs/profile_comments/profile_comments_state.dart:27` (NOT comments sheet) |
| Comment model video fields | `comment.dart:61` `videoUrl`, `:64` `thumbnailUrl`, `:76` `hasVideo` getter |

**Outstanding setup item:** The fresh worktree at `/Users/rabble/code/divine/divine-mobile-video-comments` does NOT have git hooks installed. Run `mise run setup_hooks` from `mobile/` before the first commit.

---

## Chunk 0: Pre-Flight & Worktree Setup

### Task 0.1: Create worktree

**Files:** none

- [ ] **Step 1: Create the worktree off `main`**

```bash
cd /Users/rabble/code/divine/divine-mobile
git fetch origin main
git worktree add ../divine-mobile-video-comments -b feat/video-comments-revival origin/main
cd ../divine-mobile-video-comments/mobile
```

- [ ] **Step 2: Verify hooks installed**

Run: `mise run setup_hooks`
Expected: pre-commit and pre-push hooks present in `.git/hooks/`.

- [ ] **Step 3: Get dependencies**

Run: `flutter pub get`
Expected: success.

### Task 0.2: Verify current-state assumptions

This branch was 521 commits behind main when researched. Verify the file paths still match before writing code; correct them in the plan if they have moved.

- [ ] **Step 1: Confirm feature-flag enum location**

Run: `grep -rn "enum FeatureFlag" mobile/lib/features/feature_flags/`
Expected: hits in `models/feature_flag.dart`. If file has moved, update plan.

- [ ] **Step 2: Confirm `CommentsRepository.postComment` signature**

Run: `grep -n "Future.*postComment" mobile/packages/comments_repository/lib/src/comments_repository.dart`
Expected: a method that builds and publishes a Kind 1111 event with NIP-22 threading tags. Read it end-to-end before extending.

- [ ] **Step 3: Locate the editor "Done" handler**

Run: `grep -rn "_handleDone\|onDone\|onConfirm" mobile/lib/screens/video_editor/`
Expected: a single confirm path on the editor canvas. Note its file:line for Chunk 6.

- [ ] **Step 4: Confirm comments screen still uses a modal/bottom-sheet pattern with `whenComplete`**

Run: `grep -n "whenComplete\|showModalBottomSheet" mobile/lib/screens/comments/comments_screen.dart`
Expected: a modal dismissal hook we can use for "after sheet closed, navigate to recorder if reply context set." If the comments screen has been migrated off a modal pattern, the entry-point wiring in Chunk 5 needs to move to wherever the comment input now lives.

- [x] **Step 5: Confirm the comments screen does NOT need new display widgets** *(resolved 2026-05-04)*

Run: `grep -rn "videoReplies\|VideoCommentPlayer" mobile/lib/screens/comments/`
Result on `origin/main` at `c5ed3eadd`: **no display for video comments in the comments sheet.** The profile tab renders video replies, the comments sheet does not. Display work has been folded into Chunk 5 of this plan (decision: 2026-05-04).

---

## Chunk 1: Feature Flag Wiring

Foundation for everything else. Ship this commit first; nothing else activates until it's in place.

### Task 1.1: Add `videoReplies` enum entry

**Files:**
- Modify: `mobile/lib/features/feature_flags/models/feature_flag.dart`
- Test: `mobile/test/features/feature_flags/video_replies_flag_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:divine_mobile/features/feature_flags/models/feature_flag.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FeatureFlag.videoReplies', () {
    test('exists and has descriptive metadata', () {
      const flag = FeatureFlag.videoReplies;
      expect(flag.displayName, equals('Video Replies'));
      expect(flag.description, contains('video'));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/feature_flags/video_replies_flag_test.dart`
Expected: FAIL — `videoReplies` is not a member of FeatureFlag.

- [ ] **Step 3: Add the enum entry**

In `mobile/lib/features/feature_flags/models/feature_flag.dart`, add to the enum body:

```dart
videoReplies(
  'Video Replies',
  'Allow recording and posting video replies in comments',
),
```

Place it alphabetically or grouped with other camera/video flags — match the file's existing convention.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/feature_flags/video_replies_flag_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/features/feature_flags/models/feature_flag.dart mobile/test/features/feature_flags/video_replies_flag_test.dart
git commit -m "feat(feature-flags): add videoReplies flag enum entry"
```

### Task 1.2: Wire env var in BuildConfiguration

**Files:**
- Modify: `mobile/lib/features/feature_flags/services/build_configuration.dart`
- Test: append to `mobile/test/features/feature_flags/video_replies_flag_test.dart`

- [ ] **Step 1: Add the failing test**

```dart
test('BuildConfiguration default for videoReplies is false', () {
  expect(
    BuildConfiguration.getDefault(FeatureFlag.videoReplies),
    isFalse,
  );
});

test('BuildConfiguration env key for videoReplies is FF_VIDEO_REPLIES', () {
  expect(
    BuildConfiguration.getEnvironmentKey(FeatureFlag.videoReplies),
    equals('FF_VIDEO_REPLIES'),
  );
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/feature_flags/video_replies_flag_test.dart`
Expected: FAIL — switch is not exhaustive / case missing.

- [ ] **Step 3: Add the switch cases**

In `build_configuration.dart`, add cases mirroring the existing pattern:

```dart
case FeatureFlag.videoReplies:
  return const bool.fromEnvironment('FF_VIDEO_REPLIES');
```

And in `getEnvironmentKey`:

```dart
case FeatureFlag.videoReplies:
  return 'FF_VIDEO_REPLIES';
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/feature_flags/video_replies_flag_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/features/feature_flags/services/build_configuration.dart mobile/test/features/feature_flags/video_replies_flag_test.dart
git commit -m "feat(feature-flags): wire FF_VIDEO_REPLIES env var"
```

---

## Chunk 2: Reply Context Model + Cubit

### Task 2.1: `VideoReplyContext` model

**Files:**
- Create: `mobile/lib/models/video_reply_context.dart`
- Test: `mobile/test/models/video_reply_context_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:divine_mobile/models/video_reply_context.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VideoReplyContext', () {
    test('values are equatable', () {
      const a = VideoReplyContext(
        rootEventId: 'a' * 64,
        rootEventKind: 34236,
        rootAuthorPubkey: 'b' * 64,
        rootAddressableId: '34236:${'b' * 64}:dtag',
      );
      const b = VideoReplyContext(
        rootEventId: 'a' * 64,
        rootEventKind: 34236,
        rootAuthorPubkey: 'b' * 64,
        rootAddressableId: '34236:${'b' * 64}:dtag',
      );
      expect(a, equals(b));
    });

    test('parent fields default to null for top-level reply', () {
      const ctx = VideoReplyContext(
        rootEventId: 'a' * 64,
        rootEventKind: 34236,
        rootAuthorPubkey: 'b' * 64,
        rootAddressableId: '34236:${'b' * 64}:dtag',
      );
      expect(ctx.parentCommentId, isNull);
      expect(ctx.parentAuthorPubkey, isNull);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/models/video_reply_context_test.dart`
Expected: FAIL — file does not exist.

- [ ] **Step 3: Implement the model**

```dart
import 'package:equatable/equatable.dart';

class VideoReplyContext extends Equatable {
  const VideoReplyContext({
    required this.rootEventId,
    required this.rootEventKind,
    required this.rootAuthorPubkey,
    required this.rootAddressableId,
    this.parentCommentId,
    this.parentAuthorPubkey,
  });

  final String rootEventId;
  final int rootEventKind;
  final String rootAuthorPubkey;
  final String rootAddressableId;
  final String? parentCommentId;
  final String? parentAuthorPubkey;

  @override
  List<Object?> get props => [
        rootEventId,
        rootEventKind,
        rootAuthorPubkey,
        rootAddressableId,
        parentCommentId,
        parentAuthorPubkey,
      ];
}
```

Per CLAUDE.md: never truncate Nostr IDs.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/models/video_reply_context_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/models/video_reply_context.dart mobile/test/models/video_reply_context_test.dart
git commit -m "feat(models): add VideoReplyContext"
```

### Task 2.2: `VideoReplyCubit` with explicit clear

**Files:**
- Create: `mobile/lib/blocs/video_reply/video_reply_cubit.dart`
- Test: `mobile/test/blocs/video_reply/video_reply_cubit_test.dart`

Per CLAUDE.md, all new state is BLoC/Cubit. This cubit is provided at the app root (Task 2.3) so reply intent persists across the comments-sheet → recorder → editor navigation. State is `VideoReplyContext?` — null means "no reply in progress."

- [ ] **Step 1: Write the failing test**

```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:divine_mobile/blocs/video_reply/video_reply_cubit.dart';
import 'package:divine_mobile/models/video_reply_context.dart';
import 'package:flutter_test/flutter_test.dart';

VideoReplyContext _ctx() => const VideoReplyContext(
      rootEventId: 'a' * 64,
      rootEventKind: 34236,
      rootAuthorPubkey: 'b' * 64,
      rootAddressableId: '34236:${'b' * 64}:dtag',
    );

void main() {
  group(VideoReplyCubit, () {
    test('initial state is null', () {
      expect(VideoReplyCubit().state, isNull);
    });

    blocTest<VideoReplyCubit, VideoReplyContext?>(
      'start emits the context',
      build: VideoReplyCubit.new,
      act: (cubit) => cubit.start(_ctx()),
      expect: () => [_ctx()],
    );

    blocTest<VideoReplyCubit, VideoReplyContext?>(
      'clear emits null after a context was set',
      build: VideoReplyCubit.new,
      act: (cubit) => cubit
        ..start(_ctx())
        ..clear(),
      expect: () => [_ctx(), isNull],
    );

    blocTest<VideoReplyCubit, VideoReplyContext?>(
      'regression: start → clear → no further emissions before next start; '
      'subsequent normal-post flow does NOT see leftover context',
      build: VideoReplyCubit.new,
      act: (cubit) => cubit
        ..start(_ctx())
        ..clear(),
      verify: (cubit) => expect(cubit.state, isNull),
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/blocs/video_reply/video_reply_cubit_test.dart`
Expected: FAIL — cubit does not exist.

- [ ] **Step 3: Implement the cubit**

```dart
import 'package:bloc/bloc.dart';
import 'package:divine_mobile/models/video_reply_context.dart';

class VideoReplyCubit extends Cubit<VideoReplyContext?> {
  VideoReplyCubit() : super(null);

  void start(VideoReplyContext context) => emit(context);
  void clear() => emit(null);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/blocs/video_reply/video_reply_cubit_test.dart`
Expected: PASS — including the regression test.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/blocs/video_reply mobile/test/blocs/video_reply
git commit -m "feat(video-reply): add VideoReplyCubit with clear semantics"
```

### Task 2.3: Provide `VideoReplyCubit` at app root

**Files:**
- Modify: app-root provider widget (verify in Task 0.2 — typically `mobile/lib/main.dart` or a top-level `App` widget that owns `MultiBlocProvider`).

This is a structural change so the cubit survives navigation between comments → recorder → editor. Without this step the cubit would be re-created at each screen and reply intent would not propagate.

- [ ] **Step 1: Locate the existing root `MultiBlocProvider`** (or equivalent). Add an entry:

```dart
BlocProvider<VideoReplyCubit>(
  create: (_) => VideoReplyCubit(),
),
```

- [ ] **Step 2: Smoke-test that the app still launches**

Run: `cd mobile && flutter run -d <device>` (or `flutter test integration_test/app_smoke_test.dart` if one exists)
Expected: app launches without provider-not-found errors.

- [ ] **Step 3: Commit**

```bash
git add mobile/lib/main.dart # or wherever providers live
git commit -m "feat(app): provide VideoReplyCubit at root"
```

---

## Chunk 3: Repository Layer — Extend `postComment` with Optional Imeta

### Task 3.1: `VideoCommentMedia` value type

**Files:**
- Create: `mobile/packages/comments_repository/lib/src/models/video_comment_media.dart`
- Modify: `mobile/packages/comments_repository/lib/src/models/models.dart` (barrel)
- Modify: `mobile/packages/comments_repository/lib/comments_repository.dart` (top-level barrel)
- Test: `mobile/packages/comments_repository/test/src/models/video_comment_media_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:comments_repository/comments_repository.dart';
import 'package:test/test.dart';

void main() {
  group('VideoCommentMedia', () {
    test('builds NIP-92 imeta tag values', () {
      const media = VideoCommentMedia(
        url: 'https://blossom.example/abc.mp4',
        sha256: 'd' * 64,
        mimeType: 'video/mp4',
        dimWidth: 720,
        dimHeight: 1280,
        durationSeconds: 6,
        thumbnailUrl: 'https://blossom.example/abc.jpg',
        blurhash: 'LKO2?U%2Tw=w',
      );
      final values = media.toImetaTagValues();
      expect(values, contains('url https://blossom.example/abc.mp4'));
      expect(values, contains('x ${'d' * 64}'));
      expect(values, contains('m video/mp4'));
      expect(values, contains('dim 720x1280'));
      expect(values, contains('image https://blossom.example/abc.jpg'));
      expect(values, contains('blurhash LKO2?U%2Tw=w'));
    });

    test('omits optional values when absent', () {
      const media = VideoCommentMedia(
        url: 'https://blossom.example/abc.mp4',
        sha256: 'd' * 64,
        mimeType: 'video/mp4',
        dimWidth: 720,
        dimHeight: 1280,
        durationSeconds: 6,
      );
      final values = media.toImetaTagValues();
      expect(values.any((v) => v.startsWith('image ')), isFalse);
      expect(values.any((v) => v.startsWith('blurhash ')), isFalse);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile/packages/comments_repository && dart test test/src/models/video_comment_media_test.dart`
Expected: FAIL — type not defined.

- [ ] **Step 3: Implement the value type**

```dart
import 'package:equatable/equatable.dart';

class VideoCommentMedia extends Equatable {
  const VideoCommentMedia({
    required this.url,
    required this.sha256,
    required this.mimeType,
    required this.dimWidth,
    required this.dimHeight,
    required this.durationSeconds,
    this.thumbnailUrl,
    this.blurhash,
  });

  final String url;
  final String sha256;
  final String mimeType;
  final int dimWidth;
  final int dimHeight;
  final int durationSeconds;
  final String? thumbnailUrl;
  final String? blurhash;

  /// NIP-92 imeta tag values: each entry is a "key value" string,
  /// laid out per the spec.
  List<String> toImetaTagValues() {
    return [
      'url $url',
      'x $sha256',
      'm $mimeType',
      'dim ${dimWidth}x$dimHeight',
      'duration $durationSeconds',
      if (thumbnailUrl != null) 'image $thumbnailUrl',
      if (blurhash != null) 'blurhash $blurhash',
    ];
  }

  @override
  List<Object?> get props => [
        url,
        sha256,
        mimeType,
        dimWidth,
        dimHeight,
        durationSeconds,
        thumbnailUrl,
        blurhash,
      ];
}
```

Verify the exact NIP-92 field names against `mcp__nostrbook__read_nip` for NIP-92 if there is any doubt — do not guess.

- [ ] **Step 4: Update barrels**

```dart
// models.dart
export 'video_comment_media.dart';
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd mobile/packages/comments_repository && dart test test/src/models/video_comment_media_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add mobile/packages/comments_repository/lib mobile/packages/comments_repository/test/src/models
git commit -m "feat(comments-repository): add VideoCommentMedia value type"
```

### Task 3.2: Extend `postComment` to accept optional video metadata

**Files:**
- Modify: `mobile/packages/comments_repository/lib/src/comments_repository.dart`
- Test: `mobile/packages/comments_repository/test/src/comments_repository_video_test.dart`

- [ ] **Step 1: Write failing tests**

```dart
import 'package:comments_repository/comments_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart'; // adjust per actual import
import 'package:test/test.dart';

class _MockNostrClient extends Mock implements NostrClient {}

VideoCommentMedia _media() => const VideoCommentMedia(
      url: 'https://blossom.example/abc.mp4',
      sha256: 'd' * 64,
      mimeType: 'video/mp4',
      dimWidth: 720,
      dimHeight: 1280,
      durationSeconds: 6,
    );

void main() {
  late _MockNostrClient client;
  late CommentsRepository repo;

  setUp(() {
    client = _MockNostrClient();
    repo = CommentsRepository(nostrClient: client);
    // Stub publishEvent — exact API depends on current main.
  });

  group('postComment with video', () {
    test('without video param, no imeta tag is emitted', () async {
      await repo.postComment(/* required args */, content: 'hi');
      final captured = verify(() => client.publishEvent(captureAny()))
          .captured
          .single as NostrEvent;
      expect(
        captured.tags.any((t) => t.first == 'imeta'),
        isFalse,
      );
    });

    test('with video param, an imeta tag is emitted with NIP-92 fields',
        () async {
      await repo.postComment(
        /* required args */,
        content: 'check this',
        video: _media(),
      );
      final captured = verify(() => client.publishEvent(captureAny()))
          .captured
          .single as NostrEvent;
      final imeta = captured.tags.firstWhere((t) => t.first == 'imeta');
      expect(imeta, contains('url https://blossom.example/abc.mp4'));
      expect(imeta, contains('x ${'d' * 64}'));
      expect(imeta, contains('dim 720x1280'));
    });

    test('event kind remains 1111 even when video is present', () async {
      await repo.postComment(
        /* required args */,
        content: 'check this',
        video: _media(),
      );
      final captured = verify(() => client.publishEvent(captureAny()))
          .captured
          .single as NostrEvent;
      expect(captured.kind, equals(1111));
    });
  });
}
```

The exact `postComment` argument list and `NostrClient.publishEvent` shape must be read from the current main file before writing. Adjust the test to match.

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd mobile/packages/comments_repository && dart test test/src/comments_repository_video_test.dart`
Expected: FAIL — `video` parameter not defined.

- [ ] **Step 3: Extend the method**

In `comments_repository.dart`, add a parameter:

```dart
Future<Comment> postComment({
  // ... existing params unchanged ...
  required String content,
  VideoCommentMedia? video,
}) async {
  final tags = <List<String>>[
    // ... existing NIP-22 threading tags unchanged ...
    if (video != null) ['imeta', ...video.toImetaTagValues()],
  ];
  // ... rest of existing implementation unchanged ...
}
```

The `imeta` tag form (`['imeta', 'url ...', 'x ...', ...]`) is per NIP-92.

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd mobile/packages/comments_repository && dart test`
Expected: PASS — including all *existing* tests (we did not change non-video behavior).

- [ ] **Step 5: Commit**

```bash
git add mobile/packages/comments_repository
git commit -m "feat(comments-repository): postComment accepts optional video imeta"
```

---

## Chunk 4: Publish Service + Reply Publisher

### Task 4.1: `VideoCommentPublishService`

**Files:**
- Create: `mobile/lib/services/video_comment_publish_service.dart`
- Test: `mobile/test/services/video_comment_publish_service_test.dart`

The service is **the only place that knows about both Blossom and `CommentsRepository`**. The editor must not. The publisher (next task) must not. Plain Dart class, no Riverpod, no BLoC — pure constructor injection so it's trivially mockable.

- [ ] **Step 1: Write failing tests**

Tests to cover:
1. Successful path: render path + reply context → uploads file → calls `postComment` with the resulting `VideoCommentMedia`.
2. Blossom upload failure → throws `VideoCommentPublishException`; `postComment` is never called.
3. Comment publish failure → throws `VideoCommentPublishException` with the underlying error chained.
4. The `CommentsRepository.postComment` call uses the reply context's `rootEventId`/`rootAuthorPubkey`/`rootAddressableId`/`rootEventKind` in NIP-22 root tags.

Use `mocktail` mocks for `BlossomUploadService` and `CommentsRepository`. Patterns are visible in existing service tests.

- [ ] **Step 2: Run tests — all should FAIL** (file doesn't exist).

- [ ] **Step 3: Implement the service**

Outline only — fill in concrete types from the existing `BlossomUploadService` and `CommentsRepository` APIs:

```dart
class VideoCommentPublishService {
  VideoCommentPublishService({
    required BlossomUploadService blossom,
    required CommentsRepository commentsRepository,
  })  : _blossom = blossom,
        _commentsRepository = commentsRepository;

  final BlossomUploadService _blossom;
  final CommentsRepository _commentsRepository;

  Future<Comment> publish({
    required String renderedFilePath,
    required VideoReplyContext replyContext,
    required String content,
  }) async {
    final uploaded = await _blossom.upload(File(renderedFilePath));
    final media = VideoCommentMedia(
      url: uploaded.url,
      sha256: uploaded.sha256,
      mimeType: uploaded.mimeType,
      dimWidth: uploaded.width,
      dimHeight: uploaded.height,
      durationSeconds: uploaded.durationSeconds,
      thumbnailUrl: uploaded.thumbnailUrl,
      blurhash: uploaded.blurhash,
    );
    return _commentsRepository.postComment(
      // map root* and parent* fields from replyContext
      content: content,
      video: media,
    );
  }
}

class VideoCommentPublishException implements Exception {
  VideoCommentPublishException(this.message, {this.cause});
  final String message;
  final Object? cause;
  @override
  String toString() => 'VideoCommentPublishException: $message';
}
```

- [ ] **Step 4: Run tests — should PASS.**

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/services/video_comment_publish_service.dart mobile/test/services/video_comment_publish_service_test.dart
git commit -m "feat(services): add VideoCommentPublishService (Blossom + Kind 1111)"
```

### Task 4.2: `VideoReplyPublisher`

**Files:**
- Create: `mobile/lib/services/video_reply_publisher.dart`
- Test: `mobile/test/services/video_reply_publisher_test.dart`

Thin seam between editor and publish service. Reading this file should make the entire reply path obvious to a future maintainer. **No `Ref` here** — the publisher takes the cubit, the service, and a callback the caller uses to bridge to the legacy Riverpod editor for the rendered clip. This keeps the publisher trivially unit-testable with plain mocks (no `ProviderContainer`).

- [ ] **Step 1: Write failing tests**

```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:divine_mobile/blocs/video_reply/video_reply_cubit.dart';
import 'package:divine_mobile/models/video_reply_context.dart';
import 'package:divine_mobile/services/video_comment_publish_service.dart';
import 'package:divine_mobile/services/video_reply_publisher.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockService extends Mock implements VideoCommentPublishService {}
class _MockCubit extends MockCubit<VideoReplyContext?>
    implements VideoReplyCubit {}

VideoReplyContext _ctx() => const VideoReplyContext(
      rootEventId: 'a' * 64,
      rootEventKind: 34236,
      rootAuthorPubkey: 'b' * 64,
      rootAddressableId: '34236:${'b' * 64}:dtag',
    );

void main() {
  late _MockCubit cubit;
  late _MockService service;

  setUp(() {
    cubit = _MockCubit();
    service = _MockService();
  });

  group(VideoReplyPublisher, () {
    test('with no reply context, returns false; service not called', () async {
      when(() => cubit.state).thenReturn(null);
      final publisher = VideoReplyPublisher(
        cubit: cubit,
        service: service,
        getRenderedClipPath: () async => '/tmp/clip.mp4',
      );
      expect(await publisher.handleEditorDone(), isFalse);
      verifyNever(() => service.publish(
            renderedFilePath: any(named: 'renderedFilePath'),
            replyContext: any(named: 'replyContext'),
            content: any(named: 'content'),
          ));
    });

    test('with reply context, publishes and clears cubit, returns true',
        () async {
      when(() => cubit.state).thenReturn(_ctx());
      when(() => service.publish(
            renderedFilePath: any(named: 'renderedFilePath'),
            replyContext: any(named: 'replyContext'),
            content: any(named: 'content'),
          )).thenAnswer((_) async => /* a Comment fixture */);
      final publisher = VideoReplyPublisher(
        cubit: cubit,
        service: service,
        getRenderedClipPath: () async => '/tmp/clip.mp4',
      );
      expect(await publisher.handleEditorDone(), isTrue);
      verify(() => cubit.clear()).called(1);
    });

    test(
      'on publish failure, cubit is STILL cleared and the error rethrown '
      '(debt rule #1)',
      () async {
        when(() => cubit.state).thenReturn(_ctx());
        when(() => service.publish(
              renderedFilePath: any(named: 'renderedFilePath'),
              replyContext: any(named: 'replyContext'),
              content: any(named: 'content'),
            )).thenThrow(Exception('blossom down'));
        final publisher = VideoReplyPublisher(
          cubit: cubit,
          service: service,
          getRenderedClipPath: () async => '/tmp/clip.mp4',
        );
        await expectLater(publisher.handleEditorDone(), throwsException);
        verify(() => cubit.clear()).called(1);
      },
    );

    test('returns false if rendered clip path is null', () async {
      when(() => cubit.state).thenReturn(_ctx());
      final publisher = VideoReplyPublisher(
        cubit: cubit,
        service: service,
        getRenderedClipPath: () async => null,
      );
      expect(await publisher.handleEditorDone(), isFalse);
    });
  });
}
```

- [ ] **Step 2: Run tests — should FAIL.**

- [ ] **Step 3: Implement**

```dart
import 'package:divine_mobile/blocs/video_reply/video_reply_cubit.dart';
import 'package:divine_mobile/services/video_comment_publish_service.dart';

typedef GetRenderedClipPath = Future<String?> Function();

class VideoReplyPublisher {
  VideoReplyPublisher({
    required VideoReplyCubit cubit,
    required VideoCommentPublishService service,
    required GetRenderedClipPath getRenderedClipPath,
  })  : _cubit = cubit,
        _service = service,
        _getRenderedClipPath = getRenderedClipPath;

  final VideoReplyCubit _cubit;
  final VideoCommentPublishService _service;
  final GetRenderedClipPath _getRenderedClipPath;

  /// Returns `true` iff the publisher consumed the rendered clip
  /// (caller should NOT proceed to the metadata screen).
  Future<bool> handleEditorDone() async {
    final replyContext = _cubit.state;
    if (replyContext == null) return false;

    final clipPath = await _getRenderedClipPath();
    if (clipPath == null) return false;

    try {
      await _service.publish(
        renderedFilePath: clipPath,
        replyContext: replyContext,
        content: '', // Phase 1: no caption on replies.
      );
    } finally {
      _cubit.clear();
    }
    return true;
  }
}
```

The `getRenderedClipPath` callback is the only seam to the legacy Riverpod editor. The widget that constructs `VideoReplyPublisher` (or wires it via `RepositoryProvider`) supplies a callback that does `ref.read(videoEditorProvider).finalRenderedClipPath`. Confirm that exact accessor against current main in Task 0.2.

- [ ] **Step 4: Run tests — should PASS.**

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/services/video_reply_publisher.dart mobile/test/services/video_reply_publisher_test.dart
git commit -m "feat(services): add VideoReplyPublisher seam (BLoC-aware, no Ref)"
```

### Task 4.3: Provide service + publisher via `RepositoryProvider`

**Files:**
- Modify: app-root provider widget (same one as Task 2.3)

`VideoCommentPublishService` needs `BlossomUploadService` and `CommentsRepository` from existing repository providers. `VideoReplyPublisher` needs the cubit (already provided via `BlocProvider`), the service, and the rendered-clip callback. Because the callback must close over `Ref` for the legacy editor, the publisher is constructed inside the editor screen (a `ConsumerStatefulWidget`) rather than at the app root — see Chunk 6.

- [ ] **Step 1: Add `RepositoryProvider<VideoCommentPublishService>` at root**

```dart
RepositoryProvider<VideoCommentPublishService>(
  create: (context) => VideoCommentPublishService(
    blossom: context.read<BlossomUploadService>(),
    commentsRepository: context.read<CommentsRepository>(),
  ),
),
```

- [ ] **Step 2: Smoke-test that the app still launches.**

- [ ] **Step 3: Commit**

```bash
git commit -m "feat(app): provide VideoCommentPublishService at root"
```

---

## Chunk 5: Comment Display — Render Video Comments Inline

This chunk is independent of the publish path; it ships even with the flag off (no-op when no video comments exist on a given video). It lands the missing display side so that, once Chunk 7 ships and a user posts a video reply, it actually appears in the very sheet they posted from.

> **Reuse existing primitives.** Do not invent a new video-player engine. Verify which inline player the rest of the app uses (`mobile/lib/widgets/video_player_subtitle_layer.dart` and `mobile/lib/widgets/web_video_player.dart` both exist; the feed item likely uses a higher-level wrapper). The implementer should pick the smallest existing primitive that supports tap-to-play with a thumbnail+blurhash placeholder, and only fall back to `package:video_player` directly if the existing wrappers don't fit. If unsure, **stop and ask** rather than reinvent.

### Task 5.1: `CommentVideoPlayer` widget

**Files:**
- Create: `mobile/lib/screens/comments/widgets/comment_video_player.dart`
- Test: `mobile/test/screens/comments/widgets/comment_video_player_test.dart`

- [ ] **Step 1: Write failing widget tests**

```dart
testWidgets(
  'shows thumbnail + play overlay before tap',
  (tester) async {
    await tester.pumpWidget(_wrap(const CommentVideoPlayer(
      videoUrl: 'https://blossom.example/abc.mp4',
      thumbnailUrl: 'https://blossom.example/abc.jpg',
      aspectRatio: 9 / 16,
    )));
    expect(find.byKey(const Key('comment-video-thumbnail')), findsOneWidget);
    expect(find.byKey(const Key('comment-video-play-overlay')), findsOneWidget);
    expect(find.byKey(const Key('comment-video-player-surface')), findsNothing);
  },
);

testWidgets(
  'tapping the thumbnail switches to the player surface',
  (tester) async {
    await tester.pumpWidget(_wrap(const CommentVideoPlayer(
      videoUrl: 'https://blossom.example/abc.mp4',
      thumbnailUrl: 'https://blossom.example/abc.jpg',
      aspectRatio: 9 / 16,
    )));
    await tester.tap(find.byKey(const Key('comment-video-thumbnail')));
    await tester.pump();
    expect(find.byKey(const Key('comment-video-player-surface')), findsOneWidget);
  },
);

testWidgets(
  'respects the supplied aspectRatio (no fixed height)',
  (tester) async {
    await tester.pumpWidget(_wrap(const SizedBox(
      width: 200,
      child: CommentVideoPlayer(
        videoUrl: 'https://blossom.example/abc.mp4',
        thumbnailUrl: 'https://blossom.example/abc.jpg',
        aspectRatio: 16 / 9,
      ),
    )));
    final box = tester.getSize(find.byKey(const Key('comment-video-thumbnail')));
    expect(box.width / box.height, closeTo(16 / 9, 0.01));
  },
);
```

`_wrap` should provide a MaterialApp with VineTheme so the player renders against the dark theme used by the comments sheet.

- [ ] **Step 2: Run — should FAIL.**

- [ ] **Step 3: Implement the widget**

Outline:

```dart
class CommentVideoPlayer extends StatefulWidget {
  const CommentVideoPlayer({
    super.key,
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.aspectRatio,
    this.blurhash,
  });

  final String videoUrl;
  final String? thumbnailUrl;
  final double aspectRatio;
  final String? blurhash;

  @override
  State<CommentVideoPlayer> createState() => _CommentVideoPlayerState();
}
```

- Initial state: thumbnail (use `VineCachedImage` per CLAUDE.md UI rules) with a centered play icon (`DivineIcon`).
- On tap: switch to a video surface (the existing app primitive — verify which one) and start playback.
- Use `AspectRatio(aspectRatio: ...)` rather than fixed `SizedBox(height:)` so it survives system text scaling per `accessibility.md`.
- Include `Semantics(label: 'Video reply, tap to play', button: true, ...)` on the tap target per `accessibility.md`.
- Dispose any controller in `dispose()` per `performance.md`.

If no existing wrapper fits cleanly, stop and ask before pulling `package:video_player` in directly.

- [ ] **Step 4: Run — should PASS.**

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/screens/comments/widgets/comment_video_player.dart mobile/test/screens/comments/widgets/comment_video_player_test.dart
git commit -m "feat(comments): add inline CommentVideoPlayer for video comments"
```

### Task 5.2: Render `CommentVideoPlayer` from `CommentItem` when `hasVideo`

**Files:**
- Modify: `mobile/lib/screens/comments/widgets/comment_item.dart`
- Test: `mobile/test/screens/comments/widgets/comment_item_video_render_test.dart`

- [ ] **Step 1: Write failing widget tests**

```dart
testWidgets(
  'text-only comment renders no CommentVideoPlayer (regression)',
  (tester) async {
    final comment = _textComment(content: 'just text');
    await tester.pumpWidget(_wrap(CommentItem(comment: comment, /* required deps */)));
    expect(find.byType(CommentVideoPlayer), findsNothing);
    expect(find.text('just text'), findsOneWidget);
  },
);

testWidgets(
  'video comment renders CommentVideoPlayer above the text content',
  (tester) async {
    final comment = _videoComment(
      videoUrl: 'https://blossom.example/abc.mp4',
      thumbnailUrl: 'https://blossom.example/abc.jpg',
      content: 'caption',
    );
    await tester.pumpWidget(_wrap(CommentItem(comment: comment, /* required deps */)));
    expect(find.byType(CommentVideoPlayer), findsOneWidget);
    expect(find.text('caption'), findsOneWidget);
  },
);

testWidgets(
  'video comment with empty content still renders the player',
  (tester) async {
    final comment = _videoComment(
      videoUrl: 'https://blossom.example/abc.mp4',
      thumbnailUrl: 'https://blossom.example/abc.jpg',
      content: '',
    );
    await tester.pumpWidget(_wrap(CommentItem(comment: comment, /* required deps */)));
    expect(find.byType(CommentVideoPlayer), findsOneWidget);
  },
);
```

`_textComment` / `_videoComment` are local fixture helpers built with the existing `Comment` constructor.

- [ ] **Step 2: Run — should FAIL.**

- [ ] **Step 3: Add the render branch**

Inside `_CommentItemState.build` (or wherever the comment body is laid out), insert above the existing text widget:

```dart
if (widget.comment.hasVideo)
  CommentVideoPlayer(
    videoUrl: widget.comment.videoUrl!,
    thumbnailUrl: widget.comment.thumbnailUrl,
    aspectRatio: _aspectRatioFor(widget.comment), // helper, e.g. 9/16 default
    blurhash: widget.comment.videoBlurhash,
  ),
```

The aspect ratio helper should prefer `comment.videoDimensions` when available, default to `9 / 16` when not (vertical video is the dominant orientation in this app). Confirm field names against the current `Comment` model before writing.

- [ ] **Step 4: Run — should PASS.**

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/screens/comments/widgets/comment_item.dart mobile/test/screens/comments/widgets/comment_item_video_render_test.dart
git commit -m "feat(comments): render video comments inline in CommentItem"
```

---

## Chunk 6: Comment-Side Entry Point

### Task 6.1: Add `onVideoReply` to `CommentInput`

**Files:**
- Modify: `mobile/lib/screens/comments/widgets/comment_input.dart`
- Test: `mobile/test/screens/comments/widgets/comment_input_video_reply_test.dart`

- [ ] **Step 1: Write failing widget test**

```dart
testWidgets(
  'video reply icon is hidden when onVideoReply is null',
  (tester) async {
    await tester.pumpWidget(_wrap(const CommentInput()));
    expect(find.byKey(const Key('comment-input-video-reply')), findsNothing);
  },
);

testWidgets(
  'video reply icon is shown and tappable when onVideoReply is non-null',
  (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      _wrap(CommentInput(onVideoReply: () => tapped = true)),
    );
    await tester.tap(find.byKey(const Key('comment-input-video-reply')));
    expect(tapped, isTrue);
  },
);
```

- [ ] **Step 2: Run — should FAIL.**

- [ ] **Step 3: Add the optional callback + icon**

```dart
class CommentInput extends StatelessWidget {
  const CommentInput({super.key, this.onVideoReply});
  final VoidCallback? onVideoReply;
  // ... in build, render the icon next to send only when non-null
}
```

Use `DivineIcon` and `VineTheme` per CLAUDE.md UI rules. Provide a `tooltip: 'Record a video reply'` for accessibility.

- [ ] **Step 4: Run — should PASS.**

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/screens/comments/widgets/comment_input.dart mobile/test/screens/comments/widgets/comment_input_video_reply_test.dart
git commit -m "feat(comments): optional onVideoReply callback on CommentInput"
```

### Task 6.2: Wire the entry point in `CommentsScreen`

**Files:**
- Modify: `mobile/lib/screens/comments/comments_screen.dart`
- Test: `mobile/test/screens/comments/comments_screen_video_reply_entry_test.dart`

- [ ] **Step 1: Write failing widget tests**

```dart
testWidgets(
  'when videoReplies flag is OFF, no video reply icon is rendered',
  (tester) async { /* override flag service to return false */ },
);

testWidgets(
  'when flag is ON, tapping the icon sets reply context, '
  'closes the sheet, and pushes the recorder route',
  (tester) async {
    /* override flag service to true; pump screen */
    /* tap icon; assert provider state; assert router.push called */
  },
);
```

- [ ] **Step 2: Run — should FAIL.**

- [ ] **Step 3: Wire the callback**

In `CommentsScreen`:

1. Read the flag via the existing `featureFlagProvider` / `FeatureFlagService` pattern (match what other screens do).
2. If `isEnabled(FeatureFlag.videoReplies)`, pass `onVideoReply: () { ... }` to `CommentInput`.
3. The handler:
   - Calls `context.read<VideoReplyCubit>().start(VideoReplyContext(...))` with the parent video's full Nostr id (no truncation), kind, pubkey, addressable id (`30000+:pubkey:dtag`).
   - Closes the sheet (`Navigator.of(context).pop()`).
   - In the sheet's `whenComplete` (in whatever caller opens the sheet), if `context.read<VideoReplyCubit>().state` is non-null, `router.push(VideoRecorderScreen.path)`.

If the comments screen no longer uses a modal pattern (verified in Task 0.2), wire the recorder navigation directly from the callback instead of via `whenComplete`.

- [ ] **Step 4: Run — should PASS.**

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/screens/comments mobile/test/screens/comments
git commit -m "feat(comments): wire video reply entry behind videoReplies flag"
```

---

## Chunk 7: Editor Confirm — Single Decision Point

### Task 7.1: Branch on reply context at editor "Done"

**Files:**
- Modify: `mobile/lib/widgets/video_editor/main_editor/video_editor_canvas.dart` (verified in pre-flight; the `await context.push(VideoMetadataScreen.path)` is at line 721 on `origin/main` at `c5ed3eadd`)
- Test: `mobile/test/widgets/video_editor/main_editor/video_editor_canvas_reply_branch_test.dart`

This is the ONLY file in the editor that learns about replies. Per debt rule #2, do not put any reply logic in `video_editor_provider.dart`.

- [ ] **Step 1: Write failing widget tests**

```dart
testWidgets(
  'normal flow: with no reply context, "Done" pushes the metadata screen',
  (tester) async { /* ... */ },
);

testWidgets(
  'reply flow: with reply context, "Done" calls publisher and '
  'does NOT push the metadata screen',
  (tester) async {
    /* Provide a stubbed VideoReplyPublisher whose handleEditorDone
       returns Future.value(true). Verify the metadata screen never
       appears in the navigator stack. */
  },
);

testWidgets(
  'reply flow regression: after publisher succeeds, '
  'VideoReplyCubit state is null',
  (tester) async { /* ... */ },
);
```

- [ ] **Step 2: Run — should FAIL.**

- [ ] **Step 3: Modify `_handleDone` (or equivalent)**

The editor screen is a `ConsumerStatefulWidget` (legacy Riverpod). It constructs the publisher locally so the rendered-clip callback can read `Ref` without leaking it into the publisher class:

```dart
Future<void> _handleDone() async {
  final publisher = VideoReplyPublisher(
    cubit: context.read<VideoReplyCubit>(),
    service: context.read<VideoCommentPublishService>(),
    getRenderedClipPath: () async =>
        ref.read(videoEditorProvider).finalRenderedClipPath,
  );
  final consumed = await publisher.handleEditorDone();
  if (consumed) {
    if (!mounted) return;
    context.go(HomeRoute.path); // or whichever post-publish destination
    return;
  }
  // existing path
  context.push(VideoMetadataScreen.path);
}
```

This is the only place `Ref` and `BlocProvider` mix — and it is intentional: it is the documented seam between the legacy editor and the new BLoC-based reply state.

- [ ] **Step 4: Run — should PASS.**

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/screens/video_editor mobile/test/screens/video_editor
git commit -m "feat(video-editor): dispatch reply path at confirm; metadata otherwise"
```

---

## Chunk 8: Lifecycle Hardening

Debt rule #1 has the highest regression risk. Each exit path needs an explicit clear and a test.

### Task 8.1: Clear reply context on recorder cancel/dispose

**Files:**
- Modify: `mobile/lib/screens/video_recorder_screen.dart` (the *screen widget*, NOT the Riverpod notifier)
- Test: `mobile/test/screens/video_recorder/video_recorder_screen_reply_clear_test.dart`

The legacy Riverpod recorder *notifier* is not modified — clearing happens at the screen widget layer where both `Ref` and `BlocProvider` are reachable. This avoids polluting Riverpod-only code with BLoC dependencies.

- [ ] **Step 1: Failing widget test** — pump `VideoRecorderScreen` wrapped with a `BlocProvider<VideoReplyCubit>` whose state is set to a non-null context, simulate cancel/back, then assert `cubit.state == null`.
- [ ] **Step 2: Run — FAIL.**
- [ ] **Step 3: In the screen's `dispose()` and the cancel button handler, call:**

```dart
context.read<VideoReplyCubit>().clear();
```

In `dispose()` use `context.read` carefully — if the screen is being torn down because the `BlocProvider` itself was popped, the cubit may already be unavailable. Guard with a try/catch or store a captured reference in `didChangeDependencies()`:

```dart
late VideoReplyCubit _replyCubit;
@override
void didChangeDependencies() {
  super.didChangeDependencies();
  _replyCubit = context.read<VideoReplyCubit>();
}
@override
void dispose() {
  _replyCubit.clear();
  super.dispose();
}
```

- [ ] **Step 4: Run — PASS.**
- [ ] **Step 5: Commit**

```bash
git commit -m "fix(recorder): clear VideoReplyCubit on screen dispose/cancel"
```

### Task 8.2: Clear reply context on editor cancel

**Files:**
- Modify: editor screen cancel handler (verify location — same `ConsumerStatefulWidget` as Chunk 6)
- Test: matching widget test

- [ ] Same five-step TDD cycle, using the captured-`VideoReplyCubit` pattern from 7.1.
- [ ] **Commit:**

```bash
git commit -m "fix(video-editor): clear VideoReplyCubit on cancel"
```

### Task 8.3: Integration test for the regression scenario

**Files:**
- Test: `mobile/integration_test/video_reply_lifecycle_test.dart` (or a widget test if integration_test setup is heavy for this)

- [ ] **Step 1:** Write a test that drives: open comments → tap video reply (flag forced on) → enter recorder → press cancel → open the standard recorder via the home tab → assert `VideoReplyCubit.state` is null AND assert that completing the flow publishes a Kind 34236 event, NOT a Kind 1111 with imeta.
- [ ] **Step 2:** Run — should FAIL until 7.1/7.2 are merged. (Sanity check: temporarily comment out the clear in 7.1; the test should fail. Restore.)
- [ ] **Step 3:** Run with clears in place — PASS.
- [ ] **Step 4: Commit**

```bash
git commit -m "test(video-comments): regression test for reply→cancel→normal post"
```

---

## Chunk 9: Final Polish & PR

### Task 9.1: Run the full local CI suite

- [ ] `cd mobile && flutter analyze lib test integration_test`
- [ ] `cd mobile && dart format --output=none --set-exit-if-changed lib test integration_test`
- [ ] `cd mobile && flutter test`
- [ ] `cd mobile/packages/comments_repository && dart test`
- [ ] If any codegen inputs were touched: `cd mobile && dart run build_runner build --delete-conflicting-outputs` and commit any generated changes.

### Task 9.2: PR with explicit flag exit criterion

Per debt rule #4, the PR description must state when the flag will be removed.

- [ ] Push the branch and open a PR with this body skeleton:

```markdown
## Summary
Revives the half-shipped video-replies feature behind `FF_VIDEO_REPLIES` (default off). Reuses the existing recorder/editor; only the publish path diverges (Kind 1111 + NIP-92 imeta vs. Kind 34236).

## Feature flag exit criterion
Remove the `videoReplies` enum entry, env var, and dispatcher branch once the flag has been at 100% for two weeks with no regression in the comments funnel and no >0.5% lift in publish errors. Tracked in: <issue link>.

## Test plan
- [ ] With FF_VIDEO_REPLIES=false (default), the comments sheet shows no video-reply icon and the recorder/editor behave exactly as today.
- [ ] With FF_VIDEO_REPLIES=true, tapping the icon opens the recorder, recording + editing → "Done" publishes a Kind 1111 comment with imeta tags via Blossom, and lands in the feed (no metadata screen).
- [ ] Reply→cancel→normal-post path produces a Kind 34236 (regression).
- [ ] Pre-commit and pre-push hooks pass.
```

- [ ] Open a tracking issue for the flag-removal exit criterion and link it in the PR.

---

## Plan complete

**Saved to:** `docs/superpowers/plans/2026-05-04-video-comments-revival.md`

Ready to execute?
