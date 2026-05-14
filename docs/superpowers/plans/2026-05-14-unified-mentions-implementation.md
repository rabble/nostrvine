# Unified Mentions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Publish resolved user mentions consistently from comments, video captions/overlays, and profile bios using one small app-layer mention helper.

**Architecture:** Add one shared app-layer helper for resolving mention text and building generic mention `p` tags. Keep UI state local to existing surfaces. Wire comments and videos to emit generic `["p", pubkey, "wss://relay.divine.video", "mention"]` tags, while profile kind 0 canonicalizes bio text to `nostr:npub...` without adding tags.

**Tech Stack:** Flutter/Dart, BLoC, Riverpod legacy paths, Nostr kind 1111 comments, NIP-71 video events, kind 0 profile metadata, existing `ProfileRepository` search APIs.

---

## Task 1: Shared Mention Helper

**Files:**
- Create: `mobile/lib/services/mention_resolution_service.dart`
- Test: `mobile/test/services/mention_resolution_service_test.dart`

- [ ] Write failing tests for selected mention canonicalization, typed token parsing, email/Nostr-reference exclusion, exact cached/API matches, ambiguous matches, self-match exclusion, invalid pubkey skipping, collaborator exclusion, and generic mention tag building.
- [ ] Run `cd mobile && flutter test test/services/mention_resolution_service_test.dart` and confirm the tests fail because the helper does not exist.
- [ ] Implement one `MentionResolutionService` class plus small value objects in the same file. Keep parsing and tag construction private or static internals unless tests need a public call.
- [ ] Keep typed remote resolution bounded: dedupe tokens, max five API lookups, one two-second timeout for the resolution pass.
- [ ] Run `cd mobile && flutter test test/services/mention_resolution_service_test.dart`.
- [ ] Commit: `feat: add shared mention resolution helper`.

## Task 2: Comment Repository Tags

**Files:**
- Modify: `mobile/packages/comments_repository/lib/src/comments_repository.dart`
- Test: `mobile/packages/comments_repository/test/src/comments_repository_test.dart`

- [ ] Write failing repository tests showing `postComment(mentionedPubkeys: [...])` appends generic mention `p` tags after required NIP-22 tags, skips invalid/empty pubkeys, and does not duplicate root/parent author `p` tags.
- [ ] Run `cd mobile && flutter test packages/comments_repository/test/src/comments_repository_test.dart` and confirm the new tests fail.
- [ ] Add optional `List<String> mentionedPubkeys = const []` to `postComment`.
- [ ] Append `["p", pubkey, "wss://relay.divine.video", "mention"]` for valid full hex pubkeys not already used by NIP-22 root/parent tags.
- [ ] Run `cd mobile && flutter test packages/comments_repository/test/src/comments_repository_test.dart`.
- [ ] Commit: `feat(comments): publish mention p tags`.

## Task 3: Video Event Publisher Tags

**Files:**
- Modify: `mobile/lib/services/video_event_publisher.dart`
- Test: `mobile/test/services/video_event_publisher_test.dart`
- Test: `mobile/test/services/video_event_publisher_collaborator_tags_test.dart`

- [ ] Write failing publisher tests showing `mentionedPubkeys` adds generic mention `p` tags to kind 34236 publishes, preserves collaborator role tags, excludes collaborator pubkeys from generic mention tags, and skips invalid/empty pubkeys.
- [ ] Run `cd mobile && flutter test test/services/video_event_publisher_test.dart test/services/video_event_publisher_collaborator_tags_test.dart` and confirm the new tests fail.
- [ ] Add `mentionedPubkeys` to `publishVideoEvent` and `publishDirectUpload`.
- [ ] Append generic mention tags separately from collaborator tags, using the same relay hint and role marker as the spec.
- [ ] Run `cd mobile && flutter test test/services/video_event_publisher_test.dart test/services/video_event_publisher_collaborator_tags_test.dart`.
- [ ] Commit: `feat(video): publish mention p tags`.

## Task 4: Comments Bloc Wiring

**Files:**
- Modify: `mobile/lib/blocs/comments/comments_bloc.dart`
- Modify: `mobile/lib/blocs/comments/comments_event.dart`
- Modify: `mobile/lib/blocs/comments/comments_state.dart`
- Modify: `mobile/lib/screens/comments/comments_screen.dart`
- Modify: `mobile/lib/screens/comments/widgets/comment_input.dart`
- Modify: `mobile/lib/screens/comments/widgets/mention_overlay.dart`
- Test: `mobile/test/blocs/comments/comments_bloc_test.dart`
- Test: `mobile/test/screens/comments/comment_input_test.dart`
- Test: `mobile/test/screens/comments/widgets/mention_overlay_test.dart`

- [ ] Write failing tests showing selected mentions are resolved to canonical `nostr:npub...` content and passed to `CommentsRepository.postComment(mentionedPubkeys: ...)`.
- [ ] Write a failing test showing typed-but-unselected `@name` resolves through the helper when there is one exact match.
- [ ] Run targeted tests and confirm failures.
- [ ] Inject/use `MentionResolutionService` in `CommentsBloc`.
- [ ] Preserve existing comment autocomplete UI; pass selected hex pubkeys from overlay/input into bloc state.
- [ ] Replace ad hoc `displayName -> npub` replacement with helper output.
- [ ] Run the targeted comments tests.
- [ ] Commit: `feat(comments): resolve mentions before publish`.

## Task 5: Video Publish Service Wiring

**Files:**
- Modify: `mobile/lib/services/video_publish/video_publish_service.dart`
- Modify: `mobile/lib/providers/video_publish_provider.dart`
- Modify: `mobile/lib/main.dart`
- Test: `mobile/test/services/video_publish/video_publish_service_test.dart`
- Test: `mobile/test/providers/video_publish_provider_test.dart`

- [ ] Write failing tests showing video publish resolves typed mentions from draft description and overlay text, excludes collaborators, and passes `mentionedPubkeys` to `VideoEventPublisher`.
- [ ] Run targeted tests and confirm failures.
- [ ] Inject/use `MentionResolutionService` in `VideoPublishService`.
- [ ] Resolve mentions from `draft.description` plus text layer strings recoverable from editor state/history without adding editor metadata.
- [ ] Keep publish non-blocking on resolution failure: publish without unresolved mention tags.
- [ ] Run targeted video publish tests.
- [ ] Commit: `feat(video): resolve mentions during publish`.

## Task 6: Profile Bio Canonicalization

**Files:**
- Modify: `mobile/lib/blocs/profile_editor/profile_editor_bloc.dart`
- Test: `mobile/test/blocs/profile_editor/profile_editor_bloc_test.dart`
- Test: `mobile/test/widgets/profile/profile_header_widget_test.dart`
- Test: `mobile/test/widgets/linkified_text/linkified_text_span_builder_test.dart`

- [ ] Write failing tests showing `ProfileSaved(about: "hi @alice")` saves `about` with canonical `nostr:npub...` when there is one exact match.
- [ ] Write/assert kind 0 save still uses no tags at repository/client boundary.
- [ ] Run targeted tests and confirm failures.
- [ ] Inject/use `MentionResolutionService` in `ProfileEditorBloc`.
- [ ] Canonicalize profile bio mentions before `ProfileRepository.saveProfileEvent`, preserving unresolved text.
- [ ] Run targeted profile tests.
- [ ] Commit: `feat(profile): canonicalize bio mentions`.

## Task 7: Final Verification

**Files:**
- Review all changed files.

- [ ] Run `cd mobile && flutter test test/services/mention_resolution_service_test.dart`.
- [ ] Run `cd mobile && flutter test test/blocs/comments/comments_bloc_test.dart packages/comments_repository/test/src/comments_repository_test.dart`.
- [ ] Run `cd mobile && flutter test test/services/video_publish/video_publish_service_test.dart test/services/video_event_publisher_test.dart test/services/video_event_publisher_collaborator_tags_test.dart`.
- [ ] Run `cd mobile && flutter test test/blocs/profile_editor/profile_editor_bloc_test.dart test/widgets/profile/profile_header_widget_test.dart test/widgets/linkified_text/linkified_text_span_builder_test.dart`.
- [ ] Run `cd mobile && flutter analyze`.
- [ ] Review `git diff` for stray edits, generated junk, logs, and broad refactors.
- [ ] Commit any integration fixups.
