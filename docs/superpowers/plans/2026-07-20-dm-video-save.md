# DM Shared-Video Save Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an ownership-aware Save video action to full shared-video DM cards.

**Architecture:** Normalize URL and NIP-18 `q` references into one `DmVideoTarget`, then use that target for preview resolution, copy-link behavior, and save resolution. The conversation presents the existing original or watermarked gallery-save sheet after resolving the canonical `VideoEvent`.

**Tech Stack:** Flutter, Dart, BLoC/Cubit, Riverpod compatibility providers, `VideosRepository`, NIP-17/NIP-18 DM models, mocktail widget tests.

---

### Task 1: Normalize DM video identity

**Files:**
- Create: `mobile/lib/screens/inbox/conversation/dm_video_target.dart`
- Modify: `mobile/lib/screens/inbox/conversation/widgets/message_bubble.dart`
- Modify: `mobile/lib/screens/inbox/conversation/widgets/video_link_preview_cubit.dart`
- Create: `mobile/test/screens/inbox/conversation/dm_video_target_test.dart`
- Test: `mobile/test/screens/inbox/conversation/widgets/video_link_preview_cubit_test.dart`

- [ ] **Step 1: Write target normalization tests**

Cover canonical URLs, regular event refs, addressable refs, URL-plus-structured
metadata, and malformed addressable refs:

```dart
final target = resolveDmVideoTarget(
  content: 'watch https://divine.video/video/skate-loop',
  sharedVideoRef: const DmSharedVideoRef(
    coordinateOrId: '34236:$author:skate-loop',
    videoKind: DmSharedVideoKind.addressableShortVideo,
  ),
);

expect(target?.stableId, 'skate-loop');
expect(target?.fallbackRouteIds, ['34236:$author:skate-loop']);
expect(target?.canonicalUrl, 'https://divine.video/video/skate-loop');
```

- [ ] **Step 2: Run the target tests and confirm they fail**

Run:

```bash
cd mobile
flutter test test/screens/inbox/conversation/dm_video_target_test.dart
```

Expected: compilation failure because `DmVideoTarget` and
`resolveDmVideoTarget` do not exist.

- [ ] **Step 3: Implement the normalized target**

Create an immutable value object and resolver:

```dart
class DmVideoTarget {
  const DmVideoTarget({
    required this.stableId,
    this.authorPubkey,
    this.videoKind,
  });

  final String stableId;
  final String? authorPubkey;
  final int? videoKind;

  String get canonicalUrl => 'https://divine.video/video/$stableId';

  List<String> get fallbackRouteIds {
    final author = authorPubkey;
    final kind = videoKind;
    if (author == null || kind == null) return const [];
    return ['$kind:$author:$stableId'];
  }
}
```

`resolveDmVideoTarget` must prefer the URL's stable ID while retaining valid
author/kind metadata from the structured ref. For an addressable ref, use
`DmSharedVideoRef.dTag` and parse the author from `coordinateOrId`.

- [ ] **Step 4: Make the card and cubit use the shared target**

Replace `_SharedVideoTarget` and `_videoTargetFromRef` in
`message_bubble.dart`. Make `VideoLinkPreviewCubit` resolve with
`target.fallbackRouteIds` so the preview and save action cannot drift.

- [ ] **Step 5: Run focused tests**

Run:

```bash
cd mobile
flutter test \
  test/screens/inbox/conversation/dm_video_target_test.dart \
  test/screens/inbox/conversation/widgets/video_link_preview_cubit_test.dart \
  test/screens/inbox/conversation/widgets/message_bubble_test.dart
```

Expected: all pass.

### Task 2: Add Save video to DM actions

**Files:**
- Modify: `mobile/lib/screens/inbox/conversation/widgets/message_actions_sheet.dart`
- Modify: `mobile/lib/screens/inbox/conversation/widgets/reaction_picker_overlay.dart`
- Modify: `mobile/test/screens/inbox/conversation/widgets/reaction_picker_overlay_test.dart`

- [ ] **Step 1: Write failing action tests**

Open the overlay with `isVideoShare: true`, assert that **Save video** appears,
tap it, and assert:

```dart
expect(result?.action, MessageAction.saveVideo);
```

Also assert the action is absent for text-only messages.

- [ ] **Step 2: Run the overlay tests and confirm failure**

Run:

```bash
cd mobile
flutter test test/screens/inbox/conversation/widgets/reaction_picker_overlay_test.dart
```

Expected: **Save video** is not found and `MessageAction.saveVideo` is absent.

- [ ] **Step 3: Add the action**

Add `saveVideo` to `MessageAction`. In both action-sheet renderers, insert:

```dart
if (isVideoShare)
  _ActionTile(
    icon: DivineIconName.downloadSimple,
    label: l10n.shareSheetSaveVideo,
    onTap: () => onSelected(MessageAction.saveVideo),
  ),
```

The dormant `MessageActionsSheet` must stay aligned with the active
`ReactionPickerOverlay`.

- [ ] **Step 4: Run overlay tests**

Run the command from Step 2. Expected: all pass.

### Task 3: Resolve and present the correct save flow

**Files:**
- Modify: `mobile/lib/screens/inbox/conversation/conversation_view.dart`
- Modify: `mobile/test/screens/inbox/conversation/conversation_view_test.dart`

- [ ] **Step 1: Write failing conversation tests**

Add tests proving:

- a structured full-card share without a plaintext URL shows **Copy video URL**
  and **Save video**;
- selecting Save video fetches with the normalized stable ID and fallbacks;
- current-user content calls `downloadOriginal`;
- other-creator content calls `downloadWithWatermark`;
- a repository miss shows `notificationsVideoUnavailable`.

Override `videosRepositoryProvider` and `watermarkDownloadServiceProvider` with
mocks, and return a `WatermarkDownloadSuccess` so the established progress
sheet completes deterministically.

- [ ] **Step 2: Run the conversation tests and confirm failure**

Run:

```bash
cd mobile
flutter test test/screens/inbox/conversation/conversation_view_test.dart \
  --plain-name 'shared video save'
```

Expected: the structured share lacks the actions and no save method is called.

- [ ] **Step 3: Implement conversation save presentation**

Normalize the full-card target before opening the action overlay:

```dart
final videoTarget = resolveDmVideoTarget(
  content: message.content,
  sharedVideoRef: resolveOwnShareVideoRef(message),
);
```

For `MessageAction.copyVideoUrl`, copy `videoTarget.canonicalUrl`. For
`MessageAction.saveVideo`, resolve through `VideosRepository`, check the
authenticated pubkey against `video.pubkey`, and present
`showSaveOriginalSheet` or `showWatermarkDownloadSheet`. Use
`resolveWatermarkText` for other creators and show
`notificationsVideoUnavailable` on null/error.

- [ ] **Step 4: Run focused conversation and save tests**

Run:

```bash
cd mobile
flutter test \
  test/screens/inbox/conversation/conversation_view_test.dart \
  test/screens/inbox/conversation/widgets/reaction_picker_overlay_test.dart \
  test/widgets/save_original_progress_sheet_test.dart \
  test/widgets/watermark_download_progress_sheet_test.dart \
  test/services/watermark_download_service_test.dart
```

Expected: all pass.

### Task 4: Verify and publish

**Files:**
- Verify all files changed by Tasks 1-3.

- [ ] **Step 1: Format**

```bash
cd mobile
mise exec -- dart format \
  lib/screens/inbox/conversation/dm_video_target.dart \
  lib/screens/inbox/conversation/conversation_view.dart \
  lib/screens/inbox/conversation/widgets/message_actions_sheet.dart \
  lib/screens/inbox/conversation/widgets/message_bubble.dart \
  lib/screens/inbox/conversation/widgets/reaction_picker_overlay.dart \
  lib/screens/inbox/conversation/widgets/video_link_preview_cubit.dart \
  test/screens/inbox/conversation/dm_video_target_test.dart \
  test/screens/inbox/conversation/conversation_view_test.dart \
  test/screens/inbox/conversation/widgets/reaction_picker_overlay_test.dart \
  test/screens/inbox/conversation/widgets/video_link_preview_cubit_test.dart
```

- [ ] **Step 2: Run localization consistency**

No ARB change is expected because the design reuses existing localized copy:

```bash
cd mobile
flutter test test/l10n/arb_consistency_test.dart
```

- [ ] **Step 3: Run static analysis**

```bash
cd mobile
flutter analyze lib test
```

Expected: no issues.

- [ ] **Step 4: Inspect and commit**

```bash
git diff --check
git status --short
git diff --stat
git add \
  docs/superpowers/specs/2026-07-20-dm-video-save-design.md \
  docs/superpowers/plans/2026-07-20-dm-video-save.md \
  mobile/lib/screens/inbox/conversation/dm_video_target.dart \
  mobile/lib/screens/inbox/conversation/conversation_view.dart \
  mobile/lib/screens/inbox/conversation/widgets/message_actions_sheet.dart \
  mobile/lib/screens/inbox/conversation/widgets/message_bubble.dart \
  mobile/lib/screens/inbox/conversation/widgets/reaction_picker_overlay.dart \
  mobile/lib/screens/inbox/conversation/widgets/video_link_preview_cubit.dart \
  mobile/test/screens/inbox/conversation/dm_video_target_test.dart \
  mobile/test/screens/inbox/conversation/conversation_view_test.dart \
  mobile/test/screens/inbox/conversation/widgets/reaction_picker_overlay_test.dart \
  mobile/test/screens/inbox/conversation/widgets/video_link_preview_cubit_test.dart
git commit -m "feat(dm): save shared videos from messages"
```

- [ ] **Step 5: Rebase and push**

```bash
git fetch origin
git rebase origin/main
git push -u origin feat/dm-video-save
```

Create a Conventional Commit PR targeting `main`, then inspect GitHub checks.
