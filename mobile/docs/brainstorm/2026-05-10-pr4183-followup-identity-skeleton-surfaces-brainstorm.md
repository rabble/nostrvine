# Brainstorm: post-merge follow-up surfaces for the identity-skeleton pattern (PR #4183)

Date: 2026-05-10

## Problem Statement

PR #4183 fixes #4163 by replacing a misleading "placeholder identity" on the
profile screen with a `Skeletonizer`-driven shimmer over the avatar +
name/NIP-05/bio block. The state machine (Timer + `_wasLoadingIdentity` guard +
post-frame schedule + 7 s fallthrough to the generated-name/identicon path)
was tightened across three review rounds and lives inline in
`_ProfileHeaderWidgetState`. The same misleading-placeholder problem exists in
principle on every surface that renders an async-resolved username/avatar with
a "best effort" fallback while the Kind 0 fetch is in flight. This brainstorm
ranks those follow-up surfaces by user impact × reuse cost and converges on
the next concrete piece of work.

## Constraints

- Layered architecture: UI → BLoC/Cubit → Repository → Client.
- BLoC-first for new state management; Riverpod is legacy bridge code (the
  other-profile branch in PR #4183 still reads `fetchUserProfileProvider`).
- Dark-mode only, `VineTheme`, `divine_ui` for shared components.
- `divine_ui` is a strict-coverage package — any new widget there ships with
  tests in the same PR.
- Nostr Kind 0 (profile metadata) is genuinely absent for some users (classic
  Viners), which is why the 7 s fallthrough exists rather than an
  indefinite skeleton.
- No truncation of Nostr identifiers anywhere (logs, tests, debug output).

## Prior Art

- **PR #4183** — `mobile/lib/widgets/profile/profile_header_widget.dart` —
  canonical implementation of the pattern. State machine at
  `_ProfileHeaderWidgetState`. `Skeleton.keep` on stats / action buttons /
  NIP-05 link / bio. Post-frame timer mutation in `bfdee671b`.
- **#4054 → #4163** — original triage chain. The root concern is users
  mistaking a generated-name placeholder for the real identity, especially at
  large avatar sizes (the 144 px profile avatar was the trigger).
- **`Skeletonizer` package** — already a dep; `Skeleton.keep` mutes shimmer
  while preserving pointer events on chrome.
- **`divine_ui`** — `mobile/packages/divine_ui/`. Already exposes
  `vineSkeletonEffect` used by PR #4183.

## Surface Inventory

| Surface | File | Avatar | Profile source | Already gates on loading? |
|---|---|---|---|---|
| Video feed author bar | `lib/widgets/video_feed_item/video_author_info_section.dart` | small | mostly cached on the video event | no |
| Comments thread item | `lib/screens/comments/widgets/comment_item.dart` | small | per-comment async | no |
| Notifications list item | `lib/widgets/notification_list_item.dart` | small (avatar stack) | per-actor async | no |
| DM conversation tile | `lib/screens/inbox/widgets/conversation_tile.dart` | small | `fetchUserProfileProvider` | partial |
| DM conversation header | `lib/screens/inbox/conversation/conversation_view.dart` | medium | provider | no |
| User profile tile (followers / following / search) | `lib/widgets/user_profile_tile.dart` | small-medium | provider | no |
| Mentions overlay | `lib/screens/comments/widgets/mention_overlay.dart` | small | provider | varies |
| Repost / collaborator chips | `lib/widgets/video_feed_item/collaborator_avatar_row.dart`, `metadata_user_chips.dart` | tiny | provider | no |

Confusion severity tracks avatar size; frequency tracks visit cadence.

## Approaches Explored

### Approach A — Targeted: video-feed author bar only

**Description:** Apply PR #4183's exact pattern in-line to
`video_author_info_section.dart`. One surface, one PR.

**Layers affected:** UI only.

**Pros:**
- Smallest review surface; ships fastest.
- Highest-frequency surface in the app (every scroll).

**Cons:**
- Copy-pastes the Timer + `_wasLoadingIdentity` + post-frame state machine.
- Sets up a "every surface needs the same boilerplate" pattern that the team
  already iterated on three times for `_ProfileHeaderWidgetState`.

**Risks / Unknowns:**
- Author info on a video event is mostly already cached — the actual loading
  window for an in-feed video is near zero except on cold start. May be
  low-yield despite high visibility.

**Complexity:** Low.

### Approach B — Extract `IdentitySkeletonizer` to `divine_ui` + pilot on the video-feed author bar

**Description:** Move the state machine (loading flag in →
`Skeletonizer.enabled` out, with 7 s fallthrough) into a new widget in
`mobile/packages/divine_ui/`. Pilot on the video-feed author bar; future
surfaces adopt by wrapping their avatar+name area.
`_ProfileHeaderWidgetState` migrates to it in a follow-up.

**Layers affected:** UI + `divine_ui` package addition.

**Pros:**
- Single source of truth for the state machine — drift across surfaces
  becomes impossible.
- `divine_ui` strict-coverage gate forces a clean test surface
  (`fakeAsync` for the timeout path).
- Subsequent surfaces are 3–5 lines each.
- PR #4183's `_ProfileHeaderWidgetState` becomes ~15 lines lighter once it
  switches over.

**Cons:**
- Bigger first PR (divine_ui addition + pilot + test).
- Abstraction is thin; risks looking like a `Skeletonizer` wrapper.
- YAGNI tension until at least two callsites exist (right now there's only
  one; this PR creates the second).

**Risks / Unknowns:**
- Should the timeout be parameterised or hardcoded at 7 s? Hardcoding is
  simpler; parameterising invites bikeshedding.
- Does `divine_ui` already depend on `skeletonizer`? Confirmed — it exports
  `vineSkeletonEffect`, so yes.

**Complexity:** Medium.

### Approach C — Three-surface bundle (no extraction)

**Description:** One PR applies the pattern in-line to the three highest-
frequency surfaces: video-feed author bar, comments thread item, DM
conversation header.

**Layers affected:** UI only, three files.

**Pros:**
- Highest user-impact per review round.
- Gives 3 callsites' worth of "what does this need" data before committing
  to an abstraction.

**Cons:**
- Three copy-pasted state machines.
- Each surface has its own loading-flag derivation (cached event author vs.
  async `fetchUserProfileProvider` vs. DM peer), so the "bundle" framing is
  mostly cosmetic — the changes don't compose.
- Big review surface, harder to land cleanly.

**Risks / Unknowns:**
- Concurrent loading-flag derivations are subtle (e.g. a comment whose
  author profile arrives mid-stream can flicker).

**Complexity:** Medium-High.

### Approach D — Defer

**Description:** No further skeleton work until a triage signal names another
surface as confusing. Smaller avatars likely don't reproduce the #4054-style
confusion that the giant 144 px profile avatar did.

**Layers affected:** None.

**Pros:**
- Honors YAGNI. PR #4183 already addresses the worst-case.

**Cons:**
- Leaves a known structural gap. Next #4054-style report = one-at-a-time fix
  cycle again.

**Risks / Unknowns:**
- None.

**Complexity:** Zero.

## Recommendation

**Approach B** (extract to `divine_ui`, pilot on the video-feed author bar) —
conditional on the team agreeing the pattern will see at least one more
callsite beyond the pilot. Otherwise, **Approach A**.

Why B over A:
- The state machine took three review rounds to stabilise on the profile
  screen. Copying it inline three more times will eat the same review
  budget three more times.
- `divine_ui`'s strict-coverage gate is the ideal home for a Timer-driven
  state machine that needs `fakeAsync` discipline.
- Once extracted, the existing `_ProfileHeaderWidgetState` simplifies on a
  natural follow-up PR — net code goes down across the codebase even before
  the second adoption.

Why not C: the three surfaces don't actually compose — each has a different
loading-flag derivation. A "bundle" PR is just three independent PRs in one
review.

Why D is the fallback: if the small-avatar surfaces aren't actually
confusing in practice (no `#4054`-style report ever lands on comments or the
video feed), the right answer is no further work.

## Open Questions for /plan

- [ ] Does the video-feed author bar actually have a non-zero loading window
      for the author profile, or is the author info pulled directly from the
      video event with no async profile fetch? Need to read
      `video_author_info_section.dart` end-to-end to confirm where (if
      anywhere) a profile fetch races the render.
- [ ] Where in `mobile/packages/divine_ui/lib/src/` should
      `IdentitySkeletonizer` live? Next to `vineSkeletonEffect`? Same file?
- [ ] Hardcode the 7 s timeout, or expose as a constructor param with a
      default of 7 s? Lean: param with default, since the profile screen's
      7 s was tuned for the worst-case Kind 0 absence and a smaller surface
      may want a smaller value.
- [ ] Test strategy for the new widget under `divine_ui`'s strict-coverage
      gate: `fakeAsync` for timeout, plus widget tests for the
      `Skeletonizer.enabled` transitions on each input change.
- [ ] Migration of `_ProfileHeaderWidgetState` to the new widget: same PR
      or follow-up? Lean: follow-up to keep the pilot focused.

## Prerequisites

- [ ] PR #4183 must merge first to avoid conflicts in
      `_ProfileHeaderWidgetState`.

## Next Step

If Approach B confirmed: `/plan` for "extract `IdentitySkeletonizer` to
`divine_ui` + apply to video-feed author bar."

If Approach A: `/plan` for "apply identity-skeleton pattern to video-feed
author bar."

If Approach D: no follow-up; close this brainstorm as "deferred pending
triage signal."
