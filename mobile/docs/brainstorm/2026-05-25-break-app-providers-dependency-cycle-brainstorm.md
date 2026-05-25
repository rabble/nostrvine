# Brainstorm: Break remaining transitive `app_providers` dependency cycle (#4554)

Date: 2026-05-25

## Problem Statement

`app_providers.dart` was decomposed into feature leaf-modules across 12 PRs
(#4523–#4556, closing parent #4506). It is now a 40-line file: 11 `export`
lines + one plain helper `createBlockedAuthorFilter`. The decomposition left
**31 provider files in `lib/providers/` still importing the aggregator back**,
including 7 of the aggregator's own exported leaves — forming
`aggregator → (export) leaf → (import) aggregator` cycles. We want the split
provider files to depend on **leaf modules directly** so the aggregator becomes
a pure barrel, unblocking the eventual `export`-drop (the `TODO(#4506)`).

## Constraints

- Epic #4339 engineering standard: **must not create new technical debt**,
  **prefer targeted simplification over abstract refactoring**, **avoid broad
  churn that does not reduce future cost**.
- Riverpod is legacy DI here (this is the legacy provider layer, not new BLoC
  work) — the task is import-graph hygiene, not a state-management migration.
- **Preserve external provider names and behavior** (issue requirement).
- **Keep generated files in sync** (issue requirement).
- Dart permits import cycles; there is **no import-cycle lint** in the repo, so
  the goal is architectural cleanliness, not a failing gate.

## Prior Art

- The merged split PRs **already established the target shape**: the two "clean"
  leaves `social_providers.dart` and `upload_media_providers.dart` import
  sibling leaves **directly** (PR #4550 explicitly: "outbound deps reach
  already-split files: auth_providers, moderation_providers,
  environment_provider"). The 31 files simply haven't been converted yet.
- `createBlockedAuthorFilter` (the only non-export symbol in the aggregator)
  depends only on `contentBlocklistRepositoryProvider` +
  `contentPolicyEngineProvider` — **both defined in `moderation_providers.dart`**
  — plus `featureFlagServiceProvider` and filter factories. `moderation` is its
  natural, cycle-free home (`feature_flag_providers` does not import moderation).

## Approaches Explored

### Approach A: Redirect-to-siblings + relocate the one helper

**Description:** Move `createBlockedAuthorFilter` into `moderation_providers.dart`;
reduce `app_providers.dart` to a pure export barrel; replace each of the 31
files' `import app_providers.dart` with direct imports of the specific sibling
leaves they actually use (determined empirically via the analyzer). Accept
leaf↔leaf import edges, which already exist in `social`/`upload_media`.

**Layers affected:** Riverpod provider/DI layer only (`lib/providers/`).

**Pros:** Matches the blessed precedent exactly; minimal, mechanical churn;
fully breaks the aggregator cycle; unblocks #4506 barrel-drop; no codegen
change (helper isn't a provider); no consumer/test changes (barrel keeps
re-exporting). Each redirect is analyzer-verifiable.

**Cons:** Leaf↔leaf cycles remain (acceptable — Dart-legal, no lint, already
present in the codebase).

**Complexity:** Low–Medium.

### Approach B: Strict DAG via base-layer extraction

**Description:** Extract every shared "hub" provider (`authService`,
`profileRepository`, `videoEventService`, `pendingAction`, …) into
dependency-free base leaves so the graph is acyclic.

**Cons:** Dozens of files + large codegen + consumer churn; the providers are
genuinely mutually recursive so a true DAG may be unachievable without splitting
provider bodies; **directly violates #4339's "avoid broad churn."** Wins only on
theoretical purity.

**Complexity:** High. (Rejected.)

### Approach C: Approach A with explicit `show` clauses

**Description:** Like A, but every redirected import lists exact symbols via
`show`. More explicit/collision-proof, but diverges from the existing
plain-import precedent and adds maintenance friction.

**Complexity:** Low–Medium. (Rejected in favor of A's precedent match.)

## Recommendation

**Approach A**, at the **broader scope** chosen by the maintainer: redirect
**all 31 provider files** in `lib/providers/` off the barrel (not just the 7
exported leaves + `environment_provider`). The ~130 screens/widgets/router
consumers stay on the barrel re-export — that remains the separate #4506
"drop compatibility export" migration.

Empirically derived per-file redirect table (analyzer-verified; modules listed
are the *net-new* direct imports each file needs):

| File | Direct leaf imports to add |
|---|---|
| auth_providers | repository_providers, social_providers |
| classic_vine_clip_import_provider | social_providers |
| classic_vines_provider | moderation_providers, repository_providers, video_providers |
| clip_manager_provider | social_providers |
| curation_providers | repository_providers |
| environment_provider | video_providers |
| for_you_provider | auth_providers, moderation_providers, video_providers |
| individual_video_providers | moderation_providers, upload_media_providers, video_providers |
| list_providers | auth_providers, repository_providers, video_providers |
| moderation_providers | auth_providers, repository_providers |
| new_videos_feed_provider | moderation_providers, video_providers |
| nostr_apps_providers | auth_providers |
| nostr_client_provider | auth_providers, relay_providers |
| notifications_providers | auth_providers, relay_providers, repository_providers, video_providers |
| popular_now_feed_provider | moderation_providers, video_providers |
| popular_videos_feed_provider | moderation_providers, video_providers |
| profile_feed_provider | moderation_providers, video_providers |
| profile_feed_providers | video_providers |
| profile_feed_session_cache | auth_providers |
| profile_reposts_provider | video_providers |
| relay_providers | video_providers |
| repository_providers | auth_providers, moderation_providers, relay_providers, social_providers, video_providers |
| route_feed_providers | moderation_providers, video_providers |
| user_profile_providers | repository_providers |
| video_editor_provider | moderation_providers, preferences_providers, social_providers |
| video_events_providers | moderation_providers, video_providers |
| video_feed_provider | repository_providers, video_providers |
| video_providers | auth_providers, moderation_providers, preferences_providers, relay_providers, repository_providers, social_providers, upload_media_providers |
| video_publish_provider | auth_providers, preferences_providers, repository_providers, social_providers, upload_media_providers, video_providers |
| video_reply_parent_provider | video_providers |
| watermark_download_provider | permissions_providers |

Aggregator + helper changes:
- Move `createBlockedAuthorFilter` → `moderation_providers.dart` (add imports:
  `features/feature_flags/providers/feature_flag_providers.dart`,
  `features/feature_flags/models/feature_flag.dart`,
  `services/blocklist_content_filter.dart`, `videos_repository`).
- `app_providers.dart` → keep only the 11 `export` lines (drop all 6 imports +
  the function). Consumers still get `createBlockedAuthorFilter` via
  `export 'moderation_providers.dart'`.
- `moderation_providers.dart`: drop `hide feedAspectRatioPreferenceServiceProvider`
  (collision vanishes once the barrel import is gone; it keeps its direct
  `preferences_providers` import).

## Open Questions for /plan

- [ ] Commit decomposition: single mechanical commit vs. grouped (aggregator +
      helper first, then file redirects) — both land in one PR (no stacking).
- [ ] Confirm `build_runner` is a true no-op and whether to run/commit anyway
      (issue says "keep generated files in sync").
- [ ] Residual unused-import warnings after redirect (analyzer-driven cleanup).
- [ ] Symbol-collision check when a file gains multiple new sibling imports
      (expected none — each provider symbol is uniquely owned — but verify).

## Prerequisites

- [ ] Fresh branch from `origin/main` (no worktree, per maintainer preference).

## Next Step

`/plan https://github.com/divinevideo/divine-mobile/issues/4554`
