# Brainstorm: replacing raw exception text in user-facing messages (#3589)

Date: 2026-08-29
Findings of record: `tasks/findings_3589.md` (every claim there is file:line cited,
and the device measurements were taken on a physical iPhone, iOS 26.6.1).

## Problem Statement

22 localized ARB keys in `mobile/lib/l10n/app_en.arb` declare an `{error}` placeholder
that callers fill with raw exception `.toString()` output, so users see developer
internals — plugin wrapper types, `errno` values, absolute container paths, local
ephemeral ports, request URIs — inside otherwise-localized copy. Two further sites leak
the same way without going through the ARB at all. The guard written to prevent this
(`check_arb_error_ceiling.sh`, authored for this very issue) has drifted 11 counts out
of date and currently permits regressions.

## Constraints

- **Layering** (`error_handling.md`): state carries codes, the UI layer localizes.
  No error strings or exception objects in Bloc state.
- **l10n** (`localization.md`): 22 locales; a key added ahead of its call site is an
  orphan and fails the #3630 ratchet, so caller + ARB must ship together.
- **Copy-alignment policy**: align code to existing ARB values; do not churn translated
  copy as a refactor side effect.
- **Ratchets that bite this change**: `check_arb_error_ceiling.sh` (the target),
  `check_orphaned_arb_key_floor.sh`, `check_ungrouped_tests.sh`,
  `check_l10n_delegates_ceiling.sh`, `check_test_unit_structure.sh`.
- **No stacked PRs**; one PR to `main`.
- Diagnostic detail must survive somewhere — the user's decision is
  *localized copy on screen, full detail to the log*.

## Prior Art (both merged, both in this repo)

- **Pattern 1 — typed failure-kind enum -> closed set of error-free keys + `*Generic`.**
  `b52a2905b` (#3117): `DeleteFailureKind` + `lib/utils/delete_failure_localization.dart`,
  retiring three `{error}` keys and shipping the still-live `shareMenuDeleteFailed*`
  family. Canonical mapping shape today: `lib/l10n/publish_error_kind_l10n.dart`
  (`extension on AppLocalizations`, one `switch`, **no `default`**).
- **Pattern 2 — branch on a typed exception -> two error-free keys.**
  `aac8df74c`: `bugReportFailedWithError('$e')` became
  `e is ZendeskAttachmentUploadException ? bugReportUploadFailed : bugReportSendFailed`.
- **Pattern 1', half-applied** — `01a757f9a` (#4792) added `BlossomSaveFailureKey` but
  left the `{error}` key, passing `''`. That residue is the live dangling-colon bug.
- Six merged reason enums establish placement: **beside the state they describe**
  (`lib/blocs/<feature>/<feature>_state.dart`) or in the owning service
  (`lib/services/video_publish/publish_error_kind.dart`). Mapping extensions live in
  `lib/l10n/<name>_l10n.dart` with a test in `test/l10n/`.

## The fact that reframes the cost

Most sites already have a placeholder-free sibling key, already translated in all 22
locales (finding H28). Both url_launcher sites are the clearest case: the
`canLaunchUrl`-false branch already uses `supportCouldNotOpenPage(pageName)` /
`legalCouldNotOpenPage(pageName)`, and only the sibling `catch (e)` reaches for
`{error}`. `nostr_connect_screen.dart:388` is even starker — the correct localized key
`authFailedToConnect` is used **six lines above**, at `:382`.

So "22 keys x 22 locales of new copy" overstates the work by a wide margin.

## Approaches Explored

### Approach A: Reuse-first — collapse onto existing keys, add an enum only where a real taxonomy exists

**Description.** Sort the 24 sites into four buckets and apply the cheapest correct
shape to each: **delete** (2 dead branches), **reuse** (collapse onto an existing
translated placeholder-free key, ~10 sites), **static** (one new actionable string where
the catch provably has no distinguishable causes, ~4 sites), **enum** (Pattern 1, only
where >=2 user-actionable causes exist and no key covers them — realistically
`shareMenuFailedToUpdateVideo`'s four fixed `Exception` literals and
`profileSetupCameraAccessFailed`'s permission-denied / restricted / busy).

**Layers affected:** UI (all), Bloc/service (only for the enum sites), l10n.

**Pros**
- Minimal new copy, therefore minimal new translation — the reuse bucket costs zero.
- Follows both merged precedents, choosing between them per site rather than uniformly.
- Smallest diff that still reaches zero `{error}`.
- Honours the copy-alignment policy: existing values are reused verbatim.

**Cons**
- Per-site judgement means the PR is heterogeneous; a reviewer must check the bucket
  choice, not just the mechanics.
- Two sites lose genuine signal (relay diagnostics) unless the log path is wired in the
  same commit.

**Risks / Unknowns**
- Whether `discoverListsFailedToLoad` (no placeholder) reads well for the non-timeout
  arm, or whether that arm deserves its own copy.

**Complexity:** Medium-Low

### Approach B: Uniform Pattern 1 — a reason enum per feature for every site

**Description.** Author ~8-10 per-feature enums plus matching `lib/l10n/*_l10n.dart`
extensions and `test/l10n/*_test.dart` mapping tests, one per touched feature, and route
every site through them.

**Layers affected:** UI, Bloc/service (new enums), l10n (new extensions + tests).

**Pros**
- Maximum consistency; every failure surface is code-carrying and exhaustively tested.
- The `switch`-without-`default` shape makes a future enum arm a compile error.
- Best long-term extensibility if these surfaces later need finer copy.

**Cons**
- Over-engineers sites that **provably cannot throw**
  (`discoverListsFailedToUpdateSubscription`: both service methods wrap their whole body
  and return `bool`) and sites that are dead. An enum with one reachable arm is
  ceremony, not taxonomy.
- ~40-60 new ARB keys x 22 locales.
- Directly contradicts YAGNI, and wins mainly on "flexibility for future requirements" —
  which this skill flags as a red flag rather than a feature.

**Risks / Unknowns**
- Large translation surface increases the chance of English mirrors slipping in; the
  `en != de` mapping test catches that, but only per enum.

**Complexity:** High

### Approach C: One shared app-wide `UserFacingFailure` enum

**Description.** A single enum (`network`, `permission`, `notFound`, `server`,
`unknown`) with one mapping extension, applied everywhere.

**Layers affected:** a new shared model, l10n, UI.

**Pros**
- Smallest possible machinery: one enum, one extension, one test, ~5 new keys.
- Trivially uniform.

**Cons**
- **Already considered and rejected in this repo.** PR #8307's own rationale states the
  choice was per-feature enums "not one shared enum, which would collapse unrelated
  domains into vague copy."
- Produces exactly the generic copy the brand guidelines argue against; "Something went
  wrong" for a camera-permission denial is a worse user experience than today's leak,
  because at least today the user can read "The user did not allow camera access."
- Loses the actionable half of messages that currently *do* carry a usable sentence.

**Complexity:** Low (but low quality)

## Secondary question: should a second detector guard the non-ARB shape?

The existing `check_arb_error_ceiling.sh` reads `app_en.arb` only, so it structurally
cannot see `nostr_connect_screen.dart:388` (`'Failed to connect: $e'`) or
`for_you_tab.dart:91` (`error.toString()` into a rendered `Text`) — the two sites the
issue's own ARB-derived list missed.

- **D1 — regenerate the existing ratchet to 0 only.** Zero new machinery; closes the
  ARB-shaped hole permanently. Leaves the non-ARB shape guarded by review alone.
- **D2 — D1 plus a Dart AST detector** for "a raw exception identifier interpolated into
  a widget-rendered string", in the style of
  `scripts/lib/orphaned_arb_key_detector.dart`. Catches the class the ARB ratchet cannot
  see. Cost: a real detector plus its pinning test, and a meaningful false-positive
  design problem (distinguishing a rendered `Text` from a `Log.error`).
- **D3 — D1 plus a narrow source guard** in the existing
  `test/l10n/hardcoded_visible_strings_test.dart` style, pinning just the two fixed
  files. Cheap, but source guards go vacuous the moment the code moves.

## Recommendation

**Approach A, with D1 now and D2 filed as a follow-up.**

Approach A is the only option that matches how this repo has actually fixed this problem
twice, and the H28 discovery is what makes it decisively cheaper rather than merely
smaller: the reuse bucket needs no new copy, no new translations, and no new machinery,
while the enum bucket is reserved for the two or three sites that genuinely have a
taxonomy worth telling apart. Approach B spends a 40-60 key translation budget on
branches that provably cannot throw; Approach C was already weighed and rejected in this
codebase for producing vague copy.

D1 rather than D2 for this PR because the existing ratchet was authored for this exact
issue and is currently ineffective — regenerating it to zero is both the smallest change
and the one that closes the actual documented hole. D2 is a genuinely good idea, but a
new AST detector is its own reviewable unit with its own false-positive design, and
folding it into a 24-site refactor would obscure both.

## Open Questions for /plan

- [ ] Does the non-timeout arm of `discoverListsFailedToLoadWithError` reuse
      `discoverListsFailedToLoad`, or earn its own actionable copy?
- [ ] For the relay-diagnostic sites, exactly which log call carries the detail —
      an existing `Log.error` or a new one — so no diagnostic signal is lost.
- [ ] `relaySettingsLastError` is dead because `recordRequestFailure` has no production
      caller. Delete the branch and the field, or wire the field to its real callers?
      (User decided: delete the key and give explore a real error state; the relay
      statistics field is the remaining sub-decision.)
- [ ] Exact enum names and arms for the two enum-bucket sites.
- [ ] Whether `reportFailed` should keep surfacing **server prose** (`result.error`)
      at all — it is the same class as the invite `?error=` injection PR #8307 removed.

## Prerequisites

- [ ] None blocking. Worktree `.worktrees/3589-raw-exception` exists on
      `fix/3589-raw-exception-text` from `origin/main`, `pub get` done, and the app is
      confirmed building and running on a physical iPhone from it.

## Next Step

`/plan 3589`
