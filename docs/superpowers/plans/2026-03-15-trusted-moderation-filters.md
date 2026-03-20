Status: Historical

> Historical note
> Preserved for context during the P1 documentation refresh. This file may reference deleted screens, older branding, or superseded implementation details. Start with docs/README.md and docs/archive/README.md for current guidance.

# Trusted Moderation Filters Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make trusted kind-1985 content-warning labels participate in feed `Show / Warn / Hide` behavior like creator self-labels, while keeping trusted moderators user-configurable.

**Architecture:** Add one focused effective-warning resolver that merges creator self-labels with trusted kind-1985 labels at filtering time. Extend `ModerationLabelService` to expose the missing match keys for feed use, then route `VideoEventService` and repository-level NSFW filtering through that resolver. Reuse the existing Safety & Privacy moderation-provider UI, upgrading the "People I follow" option from stub to persisted behavior.

**Tech Stack:** Flutter, Riverpod, SharedPreferences, Nostr kind-1985 moderation labels, existing `ContentFilterService`, existing `ModerationLabelService`.

---

## File Map

- Modify: `mobile/lib/services/moderation_label_service.dart`
  Purpose: expose trusted content-warning lookups by addressable id and content hash; support effective feed filtering without changing model semantics.
- Modify: `mobile/lib/services/video_event_service.dart`
  Purpose: route feed `warn`/`hide` decisions through the new effective warning resolver.
- Modify: `mobile/lib/services/nsfw_content_filter.dart`
  Purpose: keep repository-level filtering consistent with app-level feed filtering.
- Modify: `mobile/lib/screens/safety_settings_screen.dart`
  Purpose: make the "People I follow" moderation provider real and persisted.
- Create or replace: `mobile/lib/services/effective_content_labels.dart`
  Purpose: compute effective warning labels from self-labels, trusted labelers, and hashtag fallback.
- Modify: `mobile/lib/providers/app_providers.dart`
  Purpose: wire any new persisted trust-source state/service dependencies.
- Test: `mobile/test/services/moderation_label_service_test.dart`
  Purpose: cover new `a`/hash lookup behavior.
- Test: `mobile/test/services/video_event_service_content_filter_test.dart`
  Purpose: verify trusted kind-1985 labels now drive `warn` and `hide`.
- Test: `mobile/test/services/nsfw_content_filter_test.dart`
  Purpose: verify repository-level filter behavior stays aligned.
- Test: `mobile/test/screens/safety_settings_screen_test.dart`
  Purpose: verify trust-source settings behavior.

## Chunk 1: Trusted Label Lookup Surface

### Task 1: Add failing moderation lookup tests

**Files:**
- Modify: `mobile/test/services/moderation_label_service_test.dart`
- Test: `mobile/test/services/moderation_label_service_test.dart`

- [ ] **Step 1: Write failing tests for content-warning lookup by addressable id and content hash**

Add tests that seed kind-1985 label events with:
- `['a', '<kind:pubkey:d>']`
- `['x', '<sha256>']`

and assert the service returns trusted content-warning labels for both paths.

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
cd mobile && flutter test test/services/moderation_label_service_test.dart
```

Expected: FAIL because the service does not yet expose content-warning lookup by addressable id or content hash.

- [ ] **Step 3: Implement minimal lookup support**

Update `mobile/lib/services/moderation_label_service.dart` to:
- parse `a` targets from kind-1985 events
- cache labels by addressable id
- expose public getters for content-warning labels by addressable id and content hash

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
cd mobile && flutter test test/services/moderation_label_service_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/services/moderation_label_service.dart mobile/test/services/moderation_label_service_test.dart
git commit -m "feat(moderation): add trusted content-warning lookup helpers"
```

## Chunk 2: Effective Warning Resolver

### Task 2: Add failing resolver tests

**Files:**
- Modify: `mobile/test/services/video_event_service_content_filter_test.dart`
- Create or Modify: `mobile/lib/services/effective_content_labels.dart`

- [ ] **Step 1: Write failing tests for effective warning label resolution**

Cover:
- creator self-labels survive unchanged
- trusted event-id labels are included
- trusted addressable-id labels are included
- trusted hash labels are included
- trusted pubkey labels are included
- hashtag fallback still maps to `nudity`

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
cd mobile && flutter test test/services/video_event_service_content_filter_test.dart
```

Expected: FAIL because the current draft file is out of sync and the new resolver behavior is not implemented.

- [ ] **Step 3: Implement the resolver**

Replace or rewrite `mobile/lib/services/effective_content_labels.dart` to:
- work on current `main`
- accept a `VideoEvent`
- optionally accept `ModerationLabelService`
- merge labels using this order:
  1. `a` / addressable id
  2. `e` / event id
  3. `x` / content hash
  4. `p` / pubkey
  5. hashtag fallback

Keep `contentWarningLabels` and `moderationLabels` semantically separate.

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
cd mobile && flutter test test/services/video_event_service_content_filter_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/services/effective_content_labels.dart mobile/test/services/video_event_service_content_filter_test.dart
git commit -m "feat(filters): resolve trusted moderation labels for feeds"
```

## Chunk 3: Feed Filtering Integration

### Task 3: Add failing feed-filter tests

**Files:**
- Modify: `mobile/test/services/video_event_service_content_filter_test.dart`
- Modify: `mobile/test/services/nsfw_content_filter_test.dart`
- Modify: `mobile/lib/services/video_event_service.dart`
- Modify: `mobile/lib/services/nsfw_content_filter.dart`

- [ ] **Step 1: Write failing tests for trusted moderation warn/hide behavior**

Add tests proving:
- trusted kind-1985 labels trigger `warnLabels` when the matched category preference is `warn`
- trusted kind-1985 labels hide videos when the matched category preference is `hide`
- FunnelCake `moderationLabels` remain hide-only

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
cd mobile && flutter test test/services/video_event_service_content_filter_test.dart test/services/nsfw_content_filter_test.dart
```

Expected: FAIL because current feed filtering does not use trusted kind-1985 labels.

- [ ] **Step 3: Implement minimal integration**

Update:
- `mobile/lib/services/video_event_service.dart`
- `mobile/lib/services/nsfw_content_filter.dart`

to use the effective warning resolver for self-label-like behavior, while keeping `video.moderationLabels` hide-only.

- [ ] **Step 4: Run tests to verify they pass**

Run:

```bash
cd mobile && flutter test test/services/video_event_service_content_filter_test.dart test/services/nsfw_content_filter_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/services/video_event_service.dart mobile/lib/services/nsfw_content_filter.dart mobile/test/services/video_event_service_content_filter_test.dart mobile/test/services/nsfw_content_filter_test.dart
git commit -m "feat(filters): apply trusted moderation labels in feed filtering"
```

## Chunk 4: Trusted Moderator Settings

### Task 4: Add failing settings tests

**Files:**
- Modify: `mobile/test/screens/safety_settings_screen_test.dart`
- Modify: `mobile/lib/screens/safety_settings_screen.dart`
- Modify: `mobile/lib/providers/app_providers.dart`

- [ ] **Step 1: Write failing tests for trust-source settings**

Cover:
- Divine toggle still works
- custom labeler add/remove still works
- "People I follow" persists and updates state instead of showing a stub snackbar

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
cd mobile && flutter test test/screens/safety_settings_screen_test.dart
```

Expected: FAIL because "People I follow" is currently a stub.

- [ ] **Step 3: Implement persisted follow-derived trust**

Add the smallest possible current-`main` implementation so:
- the setting persists
- it is readable by the effective warning resolver or supporting service
- it does not break Divine/custom labeler controls

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
cd mobile && flutter test test/screens/safety_settings_screen_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/screens/safety_settings_screen.dart mobile/lib/providers/app_providers.dart mobile/test/screens/safety_settings_screen_test.dart
git commit -m "feat(safety): add follow-based trusted moderator option"
```

## Chunk 5: Final Verification

### Task 5: Run focused verification and review diff

**Files:**
- Review: all touched files from prior chunks

- [ ] **Step 1: Run targeted tests**

Run:

```bash
cd mobile && flutter test \
  test/services/moderation_label_service_test.dart \
  test/services/video_event_service_content_filter_test.dart \
  test/services/nsfw_content_filter_test.dart \
  test/screens/safety_settings_screen_test.dart
```

Expected: PASS.

- [ ] **Step 2: Run targeted analyze**

Run:

```bash
cd mobile && flutter analyze --no-pub \
  lib/services/moderation_label_service.dart \
  lib/services/effective_content_labels.dart \
  lib/services/video_event_service.dart \
  lib/services/nsfw_content_filter.dart \
  lib/screens/safety_settings_screen.dart \
  test/services/moderation_label_service_test.dart \
  test/services/video_event_service_content_filter_test.dart \
  test/services/nsfw_content_filter_test.dart \
  test/screens/safety_settings_screen_test.dart
```

Expected: `No issues found!`

- [ ] **Step 3: Review diff for semantic boundaries**

Confirm:
- `contentWarningLabels` still means creator self-labels
- `moderationLabels` still means FunnelCake/server moderation labels
- trusted third-party labels are only applied at filtering/resolution boundaries

- [ ] **Step 4: Commit final polish if needed**

```bash
git add <touched files>
git commit -m "test(filters): finalize trusted moderation coverage"
```
