# Profile Pinning and Ordering Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let creators pin up to 12 owned addressable videos to the start of their profile while every viewer, the grid, and fullscreen playback observe one identical ordered sequence.

**Architecture:** Add a focused `profile_pins_repository` package that owns the lossless kind-10001 event, owner-scoped cache, relay subscription, serialized read-modify-write, and pin mutations. `ProfileFeedCubit` remains the composition boundary: it combines cached/resolved pin coordinates with the existing newest-first profile feed through one pure exact-coordinate ordering function. The grid only renders the cubit's ordered sequence, prefixes transient uploads, and dispatches owner actions back through the bloc.

**Tech Stack:** Flutter/Dart, BLoC, Riverpod dependency injection, Nostr NIP-51 kind 10001, NIP-71 kind 34236 addressable coordinates, SharedPreferences, `nostr_client`, `videos_repository`, `divine_ui`, Flutter l10n.

---

## Decisions made explicit before implementation

- A managed identity is the exact, case-preserving `34236:<owner-pubkey>:<d-tag>` coordinate. Never use `stableId`, a lowercased feed key, or event ID as the stored pin identity.
- Kind 10001 `a` tags are Divine's NIP-71 extension to the NIP-51 pinned-list event. Only valid kind-34236 coordinates authored by the event owner are managed. Every other tag and `content` is preserved byte-for-byte.
- The cap counts every unique valid managed reference in the stored list, including unresolved or hidden references. Imported lists over 12 are displayed using their first 12 managed references, never truncated on save, and may be reduced by unpinning; new pins are rejected while the stored list remains at or above the cap.
- A cached identity list can reorder already-loaded videos immediately. Missing pinned payloads resolve asynchronously in one call to `VideosRepository.getVideosByAddressableIds`; no profile pagination waits on that call.
- Pin and unpin re-read the full authoritative replaceable event with `requireAllRelaysSettled: true`, serialize per owner, and update the local cache only after at least one relay returns `OK true`.
- Unrelated tags retain their exact arrays and relative order. Managed tags are replaced at the first managed-tag slot; surviving managed tags retain their extra fields.
- Owner Pin is unavailable until the initial cached snapshot has loaded and is omitted for a legacy/non-addressable video. Retry repeats the requested mutation against a fresh authoritative read, never a stale whole-list candidate.
- Tile semantics announce both overall grid position and pinned rank. The decorative badge is excluded from semantics.
- Transient uploads stay outside the pure published-video ordering function and are prefixed by the grid. They are never included in fullscreen seeds.

## File map

### New package

- Create `mobile/packages/profile_pins_repository/pubspec.yaml` — package dependencies and test configuration.
- Create `mobile/packages/profile_pins_repository/lib/profile_pins_repository.dart` — public exports.
- Create `mobile/packages/profile_pins_repository/lib/src/profile_pin_list.dart` — raw lossless event snapshot and public display snapshot.
- Create `mobile/packages/profile_pins_repository/lib/src/profile_pins_codec.dart` — exact coordinate validation, parsing, and lossless tag replacement.
- Create `mobile/packages/profile_pins_repository/lib/src/local_profile_pins_cache.dart` — owner-scoped SharedPreferences cache.
- Create `mobile/packages/profile_pins_repository/lib/src/profile_pins_repository.dart` — interface and mutation result types.
- Create `mobile/packages/profile_pins_repository/lib/src/profile_pins_repository_impl.dart` — cache-first streams, relay reads/subscriptions, serialized mutations, and confirmed publishing.
- Create matching tests under `mobile/packages/profile_pins_repository/test/src/`.

### Pure ordering and identity

- Create `mobile/packages/videos_repository/lib/src/profile_pinned_order.dart`.
- Modify `mobile/packages/videos_repository/lib/videos_repository.dart` to export it.
- Create `mobile/packages/videos_repository/test/src/profile_pinned_order_test.dart`.
- Modify `mobile/lib/utils/video_identity.dart` and `mobile/test/utils/video_identity_test.dart` for addressable-coordinate lookup.

### App composition

- Create `mobile/lib/providers/profile_pins_provider.dart` and `mobile/test/providers/profile_pins_provider_test.dart`.
- Modify `mobile/pubspec.yaml` to add the workspace member and dependency.
- Modify `mobile/lib/blocs/profile_feed/profile_feed_event.dart`, `profile_feed_state.dart`, `profile_feed_cubit.dart`, and `profile_feed_scope.dart`.
- Create focused pin tests in `mobile/test/blocs/profile_feed/profile_feed_pins_test.dart` and `profile_feed_scope_pins_test.dart`.

### Fullscreen and UI

- Modify `mobile/lib/widgets/profile/profile_video_feed_view.dart`, `mobile/lib/screens/feed/pooled_fullscreen_video_feed_screen.dart`, and `mobile/lib/router/pooled_fullscreen_feed_route.dart`.
- Create `mobile/test/widgets/profile/profile_video_feed_pinning_test.dart`.
- Add `mobile/assets/icon/push_pin_simple.svg`; modify `mobile/packages/divine_ui/lib/src/icon/divine_icon.dart` and its test.
- Create `mobile/lib/widgets/profile/profile_pin_badge.dart` and `mobile/test/widgets/profile/profile_pin_badge_test.dart`.
- Modify `mobile/lib/widgets/profile/profile_videos_grid.dart` and create `mobile/test/widgets/profile/profile_videos_grid_pins_test.dart`.
- Modify `mobile/lib/l10n/app_en.arb`, `mobile/test/l10n/arb_consistency_test.dart`, and generated l10n outputs.

---

### Task 1: Exact-coordinate pure ordering

**Files:**
- Create: `mobile/packages/videos_repository/lib/src/profile_pinned_order.dart`
- Modify: `mobile/packages/videos_repository/lib/videos_repository.dart`
- Test: `mobile/packages/videos_repository/test/src/profile_pinned_order_test.dart`

- [ ] **Step 1: Write failing pure-order tests**

Cover pin-first ordering, preserved pin order, preserved unpinned order, duplicate references, shuffled resolver results, unavailable references, a rejected visibility predicate, foreign authors, exact-case d-tags, duplicate feed entries, and metadata replacement with a new event ID but the same coordinate.

The wished-for API is:

```dart
final ordered = orderProfileVideosWithPins(
  ownerPubkey: ownerPubkey,
  orderedPinCoordinates: [videoB.addressableId!, videoA.addressableId!],
  resolvedPinnedVideos: [videoA, videoB],
  feedVideos: [videoC, videoB, videoA],
  isVisible: (video) => !blockedIds.contains(video.id),
);

expect(ordered, equals([videoB, videoA, videoC]));
```

- [ ] **Step 2: Verify RED**

Run:

```bash
cd mobile/packages/videos_repository
flutter test test/src/profile_pinned_order_test.dart
```

Expected: FAIL because `orderProfileVideosWithPins` does not exist.

- [ ] **Step 3: Implement the minimal pure function**

Use exact coordinate equality and never sort either input:

```dart
typedef ProfileVideoVisibility = bool Function(VideoEvent video);

List<VideoEvent> orderProfileVideosWithPins({
  required String ownerPubkey,
  required List<String> orderedPinCoordinates,
  required List<VideoEvent> resolvedPinnedVideos,
  required List<VideoEvent> feedVideos,
  ProfileVideoVisibility isVisible = _alwaysVisible,
}) {
  final candidates = <String, VideoEvent>{};
  for (final video in [...resolvedPinnedVideos, ...feedVideos]) {
    final coordinate = video.addressableId;
    if (coordinate != null) candidates.putIfAbsent(coordinate, () => video);
  }

  final seenPins = <String>{};
  final emitted = <String>{};
  final result = <VideoEvent>[];
  for (final coordinate in orderedPinCoordinates) {
    if (!seenPins.add(coordinate)) continue;
    final video = candidates[coordinate];
    if (video == null ||
        video.pubkey != ownerPubkey ||
        video.addressableId != coordinate ||
        !isVisible(video)) {
      continue;
    }
    emitted.add(coordinate);
    result.add(video);
  }

  for (final video in feedVideos) {
    if (video.pubkey != ownerPubkey || !isVisible(video)) continue;
    final identity = video.addressableId ?? video.id;
    if (emitted.add(identity)) result.add(video);
  }
  return List.unmodifiable(result);
}

bool _alwaysVisible(VideoEvent _) => true;
```

- [ ] **Step 4: Verify GREEN and package regression safety**

```bash
cd mobile/packages/videos_repository
flutter test test/src/profile_pinned_order_test.dart test/src/profile_video_merge_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add mobile/packages/videos_repository/lib/src/profile_pinned_order.dart mobile/packages/videos_repository/lib/videos_repository.dart mobile/packages/videos_repository/test/src/profile_pinned_order_test.dart
git commit -m "feat(profile): add exact pin ordering"
```

### Task 2: Lossless profile-pin codec and cache

**Files:**
- Create: `mobile/packages/profile_pins_repository/pubspec.yaml`
- Create: `mobile/packages/profile_pins_repository/lib/profile_pins_repository.dart`
- Create: `mobile/packages/profile_pins_repository/lib/src/profile_pin_list.dart`
- Create: `mobile/packages/profile_pins_repository/lib/src/profile_pins_codec.dart`
- Create: `mobile/packages/profile_pins_repository/lib/src/local_profile_pins_cache.dart`
- Test: `mobile/packages/profile_pins_repository/test/src/profile_pins_codec_test.dart`
- Test: `mobile/packages/profile_pins_repository/test/src/local_profile_pins_cache_test.dart`
- Modify: `mobile/pubspec.yaml`

- [ ] **Step 1: Scaffold the workspace package and write codec/cache tests first**

Define these public shapes in the tests:

```dart
const snapshot = ProfilePinList(
  ownerPubkey: ownerPubkey,
  eventId: 'event-id',
  createdAt: 123,
  managedCoordinates: ['34236:$ownerPubkey:first'],
  tags: [
    ['client', 'other-app'],
    ['a', '34236:$ownerPubkey:first', 'wss://relay.example'],
    ['a', '30023:$ownerPubkey:article'],
  ],
  content: '{"opaque":true}',
);
```

Assert that parsing accepts only full-hex owner-authored kind-34236 coordinates, preserves d-tag case and colons, de-duplicates first occurrence, and retains every raw tag/content value. Assert that replacement inserts managed tags at the first managed slot, preserves unrelated tag order, retains extra fields for surviving tags, and removes all managed duplicates on unpin.

Cache tests must prove `read`, `write`, `watch`, corrupt-entry recovery, and owner isolation using `SharedPreferences.setMockInitialValues`.

- [ ] **Step 2: Verify RED**

```bash
cd mobile
flutter pub get
cd packages/profile_pins_repository
flutter test test/src/profile_pins_codec_test.dart test/src/local_profile_pins_cache_test.dart
```

Expected: FAIL because the package implementation is absent.

- [ ] **Step 3: Implement lossless models, validation, codec, and SharedPreferences cache**

Use these constants and contracts:

```dart
abstract final class ProfilePinsConstants {
  static const eventKind = 10001;
  static const videoKind = 34236;
  static const maxPins = 12;
}

class ProfilePinsSnapshot extends Equatable {
  const ProfilePinsSnapshot({
    required this.coordinates,
    required this.isLoading,
  });

  const ProfilePinsSnapshot.loading()
      : coordinates = const [],
        isLoading = true;

  final List<String> coordinates;
  final bool isLoading;
}
```

`ProfilePinList` must serialize the complete raw event shape to JSON. `LocalProfilePinsCache.watch(ownerPubkey:)` must emit the current cached value first and then future writes. The cache key must include the full owner pubkey and never log it in truncated form.

- [ ] **Step 4: Verify GREEN**

```bash
cd mobile/packages/profile_pins_repository
flutter test test/src/profile_pins_codec_test.dart test/src/local_profile_pins_cache_test.dart
flutter analyze
```

Expected: PASS with no analyzer findings.

- [ ] **Step 5: Commit**

```bash
git add mobile/pubspec.yaml mobile/pubspec.lock mobile/packages/profile_pins_repository
git commit -m "feat(profile): add pin list codec and cache"
```

### Task 3: Cache-first repository, relay subscription, and confirmed mutations

**Files:**
- Create: `mobile/packages/profile_pins_repository/lib/src/profile_pins_repository.dart`
- Create: `mobile/packages/profile_pins_repository/lib/src/profile_pins_repository_impl.dart`
- Test: `mobile/packages/profile_pins_repository/test/src/profile_pins_repository_impl_test.dart`

- [ ] **Step 1: Write repository tests for read, watch, mutation, and failure behavior**

Use an injected Nostr gateway so tests can deterministically return query health and publish acceptance without testing mocks rather than behavior:

```dart
abstract interface class ProfilePinsNostrGateway {
  Future<ProfilePinsRelayRead> readLatest(String ownerPubkey);
  Stream<Event> subscribe(String ownerPubkey);
  Future<PublishOutcome> publish(Event event);
}
```

Test cache-before-revalidation, newest replaceable winner selection (`createdAt` descending then event ID ascending), live subscription replacement, pin prepend, unpin remainder order, no-op without publish, 12-cap refusal, imported oversize preservation, unresolved-ref preservation, relay timeout/no-relay refusal, `OK false` rollback, cache update only after `acceptedByAny`, monotonically increasing `created_at`, and serialized concurrent owner mutations.

- [ ] **Step 2: Verify RED**

```bash
cd mobile/packages/profile_pins_repository
flutter test test/src/profile_pins_repository_impl_test.dart
```

Expected: FAIL because repository types are absent.

- [ ] **Step 3: Implement the interface and results**

```dart
enum ProfilePinsMutationStatus { submitted, noop, limitReached, failed }

class ProfilePinsMutationResult extends Equatable {
  const ProfilePinsMutationResult({
    required this.status,
    this.error,
  });

  final ProfilePinsMutationStatus status;
  final Object? error;
  bool get succeeded =>
      status == ProfilePinsMutationStatus.submitted ||
      status == ProfilePinsMutationStatus.noop;
}

abstract interface class ProfilePinsRepository {
  Stream<ProfilePinsSnapshot> watchPins({required String ownerPubkey});
  Future<void> refresh({required String ownerPubkey});
  Future<ProfilePinsMutationResult> pin({
    required String ownerPubkey,
    required String coordinate,
  });
  Future<ProfilePinsMutationResult> unpin({
    required String ownerPubkey,
    required String coordinate,
  });
  Future<void> dispose();
}
```

The concrete Nostr gateway must call `queryEventsDetailed` with kind 10001, the exact author, `limit: 1`, and `requireAllRelaysSettled: true`; it must reject `timedOut` and `noRelays`. Publishing must call `publishEventAwaitOk` and require `acceptedByAny`.

Serialize mutations with one future chain per owner. Each mutation performs a fresh authoritative read, applies `ProfilePinsCodec.replaceManagedCoordinates`, publishes, then caches and emits the accepted list. Never derive stored coordinates from resolved videos.

- [ ] **Step 4: Verify GREEN and full package coverage**

```bash
cd mobile/packages/profile_pins_repository
flutter test --coverage --test-randomize-ordering-seed random
flutter analyze
```

Expected: PASS. Inspect `coverage/lcov.info`; all public repository behaviors must be exercised.

- [ ] **Step 5: Commit**

```bash
git add mobile/packages/profile_pins_repository
git commit -m "feat(profile): publish profile pin lists"
```

### Task 4: Dependency injection and ProfileFeedCubit composition

**Files:**
- Create: `mobile/lib/providers/profile_pins_provider.dart`
- Test: `mobile/test/providers/profile_pins_provider_test.dart`
- Modify: `mobile/lib/blocs/profile_feed/profile_feed_event.dart`
- Modify: `mobile/lib/blocs/profile_feed/profile_feed_state.dart`
- Modify: `mobile/lib/blocs/profile_feed/profile_feed_cubit.dart`
- Modify: `mobile/lib/blocs/profile_feed/profile_feed_scope.dart`
- Test: `mobile/test/blocs/profile_feed/profile_feed_pins_test.dart`
- Test: `mobile/test/blocs/profile_feed/profile_feed_scope_pins_test.dart`

- [ ] **Step 1: Write provider and bloc tests first**

Tests must show that the provider reuses the canonical Nostr client and SharedPreferences, disposes the repository, and stays readable while relay readiness changes.

Bloc tests must show:

- cached coordinates emit before refresh completion;
- de-duplicated coordinates resolve in one `getVideosByAddressableIds` call;
- pins reorder base videos after every cold load, refresh, relay update, enrichment, filter change, and load-more;
- missing/blocked/tombstoned/foreign resolved videos remain omitted without deleting stored refs;
- pagination never duplicates a resolved pin;
- pin/unpin dispatch repository mutations and stream confirmation changes visible order;
- publish failure leaves visible order unchanged and emits retryable feedback;
- cap refusal leaves order unchanged and emits non-retry feedback;
- close cancels pin subscriptions.

- [ ] **Step 2: Verify RED**

```bash
cd mobile
flutter test test/providers/profile_pins_provider_test.dart test/blocs/profile_feed/profile_feed_pins_test.dart test/blocs/profile_feed/profile_feed_scope_pins_test.dart
```

Expected: FAIL because provider, events, and state are absent.

- [ ] **Step 3: Add state and event contracts**

```dart
enum ProfilePinAction { pin, unpin }
enum ProfilePinActionStatus { success, limitReached, failure }

class ProfilePinActionOutcome extends Equatable {
  const ProfilePinActionOutcome({
    required this.sequence,
    required this.action,
    required this.status,
    required this.coordinate,
  });

  final int sequence;
  final ProfilePinAction action;
  final ProfilePinActionStatus status;
  final String coordinate;
}
```

Extend `ProfileFeedState` with exact ordered pin coordinates, pinned coordinate membership, `isPinsLoading`, mutation-in-progress coordinates, and the last action outcome. Add internal snapshot-change events plus public pin, unpin, and retry events.

- [ ] **Step 4: Centralize every displayed-video emit through pin ordering**

Keep `_unfilteredVideos` newest-first and `_resolvedPinnedVideos` separate. Add one helper:

```dart
List<VideoEvent> _displayVideos() => orderProfileVideosWithPins(
  ownerPubkey: _authorPubkey,
  orderedPinCoordinates: state.pinCoordinates,
  resolvedPinnedVideos: _resolvedPinnedVideos,
  feedVideos: _unfilteredVideos,
  isVisible: _isVisibleProfileVideo,
);
```

Use it at every existing `videos:` emission boundary. Existing persisted profile snapshots continue to store base feed order, not pinned display order.

On pin snapshot changes, publish coordinates to state immediately so loaded matching videos reorder, then resolve the first 12 unique coordinates in one call and emit again. Use `restartable()` for resolver changes so stale results cannot win.

- [ ] **Step 5: Centralize snackbar feedback in ProfileFeedScope**

Listen for a changed action-outcome sequence. Success shows the localized pin/unpin message. Failure shows the localized error and `commonRetry`, dispatching a retry event. Limit refusal shows the localized cap message without retry. Snackbars provide the accessibility live-region announcement; do not duplicate it through `SystemChannels.accessibility`.

- [ ] **Step 6: Verify GREEN and existing profile regressions**

```bash
cd mobile
flutter test test/providers/profile_pins_provider_test.dart test/blocs/profile_feed/profile_feed_pins_test.dart test/blocs/profile_feed/profile_feed_scope_pins_test.dart test/blocs/profile_feed/profile_feed_cubit_test.dart
```

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add mobile/lib/providers/profile_pins_provider.dart mobile/lib/blocs/profile_feed mobile/test/providers/profile_pins_provider_test.dart mobile/test/blocs/profile_feed/profile_feed_pins_test.dart mobile/test/blocs/profile_feed/profile_feed_scope_pins_test.dart
git commit -m "feat(profile): compose pins into profile feeds"
```

### Task 5: Preserve ordered identity through fullscreen playback

**Files:**
- Modify: `mobile/lib/utils/video_identity.dart`
- Test: `mobile/test/utils/video_identity_test.dart`
- Modify: `mobile/lib/widgets/profile/profile_video_feed_view.dart`
- Modify: `mobile/lib/screens/feed/pooled_fullscreen_video_feed_screen.dart`
- Modify: `mobile/lib/router/pooled_fullscreen_feed_route.dart`
- Test: `mobile/test/widgets/profile/profile_video_feed_pinning_test.dart`

- [ ] **Step 1: Write failing identity and fullscreen tests**

Assert that addressable coordinate lookup finds a metadata replacement whose event ID changed. Assert that a pinned seed remains in exact displayed order while the fresh fullscreen scope catches up, that missing live videos append without re-sorting, and that live pin order becomes authoritative when it contains the tapped coordinate.

- [ ] **Step 2: Verify RED**

```bash
cd mobile
flutter test test/utils/video_identity_test.dart test/widgets/profile/profile_video_feed_pinning_test.dart
```

Expected: FAIL because coordinate lookup and ordered catch-up do not exist.

- [ ] **Step 3: Extend route identity and replace the sorting catch-up merge**

Add `initialAddressableId` to `ProfilePooledFullscreenVideoFeedArgs`, `ProfileVideoFeedView`, and the pooled route conversion. Extend `indexOfVideoIdentity` with exact `addressableId` matching.

While the fresh scope lacks the tapped target, keep the launch seed authoritative:

```dart
List<VideoEvent> mergeOrderedProfileSequences(
  List<VideoEvent> primary,
  List<VideoEvent> additions,
) {
  final seen = <String>{};
  return List.unmodifiable([
    for (final video in [...primary, ...additions])
      if (seen.add(video.addressableId ?? video.id)) video,
  ]);
}
```

Replace `mergeProfileFeedVideoLists(liveVideos, seedVideos)` with `mergeOrderedProfileSequences(seedVideos, liveVideos)` until live videos contain the initial target. Once they do, return live videos unchanged.

- [ ] **Step 4: Verify GREEN and existing fullscreen tests**

```bash
cd mobile
flutter test test/utils/video_identity_test.dart test/widgets/profile/profile_video_feed_pinning_test.dart test/widgets/profile/profile_video_feed_view_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/utils/video_identity.dart mobile/lib/widgets/profile/profile_video_feed_view.dart mobile/lib/screens/feed/pooled_fullscreen_video_feed_screen.dart mobile/lib/router/pooled_fullscreen_feed_route.dart mobile/test/utils/video_identity_test.dart mobile/test/widgets/profile/profile_video_feed_pinning_test.dart
git commit -m "fix(profile): preserve pin order in fullscreen"
```

### Task 6: Design-system pin asset and isolated badge

**Files:**
- Create: `mobile/assets/icon/push_pin_simple.svg`
- Modify: `mobile/packages/divine_ui/lib/src/icon/divine_icon.dart`
- Modify: `mobile/packages/divine_ui/test/src/icon/divine_icon_test.dart`
- Create: `mobile/lib/widgets/profile/profile_pin_badge.dart`
- Test: `mobile/test/widgets/profile/profile_pin_badge_test.dart`

- [ ] **Step 1: Add failing icon mapping and badge widget tests**

Test `DivineIconName.pushPinSimple.assetPath`, badge rendering, theme colors, directional placement contract, and `ExcludeSemantics` around the decorative icon.

- [ ] **Step 2: Verify RED**

```bash
cd mobile/packages/divine_ui
flutter test test/src/icon/divine_icon_test.dart
cd ../..
flutter test test/widgets/profile/profile_pin_badge_test.dart
```

Expected: FAIL because the enum value, asset, and widget are absent.

- [ ] **Step 3: Add the official Phosphor push-pin-simple regular SVG and badge**

Add the unmodified 256-viewBox Phosphor asset as `push_pin_simple.svg`, map it through `DivineIconName.pushPinSimple`, and render it in a compact `VineTheme` surface using only `context.vineColors` and `DivineIcon`. Do not add `Icons.*`, raw `Color`, raw `TextStyle`, or duplicate semantics.

- [ ] **Step 4: Verify GREEN and divine_ui coverage**

```bash
cd mobile/packages/divine_ui
flutter test --coverage test/src/icon/divine_icon_test.dart
cd ../..
flutter test test/widgets/profile/profile_pin_badge_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add mobile/assets/icon/push_pin_simple.svg mobile/packages/divine_ui/lib/src/icon/divine_icon.dart mobile/packages/divine_ui/test/src/icon/divine_icon_test.dart mobile/lib/widgets/profile/profile_pin_badge.dart mobile/test/widgets/profile/profile_pin_badge_test.dart
git commit -m "feat(profile): add pinned video badge"
```

### Task 7: Localized owner actions, badge semantics, and exact grid seed

**Files:**
- Modify: `mobile/lib/l10n/app_en.arb`
- Modify: `mobile/test/l10n/arb_consistency_test.dart`
- Generate: `mobile/lib/l10n/generated/*`
- Modify: `mobile/lib/widgets/profile/profile_videos_grid.dart`
- Test: `mobile/test/widgets/profile/profile_videos_grid_pins_test.dart`

- [ ] **Step 1: Add English full-string l10n keys and exact fallback debt**

Add keys for Pin to profile, Unpin from profile, success/failure messages, the 12-video cap, and a complete pinned-thumbnail semantics sentence with placeholders for overall position, pin rank, and total pins. Reuse `commonRetry`.

Add only those exact keys to `_knownUntranslatedDebt` with a profile-pinning comment; do not add patterns or edit generated files by hand.

- [ ] **Step 2: Generate localization output and write failing grid tests**

```bash
cd mobile
flutter gen-l10n
```

Tests must cover viewer badge rendering, complete pinned semantics, decorative badge exclusion, Pin versus Unpin, loading/limit disabled states, dispatch, non-owner behavior, transient uploads before pins, and tapping a tile passing the exact displayed published list/index/coordinate into `ProfilePooledFullscreenVideoFeedArgs`.

- [ ] **Step 3: Verify RED**

```bash
cd mobile
flutter test test/widgets/profile/profile_videos_grid_pins_test.dart
```

Expected: FAIL because grid integration is absent.

- [ ] **Step 4: Implement the owner sheet and ordered grid behavior**

Add Pin/Unpin before Edit/Delete. Make `_OwnVideoActionTile.onTap` nullable and mirror the disabled styling/semantics used by `VineBottomSheetActionMenuItem`. At the cap, render the disabled Pin action with the localized limit subtitle. Close the sheet before dispatching.

Derive pin membership and rank from the cubit state. Wrap each pinned thumbnail in the badge stack and give `_VideoGridTile` one localized semantics label.

Change `_onVideoTapped` to use `displayedVideos` as the only index, prefetch, and fullscreen seed source; do not substitute `state.videos`. Pass `tappedVideo.addressableId` as `initialAddressableId`.

- [ ] **Step 5: Verify GREEN, l10n, and existing grid tests**

```bash
cd mobile
flutter test test/widgets/profile/profile_videos_grid_pins_test.dart test/widgets/profile/profile_videos_grid_test.dart
flutter test --no-pub test/l10n/arb_consistency_test.dart --plain-name "all locales define the same message keys as app_en.arb"
python3 ~/.codex/skills/divine-mobile-l10n-pr-check/scripts/check_divine_mobile_l10n.py
bash scripts/check_countable_plural_floor.sh
bash scripts/check_arb_error_ceiling.sh
bash scripts/check_orphaned_arb_key_floor.sh
```

Expected: PASS. The l10n helper may report only the exact allowlisted fallback keys.

- [ ] **Step 6: Commit**

```bash
git add mobile/lib/l10n mobile/test/l10n/arb_consistency_test.dart mobile/lib/widgets/profile/profile_videos_grid.dart mobile/test/widgets/profile/profile_videos_grid_pins_test.dart
git commit -m "feat(profile): add pin controls and feedback"
```

### Task 8: Cross-layer verification and final review

**Files:**
- Review all files changed since the design-only base.

- [ ] **Step 1: Run focused package suites**

```bash
cd mobile/packages/profile_pins_repository
flutter test --coverage --test-randomize-ordering-seed random
flutter analyze
cd ../videos_repository
flutter test --coverage
cd ../divine_ui
flutter test --coverage
```

Expected: PASS and package coverage gates satisfied.

- [ ] **Step 2: Run focused app suites**

```bash
cd mobile
flutter test test/blocs/profile_feed test/widgets/profile test/utils/video_identity_test.dart test/providers/profile_pins_provider_test.dart test/l10n/arb_consistency_test.dart
```

Expected: PASS.

- [ ] **Step 3: Run analyzer and repo ratchets**

```bash
cd mobile
flutter analyze lib test integration_test
bash scripts/check_raw_icons_ceiling.sh
bash scripts/check_raw_textstyle_ceiling.sh
bash scripts/check_raw_colors_ceiling.sh
bash scripts/check_material_button_ceiling.sh
bash scripts/check_raw_dialog_ceiling.sh
bash scripts/check_implicit_font_color_ceiling.sh
bash scripts/check_l10n_delegates_ceiling.sh
bash scripts/check_test_unit_structure.sh
bash scripts/check_ungrouped_tests.sh
```

Expected: PASS with no raised baseline.

- [ ] **Step 4: Run visual verification**

```bash
cd mobile
scripts/golden.sh verify
```

Expected: PASS. Update a golden only if the reviewed pinned badge intentionally changes an existing golden surface.

- [ ] **Step 5: Re-read the approved spec and inspect the final diff**

Confirm every in-scope requirement is implemented, every out-of-scope arranger/manual-reordering concept is absent, no temporary artifact remains, full Nostr IDs are preserved, and `git status --short` contains only intended changes.

- [ ] **Step 6: Dispatch final spec-compliance and code-quality reviewers**

Review from the design-only base commit through `HEAD`. Fix every Critical or Important finding and rerun the affected verification before proceeding.

- [ ] **Step 7: Rebase, rerun verification, and commit any review fixes**

```bash
git fetch origin
git rebase origin/main
```

After rebase, rerun the focused package/app tests and analyzer. Commit any remaining intentional changes; finish with a clean status.
