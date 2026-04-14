# Feed Description Metadata Sheet Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let any non-empty feed description open the existing metadata sheet, and make full descriptions inside that sheet support tappable URLs in addition to the existing hashtag and mention parsing.

**Architecture:** Reuse the current `MetadataExpandedSheet` instead of creating a new detail surface. Keep the feed overlay visually unchanged, but wrap the description in a tap target that opens the existing sheet. Extend `ClickableHashtagText` to recognize URLs and use the same rich-text widget inside the metadata sheet so the full description is readable and interactive in one place.

**Tech Stack:** Flutter, Riverpod, go_router, url_launcher, flutter_test

---

## File Structure

**Modify**
- `mobile/lib/screens/feed/feed_video_overlay.dart`
- `mobile/lib/widgets/clickable_hashtag_text.dart`
- `mobile/lib/widgets/video_feed_item/metadata/metadata_expanded_sheet.dart`
- `mobile/test/screens/feed/feed_video_overlay_test.dart`
- `mobile/test/widgets/video_feed_item/metadata/metadata_expanded_sheet_test.dart`

**Why this structure**
- Keep feed behavior in the existing overlay widget.
- Keep parsing and link launching in the shared rich-text widget so feed text and metadata sheet text do not diverge.
- Keep the metadata sheet as the only full-description surface.
- Limit test changes to the two widget suites already covering the touched features.

## Chunk 1: Make Feed Descriptions Open The Existing Metadata Sheet

### Task 1: Add the failing feed overlay test

**Files:**
- Modify: `mobile/test/screens/feed/feed_video_overlay_test.dart`
- Use: `mobile/lib/screens/feed/feed_video_overlay.dart`

- [ ] **Step 1: Write a widget test that taps the feed description**

Add a test near the existing `FeedVideoOverlay` coverage that:

- pumps `FeedVideoOverlay` with a video that has non-empty `content`
- taps the widget with semantics identifier `video_description`
- asserts that metadata-sheet content such as the video description text and `Loops` appears

- [ ] **Step 2: Run the test to verify it fails**

Run:

```bash
cd mobile
flutter test test/screens/feed/feed_video_overlay_test.dart --plain-name "opens metadata sheet when tapping the description"
```

Expected: FAIL because the description is not yet tappable.

- [ ] **Step 3: Implement the minimal feed overlay change**

Update `mobile/lib/screens/feed/feed_video_overlay.dart` so the existing description block:

- stays visually identical
- is wrapped in a tap handler only when text exists
- calls `MetadataExpandedSheet.show(context, video)` on tap

- [ ] **Step 4: Run the test to verify it passes**

Run:

```bash
cd mobile
flutter test test/screens/feed/feed_video_overlay_test.dart --plain-name "opens metadata sheet when tapping the description"
```

Expected: PASS.

## Chunk 2: Render Full Metadata Descriptions With Shared Interactive Text

### Task 2: Add the failing metadata-sheet test

**Files:**
- Modify: `mobile/test/widgets/video_feed_item/metadata/metadata_expanded_sheet_test.dart`
- Use: `mobile/lib/widgets/video_feed_item/metadata/metadata_expanded_sheet.dart`

- [ ] **Step 1: Write a widget test that expects rich description rendering**

Add a test that:

- builds `MetadataExpandedSheet` with a description containing a URL and a hashtag
- asserts the sheet contains a `ClickableHashtagText` widget for the description
- keeps the title and description text visible

- [ ] **Step 2: Run the test to verify it fails**

Run:

```bash
cd mobile
flutter test test/widgets/video_feed_item/metadata/metadata_expanded_sheet_test.dart --plain-name "renders description with clickable rich text"
```

Expected: FAIL because the sheet still uses plain `Text`.

- [ ] **Step 3: Implement the minimal metadata sheet change**

Update `mobile/lib/widgets/video_feed_item/metadata/metadata_expanded_sheet.dart` to:

- import `ClickableHashtagText`
- replace the plain description `Text` with `ClickableHashtagText`
- remove any line clamp so the full description remains visible

- [ ] **Step 4: Run the test to verify it passes**

Run:

```bash
cd mobile
flutter test test/widgets/video_feed_item/metadata/metadata_expanded_sheet_test.dart --plain-name "renders description with clickable rich text"
```

Expected: PASS.

## Chunk 3: Extend Shared Rich Text Parsing To Support URLs

### Task 3: Add failing parser coverage for URLs

**Files:**
- Modify: `mobile/test/widgets/video_feed_item/metadata/metadata_expanded_sheet_test.dart`
- Modify: `mobile/lib/widgets/clickable_hashtag_text.dart`

- [ ] **Step 1: Add test coverage that exercises URL-bearing descriptions through the metadata sheet**

Use a description like:

```text
Read more at https://example.com/docs #proof
```

Verify:

- the metadata sheet still renders the full string
- the description is rendered through `ClickableHashtagText`

This test does not need to launch the URL. It should prove the metadata sheet routes description content through the shared parser that will own link behavior.

- [ ] **Step 2: Run the test suite to confirm the new expectation fails for URL support if needed**

Run:

```bash
cd mobile
flutter test test/widgets/video_feed_item/metadata/metadata_expanded_sheet_test.dart
```

Expected: FAIL only if the parser changes require additional adjustments; otherwise proceed to the direct implementation.

- [ ] **Step 3: Extend `ClickableHashtagText` to recognize URLs**

Update `mobile/lib/widgets/clickable_hashtag_text.dart` to:

- add URL detection for `http://`, `https://`, and bare domains
- style URLs consistently with the existing tappable text style
- launch the normalized URL with `launchUrl(..., mode: LaunchMode.externalApplication)`
- preserve the existing hashtag and mention behavior

- [ ] **Step 4: Run the targeted suites**

Run:

```bash
cd mobile
flutter test test/screens/feed/feed_video_overlay_test.dart
flutter test test/widgets/video_feed_item/metadata/metadata_expanded_sheet_test.dart
```

Expected: both suites PASS.

## Chunk 4: Final Verification And Commit

### Task 4: Verify the full change set and record the work

**Files:**
- Verify: `mobile/lib/screens/feed/feed_video_overlay.dart`
- Verify: `mobile/lib/widgets/clickable_hashtag_text.dart`
- Verify: `mobile/lib/widgets/video_feed_item/metadata/metadata_expanded_sheet.dart`
- Verify: `mobile/test/screens/feed/feed_video_overlay_test.dart`
- Verify: `mobile/test/widgets/video_feed_item/metadata/metadata_expanded_sheet_test.dart`
- Verify: `docs/superpowers/specs/2026-04-14-feed-description-metadata-sheet-design.md`
- Verify: `docs/superpowers/plans/2026-04-14-feed-description-metadata-sheet.md`

- [ ] **Step 1: Run the final targeted verification**

Run:

```bash
cd mobile
flutter test test/screens/feed/feed_video_overlay_test.dart
flutter test test/widgets/video_feed_item/metadata/metadata_expanded_sheet_test.dart
```

Expected: both suites PASS.

- [ ] **Step 2: Review the final diff**

Run:

```bash
git status --short
git diff -- mobile/lib/screens/feed/feed_video_overlay.dart mobile/lib/widgets/clickable_hashtag_text.dart mobile/lib/widgets/video_feed_item/metadata/metadata_expanded_sheet.dart mobile/test/screens/feed/feed_video_overlay_test.dart mobile/test/widgets/video_feed_item/metadata/metadata_expanded_sheet_test.dart docs/superpowers/specs/2026-04-14-feed-description-metadata-sheet-design.md docs/superpowers/plans/2026-04-14-feed-description-metadata-sheet.md
```

Expected: only task-related files are changed.

- [ ] **Step 3: Commit the task**

```bash
git add mobile/lib/screens/feed/feed_video_overlay.dart mobile/lib/widgets/clickable_hashtag_text.dart mobile/lib/widgets/video_feed_item/metadata/metadata_expanded_sheet.dart mobile/test/screens/feed/feed_video_overlay_test.dart mobile/test/widgets/video_feed_item/metadata/metadata_expanded_sheet_test.dart docs/superpowers/specs/2026-04-14-feed-description-metadata-sheet-design.md docs/superpowers/plans/2026-04-14-feed-description-metadata-sheet.md
git commit -m "feat(feed): open metadata sheet from descriptions"
```
