# Collaborator Invite Acceptance Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the mobile-side collaborator invite foundation: role-based collaborator tags, encrypted invite delivery, and non-blocking publish behavior.

**Architecture:** Keep video events canonical and creator-authored. Publish pending collaborator role tags on the video event, then send NIP-17 invite DMs through the existing DM repository. Leave public acceptance events and confirmed-collab feed reads blocked on the Funnelcake read model/event-kind agreement.

**Tech Stack:** Flutter/Dart, `flutter_test`, `mocktail`, `dm_repository`, `nostr_client`, existing `VideoPublishService` and `VideoEventPublisher`.

---

## Chunk 1: Role-Based Collaborator Tags

### Task 1: Publish role-based `p` tags

**Files:**
- Modify: `mobile/lib/services/video_event_publisher.dart`
- Test: `mobile/test/services/video_event_publisher_collaborator_tags_test.dart`

- [ ] **Step 1: Write the failing test**

Create a test that publishes a direct upload with one collaborator pubkey and captures tags passed to `AuthService.createAndSignEvent`. Expect:

```dart
['p', collaboratorPubkey, 'wss://relay.divine.video', 'Collaborator']
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test --no-pub test/services/video_event_publisher_collaborator_tags_test.dart`

Expected: FAIL because current tags only include `['p', pubkey, relay]`.

- [ ] **Step 3: Write minimal implementation**

Change collaborator tag creation in `VideoEventPublisher.publishDirectUpload` to include the role field.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd mobile && flutter test --no-pub test/services/video_event_publisher_collaborator_tags_test.dart`

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/services/video_event_publisher.dart mobile/test/services/video_event_publisher_collaborator_tags_test.dart
git commit -m "feat(collabs): publish collaborator role tags"
```

### Task 2: Preserve role tags when editing video metadata

**Files:**
- Modify: `mobile/lib/widgets/share_video_menu.dart`
- Test: extend `mobile/test/services/video_event_publisher_collaborator_tags_test.dart` only if practical, otherwise cover manually with analyzer until widget edit tests are added.

- [ ] **Step 1: Update edit republish tag creation**

Change post-publish edit metadata from `['p', pubkey]` to:

```dart
['p', pubkey, 'wss://relay.divine.video', 'Collaborator']
```

- [ ] **Step 2: Run analyzer on touched files**

Run: `cd mobile && dart analyze lib/widgets/share_video_menu.dart`

- [ ] **Step 3: Commit**

```bash
git add mobile/lib/widgets/share_video_menu.dart
git commit -m "feat(collabs): preserve collaborator role on edits"
```

## Chunk 2: Encrypted Invite Payloads

### Task 3: Allow structured tags on NIP-17 sends

**Files:**
- Modify: `mobile/packages/dm_repository/lib/src/dm_repository.dart`
- Test: `mobile/packages/dm_repository/test/src/dm_repository_test.dart`

- [ ] **Step 1: Write the failing test**

Add a test showing `DmRepository.sendMessage` forwards caller-supplied tags to `NIP17MessageService.sendPrivateMessage`.

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile/packages/dm_repository && flutter test --no-pub test/src/dm_repository_test.dart --plain-name "sendMessage forwards additional NIP-17 tags"`

- [ ] **Step 3: Add optional `additionalTags` parameter**

Add `List<List<String>> additionalTags = const []` to `sendMessage`, appending it before any reply tag.

- [ ] **Step 4: Run the focused test**

Run the same focused test and expect PASS.

- [ ] **Step 5: Commit**

```bash
git add mobile/packages/dm_repository/lib/src/dm_repository.dart mobile/packages/dm_repository/test/src/dm_repository_test.dart
git commit -m "feat(dm): allow structured nip17 message tags"
```

### Task 4: Add collaborator invite service

**Files:**
- Create: `mobile/lib/services/collaborator_invite_service.dart`
- Create: `mobile/test/services/collaborator_invite_service_test.dart`

- [ ] **Step 1: Write failing tests**

Cover:
- invite content includes a readable fallback message
- tags include `["divine", "collab-invite"]`, `a`, creator `p`, role, optional title, optional thumb
- send returns failure when `DmRepository.sendMessage` fails

- [ ] **Step 2: Run tests to verify failure**

Run: `cd mobile && flutter test --no-pub test/services/collaborator_invite_service_test.dart`

- [ ] **Step 3: Implement service**

Create a small service that depends on `DmRepository` and sends one invite per collaborator.

- [ ] **Step 4: Run tests**

Run: `cd mobile && flutter test --no-pub test/services/collaborator_invite_service_test.dart`

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/services/collaborator_invite_service.dart mobile/test/services/collaborator_invite_service_test.dart
git commit -m "feat(collabs): add encrypted invite service"
```

## Chunk 3: Publish Flow Wiring

### Task 5: Send invites after successful video publish

**Files:**
- Modify: `mobile/lib/services/video_publish/video_publish_service.dart`
- Modify: `mobile/lib/providers/video_publish_provider.dart`
- Modify: `mobile/lib/main.dart`
- Test: `mobile/test/services/video_publish/video_publish_service_test.dart`

- [ ] **Step 1: Write failing tests**

Add tests showing:
- successful publish with collaborators calls `CollaboratorInviteService.sendInvites`
- invite failure does not turn a successful video publish into `PublishError`

- [ ] **Step 2: Run focused tests to verify failure**

Run: `cd mobile && flutter test --no-pub test/services/video_publish/video_publish_service_test.dart --plain-name "collaborator invites"`

- [ ] **Step 3: Implement optional service dependency**

Add optional `CollaboratorInviteService? collaboratorInviteService` to `VideoPublishService`. After successful video event publish and before draft deletion, compute the video address from `pendingUpload.videoId`, `pubkey`, and kind `34236`, then call `sendInvites`.

- [ ] **Step 4: Wire provider**

Pass `CollaboratorInviteService(dmRepository: ref.read(dmRepositoryProvider))` from `video_publish_provider.dart` and `main.dart`.

- [ ] **Step 5: Run tests**

Run: `cd mobile && flutter test --no-pub test/services/video_publish/video_publish_service_test.dart`

- [ ] **Step 6: Commit**

```bash
git add mobile/lib/services/video_publish/video_publish_service.dart mobile/lib/providers/video_publish_provider.dart mobile/lib/main.dart mobile/test/services/video_publish/video_publish_service_test.dart
git commit -m "feat(collabs): send invites after publishing video"
```

## Chunk 4: Copy And Verification

### Task 6: Rename creator UI copy from add to invite

**Files:**
- Modify: `mobile/lib/l10n/app_en.arb`
- Run generated localization if required by repo workflow

- [ ] **Step 1: Update English strings**

Change collaborator creator-facing copy from "Add collaborator" to "Invite collaborator" where it starts an invite.

- [ ] **Step 2: Generate localization outputs**

Run: `cd mobile && flutter gen-l10n` if generated l10n files change in this repo workflow.

- [ ] **Step 3: Run l10n tests**

Run: `cd mobile && flutter test --no-pub test/l10n/arb_consistency_test.dart`

- [ ] **Step 4: Commit**

```bash
git add mobile/lib/l10n mobile/test/l10n/arb_consistency_test.dart
git commit -m "feat(collabs): rename collaborator add copy to invite"
```

### Task 7: Final verification

**Files:**
- All touched files

- [ ] **Step 1: Run focused test suite**

```bash
cd mobile
flutter test --no-pub test/services/video_event_publisher_collaborator_tags_test.dart
flutter test --no-pub test/services/collaborator_invite_service_test.dart
flutter test --no-pub test/services/video_publish/video_publish_service_test.dart
```

- [ ] **Step 2: Run package DM tests touched by this change**

Run: `cd mobile/packages/dm_repository && flutter test --no-pub test/src/dm_repository_test.dart --plain-name "sendMessage forwards additional NIP-17 tags"`

- [ ] **Step 3: Analyze touched Dart files**

Run: `cd mobile && dart analyze lib/services/collaborator_invite_service.dart lib/services/video_event_publisher.dart lib/services/video_publish/video_publish_service.dart lib/providers/video_publish_provider.dart lib/main.dart`

- [ ] **Step 4: Review diff**

Run: `git diff --stat origin/main...HEAD` and `git status --short`.
