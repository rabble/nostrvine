# Badge Empowerment Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a native Divine mobile badge hub that shows awarded and issued NIP-58 badges, supports accept/remove/hide actions, and opens `badges.divine.video` through the existing embedded Nostr app sandbox.

**Architecture:** Keep protocol parsing and relay/publish behavior in a focused badge service, expose state through a BLoC/Cubit, and keep UI widgets thin. Reuse the existing `NostrAppSandboxScreen` and `nostr_app_bridge_repository` manifest/policy system for the full web badge app.

**Tech Stack:** Flutter, BLoC/Cubit, Riverpod for dependency wiring, `nostr_client`, `nostr_sdk`, `shared_preferences`, `mocktail`, `flutter_test`.

---

## Chunk 1: Protocol Constants, Parser, And Repository

### Task 1: Add NIP-58 constants and parsing helpers

**Files:**
- Modify: `mobile/packages/nostr_sdk/lib/event_kind.dart`
- Create: `mobile/lib/services/badges/nip58_badge_models.dart`
- Create: `mobile/lib/services/badges/nip58_badge_parser.dart`
- Test: `mobile/test/services/badges/nip58_badge_parser_test.dart`

- [ ] **Step 1: Write parser tests**

Cover:
- current profile badges kind `10008`
- legacy profile badges kind `30008` with `d=profile_badges`
- consecutive `a`/`e` pairs
- orphan `a` or `e` tags ignored
- badge award event extracts `a` coordinate and all recipient `p` tags
- badge definition event extracts `d`, `name`, `description`, `image`, and `thumb`

- [ ] **Step 2: Run parser tests and verify they fail**

Run: `cd mobile && flutter test test/services/badges/nip58_badge_parser_test.dart`

Expected: FAIL because files do not exist.

- [ ] **Step 3: Implement models and parser**

Add small immutable Dart classes:
- `Nip58BadgeDefinition`
- `Nip58BadgeAward`
- `Nip58ProfileBadgeRef`
- `Nip58ProfileBadges`

Add parser helpers:
- `Nip58BadgeParser.parseDefinition(Event event)`
- `Nip58BadgeParser.parseAward(Event event)`
- `Nip58BadgeParser.parseProfileBadges(Event event)`
- `Nip58BadgeParser.isProfileBadgesEvent(Event event)`

Update `EventKind`:
- add `profileBadges = 10008`
- add `badgeSet = 30008`
- keep deprecated `badgeAccept = 30008` only if needed for compatibility and mark it deprecated

- [ ] **Step 4: Run parser tests and verify they pass**

Run: `cd mobile && flutter test test/services/badges/nip58_badge_parser_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add mobile/packages/nostr_sdk/lib/event_kind.dart mobile/lib/services/badges/nip58_badge_models.dart mobile/lib/services/badges/nip58_badge_parser.dart mobile/test/services/badges/nip58_badge_parser_test.dart
git commit -m "feat(badges): parse nip58 badge events"
```

### Task 2: Add badge repository with accept/remove/hide/load behavior

**Files:**
- Create: `mobile/lib/services/badges/badge_repository.dart`
- Test: `mobile/test/services/badges/badge_repository_test.dart`

- [ ] **Step 1: Write repository tests**

Use mocktail `NostrClient` and a small fake auth adapter callback for signing:
- `loadAwardedBadges` queries kind `8` with `p: [currentPubkey]`
- accepted state is derived from latest `10008`
- legacy `30008` profile badges are read when newer than absent current event
- `acceptAward` signs and publishes kind `10008`
- `removeAward` signs and publishes kind `10008` without the removed pair
- `hideAward` stores dismissed award id in `SharedPreferences`
- `loadIssuedBadges` queries kind `8` with `authors: [currentPubkey]` and detects recipient acceptance

- [ ] **Step 2: Run repository tests and verify they fail**

Run: `cd mobile && flutter test test/services/badges/badge_repository_test.dart`

Expected: FAIL because repository does not exist.

- [ ] **Step 3: Implement repository**

Constructor dependencies:
- `NostrClient nostrClient`
- `SharedPreferences sharedPreferences`
- `String? Function() currentPubkey`
- `Future<Event?> Function({required int kind, required String content, required List<List<String>> tags}) signEvent`

Public methods:
- `Future<BadgeDashboardData> loadDashboard()`
- `Future<List<BadgeAwardViewData>> loadAwardedBadges()`
- `Future<List<IssuedBadgeViewData>> loadIssuedBadges({int recipientCheckLimit = 50})`
- `Future<void> acceptAward(BadgeAwardViewData award)`
- `Future<void> removeAward(BadgeAwardViewData award)`
- `Future<void> hideAward(String awardEventId)`

Implementation notes:
- Query current profile badges with filters for kind `10008` and legacy kind `30008`.
- Select newest replaceable event per kind and prefer current `10008`.
- Preserve existing ordered `a`/`e` pairs.
- Use full event ids and coordinates in state and tests.

- [ ] **Step 4: Run repository tests and verify they pass**

Run: `cd mobile && flutter test test/services/badges/badge_repository_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/services/badges/badge_repository.dart mobile/test/services/badges/badge_repository_test.dart
git commit -m "feat(badges): add badge repository"
```

## Chunk 2: Embedded Badge App Manifest

### Task 3: Bundle `badges.divine.video` as an approved Nostr app

**Files:**
- Modify: `mobile/packages/nostr_app_bridge_repository/lib/src/preloaded_nostr_apps.dart`
- Modify: `mobile/packages/nostr_app_bridge_repository/test/nostr_app_directory_service_test.dart`
- Modify: `mobile/packages/nostr_app_bridge_repository/test/nostr_app_bridge_policy_test.dart`

- [ ] **Step 1: Write failing manifest tests**

Add assertions that cache-only approved apps include:
- slug `badges`
- name `Divine Badges`
- launch URL `https://badges.divine.video/me`
- allowed origin `https://badges.divine.video`
- signing kinds include `3`, `8`, `10002`, `10008`, `30008`, and `30009`

Add policy tests that a badge app manifest allows `signEvent:10008` and denies an unrelated kind.

- [ ] **Step 2: Run bridge package tests and verify they fail**

Run: `cd mobile && flutter test packages/nostr_app_bridge_repository/test/nostr_app_directory_service_test.dart packages/nostr_app_bridge_repository/test/nostr_app_bridge_policy_test.dart`

Expected: FAIL because the bundled badge app is absent.

- [ ] **Step 3: Add bundled app entry**

Add a `_badgeSignEventKinds` list and `_buildPreloadedApp` entry with sort order after existing Divine-owned app entries. Do not broaden the shared signing kind list for every app.

- [ ] **Step 4: Run bridge package tests and verify they pass**

Run: `cd mobile && flutter test packages/nostr_app_bridge_repository/test/nostr_app_directory_service_test.dart packages/nostr_app_bridge_repository/test/nostr_app_bridge_policy_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add mobile/packages/nostr_app_bridge_repository/lib/src/preloaded_nostr_apps.dart mobile/packages/nostr_app_bridge_repository/test/nostr_app_directory_service_test.dart mobile/packages/nostr_app_bridge_repository/test/nostr_app_bridge_policy_test.dart
git commit -m "feat(apps): bundle divine badges integration"
```

## Chunk 3: BLoC, Screen, Routing, And Providers

### Task 4: Add badge BLoC/Cubit

**Files:**
- Create: `mobile/lib/blocs/badges/badges_cubit.dart`
- Create: `mobile/lib/blocs/badges/badges_state.dart`
- Test: `mobile/test/blocs/badges/badges_cubit_test.dart`

- [ ] **Step 1: Write BLoC tests**

Cover:
- `load` emits loading then loaded
- `acceptAward` delegates to repository and reloads
- `removeAward` delegates to repository and reloads
- `hideAward` delegates to repository and removes item from state
- errors preserve previous data when available

- [ ] **Step 2: Run BLoC tests and verify they fail**

Run: `cd mobile && flutter test test/blocs/badges/badges_cubit_test.dart`

Expected: FAIL because cubit does not exist.

- [ ] **Step 3: Implement Cubit**

Keep state simple:
- `BadgesState(status, awarded, issued, errorMessage, actionAwardId)`

The cubit should call repository methods and avoid UI dependencies.

- [ ] **Step 4: Run BLoC tests and verify they pass**

Run: `cd mobile && flutter test test/blocs/badges/badges_cubit_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/blocs/badges/badges_cubit.dart mobile/lib/blocs/badges/badges_state.dart mobile/test/blocs/badges/badges_cubit_test.dart
git commit -m "feat(badges): add badges cubit"
```

### Task 5: Add screen, provider wiring, and route

**Files:**
- Modify: `mobile/lib/providers/app_providers.dart`
- Create: `mobile/lib/screens/badges/badges_screen.dart`
- Modify: `mobile/lib/router/app_router.dart`
- Modify: `mobile/lib/screens/settings/settings_screen.dart`
- Test: `mobile/test/screens/badges/badges_screen_test.dart`

- [ ] **Step 1: Write widget tests**

Cover:
- loading state
- empty awarded state
- awarded row with accepted state
- accept/remove/hide buttons dispatch cubit calls
- manage tab launches sandbox path with badge app entry

- [ ] **Step 2: Run widget tests and verify they fail**

Run: `cd mobile && flutter test test/screens/badges/badges_screen_test.dart`

Expected: FAIL because screen does not exist.

- [ ] **Step 3: Add provider and route**

Add a repository provider in `app_providers.dart` using:
- `nostrServiceProvider`
- `authServiceProvider`
- `sharedPreferencesProvider`

Add route:
- path `/badges`
- name `badges`

Add settings tile:
- title `Badges`
- subtitle `See what you have earned and what people accepted.`
- icon `Icons.workspace_premium_outlined` or closest existing Divine icon

- [ ] **Step 4: Implement screen**

Use a full-screen `Scaffold` with `DiVineAppBar`, dark theme, constrained width, and a tab/segmented layout. Keep rows compact and scannable. Use full IDs internally and let UI overflow/truncate visually only where necessary.

- [ ] **Step 5: Run widget tests and verify they pass**

Run: `cd mobile && flutter test test/screens/badges/badges_screen_test.dart`

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add mobile/lib/providers/app_providers.dart mobile/lib/screens/badges/badges_screen.dart mobile/lib/router/app_router.dart mobile/lib/screens/settings/settings_screen.dart mobile/test/screens/badges/badges_screen_test.dart
git commit -m "feat(badges): add native badges screen"
```

## Chunk 4: Verification

### Task 6: Focused and broader verification

**Files:**
- No source edits expected.

- [ ] **Step 1: Run focused tests**

Run:

```bash
cd mobile
flutter test test/services/badges/nip58_badge_parser_test.dart
flutter test test/services/badges/badge_repository_test.dart
flutter test test/blocs/badges/badges_cubit_test.dart
flutter test test/screens/badges/badges_screen_test.dart
flutter test packages/nostr_app_bridge_repository/test/nostr_app_directory_service_test.dart packages/nostr_app_bridge_repository/test/nostr_app_bridge_policy_test.dart
```

Expected: all pass.

- [ ] **Step 2: Run static analysis**

Run: `cd mobile && flutter analyze`

Expected: no new errors.

- [ ] **Step 3: Review diff**

Run:

```bash
git status --short
git diff --stat origin/main...HEAD
git diff origin/main...HEAD -- mobile/lib mobile/test mobile/packages/nostr_app_bridge_repository mobile/packages/nostr_sdk docs/superpowers
```

Expected: only badge-related files and docs changed.

- [ ] **Step 4: Final commit if needed**

If verification fixes were needed:

```bash
git add <specific changed files>
git commit -m "fix(badges): address badge verification issues"
```

- [ ] **Step 5: Prepare PR**

After the branch is clean and all relevant verification has passed:

```bash
git status --short
git push -u origin feat/badges-empowerment
gh pr create --title "feat(badges): add badge management surface" --body "<summary and tests>"
```
