# Community Content-Warning Tagging Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let viewers suggest content-warning labels for a video (NIP-32 kind 1985); the app counts distinct Divine-NIP-05 authors per label and folds any label crossing a threshold of 3 into the existing content-warning overlay, tagged as community-sourced.

**Architecture:** UI (`Help classify` selector + provenance chip) → `CommunitySuggestCubit` → `CommunityContentLabelRepository` → `NostrClient` (kind 1985 query/publish) + `ProfileRepository.hasDivineIdentity` (name-server `/by-pubkey`). Community-derived labels are passed into the existing synchronous `resolveEffectiveContentLabels` resolver as a new tagged source.

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
- Modify: `mobile/packages/profile_repository/lib/src/profile_repository.dart` (add `hasDivineIdentity`)
- Test: `mobile/packages/profile_repository/test/src/profile_repository_test.dart` (append group)

**Interfaces:**
- Produces:
  - `abstract class CommunityContentWarningConstants { static const int displayThreshold = 3; static const String namespace = 'content-warning'; static const Duration identityCacheTtl = Duration(hours: 24); }`
  - `Future<bool> ProfileRepository.hasDivineIdentity(String pubkey)` — GET `<apiBase>/by-pubkey/<hex>`, returns `true` when JSON `found == true`; caches per-pubkey with 24h TTL; returns `false` on any network/parse error (documented sentinel, not reportable).

- [ ] Write failing tests: `hasDivineIdentity` returns true when `/by-pubkey/<hex>` → `{"ok":true,"found":true,...}`; false on `found:false`; false on HTTP error; second call within TTL does not hit the network (mock http client call count == 1).
- [ ] Run tests → fail.
- [ ] Add constants file + `hasDivineIdentity` using the repo's existing http client + `_divineApiBaseUrl`/config base, mirroring `claimUsername`'s request style. In-memory `Map<String, ({bool value, DateTime at})>` cache gated on `identityCacheTtl`.
- [ ] Run tests → pass. Analyze. Commit.

### Task 2: CommunityContentLabelRepository — aggregation

**Files:**
- Create: `mobile/lib/repositories/community_content_label_repository.dart`
- Test: `mobile/test/repositories/community_content_label_repository_test.dart`

**Interfaces:**
- Consumes: `NostrClient.queryEvents(List<Filter>)`; `ProfileRepository.hasDivineIdentity`; `CommunityContentWarningConstants`.
- Produces:
  - `class CommunityContentLabelRepository({required NostrClient nostrClient, required ProfileRepository profileRepository})`
  - `Future<Set<String>> communityLabelsForVideo(VideoEvent video)` — queries `Filter(kinds:[1985], e:[video.id])` and (when `video.addressableId != null`) `Filter(kinds:[1985], a:[video.addressableId!])`; parse `content-warning` `l` tags; group normalized label → set of distinct author pubkeys; keep authors where `hasDivineIdentity` is true; return labels whose distinct-Divine-author count `>= displayThreshold`. Returns `{}` on query error (graceful degradation, documented).

- [ ] Write failing tests: 3 distinct Divine authors on `gambling` → `{gambling}`; 2 distinct → `{}`; same author twice + 1 other (2 distinct) → `{}`; non-Divine authors excluded from count; label normalization (`NSFW`→`nudity`) via `normalizeModerationLabelValue`; dedupes `e` and `a` results by event id; query throw → `{}`. Mock `NostrClient` + `ProfileRepository`.
- [ ] Run → fail. Implement. Run → pass. Analyze. Commit.

### Task 3: CommunityContentLabelRepository — publish + my-suggestions

**Files:**
- Modify: `mobile/lib/repositories/community_content_label_repository.dart`
- Test: `mobile/test/repositories/community_content_label_repository_test.dart` (append)

**Interfaces:**
- Consumes: `NostrClient` publish API (match signature used elsewhere, e.g. broadcast of a signed kind event).
- Produces:
  - `Future<void> suggestLabels({required VideoEvent video, required Set<ContentLabel> labels})` — builds kind 1985 event tags: `['L','content-warning']`, one `['l', label.value, 'content-warning']` per label, `['e', video.id, <relayHint>]`, `['a', video.addressableId]` when present, `['p', video.pubkey]`; publishes via `NostrClient`. Throws typed on publish failure.
  - `Future<Set<String>> mySuggestedLabels(VideoEvent video, String myPubkey)` — labels `myPubkey` already published for this video.

- [ ] Write failing tests: `suggestLabels` builds exactly the expected tag list (assert L/l/e/a/p, no truncation, empty labels → no publish or throws ArgumentError); `mySuggestedLabels` returns only the caller's labels.
- [ ] Run → fail. Implement. Run → pass. Analyze. Commit.

### Task 4: Community labels into effective-content-labels resolver

**Files:**
- Modify: `mobile/lib/services/effective_content_labels.dart`
- Test: `mobile/test/services/effective_content_labels_test.dart`

**Interfaces:**
- Produces:
  - Add optional `Set<String>? communityLabels` param to `resolveEffectiveContentLabels`; merged via `addLabel` after trusted-labeler sources, before hashtag fallback.
  - `enum ContentLabelProvenance { creator, trustedLabeler, community }` + `List<({String value, ContentLabelProvenance provenance})> resolveEffectiveContentLabelsWithProvenance(...)` used by UI to tag the community chip. (Keep the existing `List<String>` function delegating to the provenance one for back-compat.)

- [ ] Write failing tests: community label absent from creator/trusted sources is added; a community label already present as a creator self-label keeps `creator` provenance (creator wins); provenance list marks community-only labels as `community`.
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
- l10n keys: `communitySuggestTitle` ("Help classify this"), `communitySuggestSubtitle`, `communitySuggestSubmit`, `communitySuggestSuccess`, `communitySuggestFailure`, `communitySuggestAlready`, `contentWarningCommunitySource` ("Suggested by the community").

- [ ] Write failing widget tests: sheet renders label chips from `ContentLabel.values`; submit disabled until a label selected; tapping submit dispatches; already-suggested labels shown as selected/locked; `MaterialApp` has l10n delegates; assert copy via `AppLocalizations` lookup, not hardcoded.
- [ ] Run → fail. Implement selector (reuse creator selector pattern, `VineTheme`, `DivineIcon`, `Semantics(button:true)`), entry-point button, ARB keys, gen-l10n. Run → pass. Analyze. Commit.

### Task 7: Display provenance chip + wiring/providers

**Files:**
- Modify: `mobile/lib/widgets/content_warning.dart` (+ `content_warning_helpers.dart`) to show `contentWarningCommunitySource` when provenance == community
- Modify: `mobile/lib/providers/moderation_providers.dart` (+ `social_providers.dart`) to expose `communityContentLabelRepositoryProvider`
- Modify: feed content-warning resolution path to fetch community labels and pass into resolver
- Test: golden/widget test for community-tagged warning; provider smoke test

**Interfaces:**
- Consumes: everything above.

- [ ] Write failing test: `ContentWarning` renders the community-source line when given a community-provenance label; not shown for creator-only labels.
- [ ] Run → fail. Implement chip + provider wiring + feed fetch (repository call cached; degradation on error). Run → pass. Update goldens if applicable. Analyze. Commit.

### Task 8: Analyze/format/test sweep + PR polish

- [ ] `dart format` changed files; `flutter analyze lib test integration_test` clean; run all new scoped tests + affected suites.
- [ ] Verify no stray IDs truncated, no debug prints, no TODOs without issue links.
- [ ] Update PR #5720 description to reflect actual work.

## Self-Review notes

- Spec coverage: suggest (T3/T6), aggregate+threshold+Divine-identity (T1/T2), display fold-in + provenance (T4/T7), entry point (T6), 24h TTL alignment (T1), graceful degradation (T2/T7). Backend items intentionally excluded (separate issue).
- Provenance: `creator` beats `community` for the same label value (T4) — consistent across resolver and chip (T7).
- Types consistent: `communityLabelsForVideo`/`suggestLabels`/`mySuggestedLabels`/`hasDivineIdentity`/`displayThreshold` used verbatim downstream.
