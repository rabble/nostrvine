# Community Content-Warning Tagging Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let viewers suggest content-warning labels for a video (NIP-32 kind 1985); the app counts distinct Divine-NIP-05 authors per label and folds any label crossing a threshold of 3 into the existing content-warning overlay.

**Architecture:** UI (`Help classify` selector) → `CommunitySuggestCubit` → `CommunityContentLabelRepository` → `NostrClient` (kind 1985 query/publish) + `ProfileRepository.resolveDivineIdentity` (name-server `/by-pubkey`). Community-derived labels are cached by `CommunityContentLabelService` and merged into the feed's existing warning path.

**Tech Stack:** Flutter, flutter_bloc (Cubit), Riverpod (legacy bridge for provider wiring), nostr_sdk `Filter`/`NostrClient`, models `VideoEvent`, existing `ContentLabel` enum + `ContentWarning` widgets.

## Global Constraints

- Dark-mode only; use `VineTheme` colors + `VineTheme.*Font()` + `DivineIcon`; no raw `Colors.*`/`TextStyle`/`Icons.*`.
- All user-facing strings via `context.l10n`; add ARB keys to `mobile/lib/l10n/app_en.arb`, run `flutter gen-l10n`.
- Layered flow UI→BLoC→Repository→Client; no fallback/aggregation logic in UI or BLoC.
- No error strings/exception objects in Cubit state; status enums + `addError`. Network/domain errors are NOT Crashlytics-reportable.
- Divine-identity cache TTL = **24h**, matching `ModerationLabelService._resolvedPubkeyTtl` (`moderation_label_service.dart:113`). Do not invent a new window.
- Never truncate Nostr IDs anywhere.
- Threshold constant: `CommunityContentWarningConstants.displayThreshold = 3`.
- Content-warning NIP-32 namespace: `content-warning` (matches existing self-labeling).
- Run all Flutter commands from `mobile/`; `flutter analyze lib test integration_test` + scoped tests must pass before each commit.

---

### Task 1: Constants + Divine-identity check on ProfileRepository

**Files:**
- Create: `mobile/lib/services/community_content_warning_constants.dart`
- Modify: `mobile/packages/profile_repository/lib/src/profile_repository.dart` (add `resolveDivineIdentity`)
- Test: `mobile/packages/profile_repository/test/src/profile_repository_test.dart` (append group)

**Interfaces:**
- Produces:
  - `abstract class CommunityContentWarningConstants { static const int displayThreshold = 3; static const String namespace = 'content-warning'; }`
  - `Future<bool?> ProfileRepository.resolveDivineIdentity(String pubkey)` — GET `<apiBase>/by-pubkey/<hex>`, returns `true`/`false` on a 200 JSON verdict; caches genuine verdicts per-pubkey with 24h TTL; returns `null` on network/parse/non-200 failures so callers can avoid caching degraded "no warnings" results.

- [ ] Write failing tests: `resolveDivineIdentity` returns true when `/by-pubkey/<hex>` → `{"ok":true,"found":true,...}`; false on `found:false`; null on HTTP/network/parse errors; second genuine verdict within TTL does not hit the network (mock http client call count == 1).
- [ ] Run tests → fail.
- [ ] Add constants file + `resolveDivineIdentity` using the repo's existing http client + `_divineApiBaseUrl`/config base, mirroring `claimUsername`'s request style. In-memory `Map<String, ({bool value, DateTime at})>` cache gated on the repository's 24h identity TTL.
- [ ] Run tests → pass. Analyze. Commit.

### Task 2: CommunityContentLabelRepository — aggregation

**Files:**
- Create: `mobile/lib/repositories/community_content_label_repository.dart`
- Test: `mobile/test/repositories/community_content_label_repository_test.dart`

**Interfaces:**
- Consumes: `NostrClient.queryEvents(List<Filter>)`; `ProfileRepository.resolveDivineIdentity`; `CommunityContentWarningConstants`.
- Produces:
  - `class CommunityContentLabelRepository({required NostrClient nostrClient, required ProfileRepository profileRepository})`
  - `Future<Set<String>> communityLabelsForVideo(VideoEvent video)` — queries `Filter(kinds:[1985], e:[video.id])` and, for addressable NIP-71 kinds only, `Filter(kinds:[1985], a:[kind:pubkey:dTag])`; parse `content-warning` `l` tags; group normalized label → set of distinct author pubkeys; keep authors where `resolveDivineIdentity` is true; return labels whose distinct-Divine-author count `>= displayThreshold`. Throws `CommunityLabelUnavailableException` when a relay or identity failure could change the outcome.

- [ ] Write failing tests: 3 distinct Divine authors on `gambling` → `{gambling}`; 2 distinct → `{}`; same author twice + 1 other (2 distinct) → `{}`; non-Divine authors excluded from count; unknown labels ignored; dedupes `e` and `a` results by event id; degraded query/identity paths throw the typed exception when uncertainty could hide a warning. Mock `NostrClient` + `ProfileRepository`.
- [ ] Run → fail. Implement. Run → pass. Analyze. Commit.

### Task 3: CommunityContentLabelRepository — publish + my-suggestions

**Files:**
- Modify: `mobile/lib/repositories/community_content_label_repository.dart`
- Test: `mobile/test/repositories/community_content_label_repository_test.dart` (append)

**Interfaces:**
- Consumes: `NostrClient` publish API (match signature used elsewhere, e.g. broadcast of a signed kind event).
- Produces:
  - `Future<void> suggestLabels({required VideoEvent video, required Set<ContentLabel> labels})` — builds kind 1985 event tags: `['L','content-warning']`, one `['l', label.value, 'content-warning']` per label, `['e', video.id]`, and `['a', kind:pubkey:dTag]` only for addressable NIP-71 video kinds. Deliberately emits no `p` target because that labels the creator account, not the video. Publishes via `NostrClient`. Throws typed on publish failure.
  - `Future<Set<String>> mySuggestedLabels(VideoEvent video, String myPubkey)` — labels `myPubkey` already published for this video.

- [ ] Write failing tests: `suggestLabels` builds exactly the expected tag list (assert L/l/e/scoped-a/no-p, no truncation, empty labels → no publish or throws ArgumentError); `mySuggestedLabels` returns only the caller's labels.
- [ ] Run → fail. Implement. Run → pass. Analyze. Commit.

### Task 4: Community labels into feed warning path

**Files:**
- Modify: `mobile/lib/widgets/video_feed_item/feed_videos.dart`
- Test: `mobile/test/widgets/video_feed_item/feed_videos_test.dart`

**Interfaces:**
- Produces:
  - `CommunityContentLabelService` caches per-video crossed-threshold labels with a short TTL and exposes synchronous `warnLabelsFor(video)`.
  - Feed overlay code merges `video.warnLabels` with `warnLabelsFor(video)` behind the feature flag so the overlay, autoplay gate, and double-tap-like gate agree.

- [ ] Write failing tests: community label absent from creator/trusted sources is added to the overlay; flag-off ignores cached community labels; a newly crossed warning pauses already-playing video.
- [ ] Run → fail. Implement. Run → pass. Analyze. Commit.

### Task 5: CommunitySuggestCubit

**Files:**
- Create: `mobile/lib/blocs/community_suggest/community_suggest_cubit.dart`
- Create: `mobile/lib/blocs/community_suggest/community_suggest_state.dart`
- Test: `mobile/test/blocs/community_suggest/community_suggest_cubit_test.dart`

**Interfaces:**
- Consumes: `CommunityContentLabelRepository`.
- Produces:
  - `enum CommunitySuggestStatus { initial, loading, ready, submitting, success, failure }`
  - `CommunitySuggestState` (Equatable): `status`, `Set<ContentLabel> selected`, `Set<String> alreadySuggested`; getter `bool get canSubmit => selected.isNotEmpty && status != submitting`.
  - `CommunitySuggestCubit(repository, video, myPubkey)`: `loadExisting()`, `toggle(ContentLabel)`, `submit()`.

- [ ] Write failing blocTest cases: `loadExisting` emits ready with alreadySuggested; `toggle` adds/removes selection; `submit` success emits submitting→success and calls `suggestLabels`; `submit` failure emits submitting→failure and calls `addError`; state holds no error string.
- [ ] Run → fail. Implement (status enum, no mutable fields, `addError` on catch). Run → pass. Analyze. Commit.

### Task 6: UI — Help-classify selector + entry point + l10n

**Files:**
- Create: `mobile/lib/widgets/community_suggest/community_suggest_sheet.dart` (Page/View: `ConsumerWidget` page builds `BlocProvider<CommunitySuggestCubit>` keyed on repo identity → `StatelessWidget` view)
- Create: `mobile/lib/widgets/community_suggest/help_classify_action_button.dart`
- Modify: video actions area to add the distinct action (locate alongside `report_action_button.dart`)
- Modify: `mobile/lib/l10n/app_en.arb` (+ `flutter gen-l10n`)
- Test: `mobile/test/widgets/community_suggest/community_suggest_sheet_test.dart`, `.../help_classify_action_button_test.dart`

**Interfaces:**
- Consumes: `CommunitySuggestCubit`, `ContentLabel`, `context.l10n`.
- l10n keys: `communitySuggestTitle` ("Help classify this"), `communitySuggestSubtitle`, `communitySuggestSubmit`, `communitySuggestSuccess`, `communitySuggestFailure`, `communitySuggestAlready`, `communitySuggestActionLabel`.

- [ ] Write failing widget tests: sheet renders label chips from `ContentLabel.values`; submit disabled until a label selected; tapping submit dispatches; already-suggested labels shown as selected/locked; `MaterialApp` has l10n delegates; assert copy via `AppLocalizations` lookup, not hardcoded.
- [ ] Run → fail. Implement selector (reuse creator selector pattern, `VineTheme`, `DivineIcon`, `Semantics(button:true)`), entry-point button, ARB keys, gen-l10n. Run → pass. Analyze. Commit.

### Task 7: Wiring/providers

**Files:**
- Create: `mobile/lib/providers/community_content_label_provider.dart`
- Modify: feed content-warning path to prefetch community labels and merge cached warning labels.
- Test: provider smoke test and feed behavior tests

**Interfaces:**
- Consumes: everything above.

- [ ] Write failing tests for provider readiness, flag-off no-prefetch, runtime flag flip, and feed warning behavior.
- [ ] Run → fail. Implement providers + feed fetch (service cached; degraded results are not cached). Run → pass. Analyze. Commit.

### Task 8: Analyze/format/test sweep + PR polish

- [ ] `dart format` changed files; `flutter analyze lib test integration_test` clean; run all new scoped tests + affected suites.
- [ ] Verify no stray IDs truncated, no debug prints, no TODOs without issue links.
- [ ] Update PR #5720 description to reflect actual work.

## Self-Review notes

- Spec coverage: suggest (T3/T6), aggregate+threshold+Divine-identity (T1/T2), display fold-in (T4/T7), entry point (T6), 24h identity TTL alignment (T1), short-lived label cache (T4/T7), graceful degradation (T2/T7). Backend items intentionally excluded (separate issue).
- Provenance: v1 does not display a separate community provenance line; community warnings are advisory and use the existing blur + View Anyway flow.
- Types consistent: `communityLabelsForVideo`/`suggestLabels`/`mySuggestedLabels`/`resolveDivineIdentity`/`displayThreshold` used verbatim downstream.
