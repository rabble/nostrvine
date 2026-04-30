# Brainstorm: dates on posts (issue #2432)

Date: 2026-04-30

Linked: [#2432 — feat: dates on posts](https://github.com/divinevideo/divine-mobile/issues/2432)
Figma: [UI-Design / metadata-expanded](https://www.figma.com/design/rp1DsDEUuCaicW0lk6I2aZ/UI-Design?node-id=15201-37298)

## Status

Both originally-open product questions (empty-title fallback, spacing mix)
are **resolved by the Figma layer hierarchy** — see "Figma evidence" below.
Recommendation now stands as final; the brainstorm hands off to `/plan`
without needing async confirmation from @Chardot.

## Figma evidence (resolves Axes 4 and 5)

`mcp__figma__get_metadata` on node 15201:37298 returns the exact pixel layout
of the title cluster:

```
Frame 382 (15201:37585) — bordered card, 402 × 372
└── Content (15201:37586) — at (16, 20), 370 × 116, gap: 16
    ├── Frame 381 (15201:37587) — at (0, 0), 370 × 84, gap: 8
    │   ├── Headline "Who knew?" (15201:37588) — y=0, height 28
    │   └── Supporting text (15201:37589) — y=36, height 48
    └── Supporting text "Apr 22, 2003" (15201:37590) — y=100, height 16
```

**Spacing (Q5)** — computed from absolute coordinates:

- Title bottom (y=28) → description top (y=36) = **8 px**.
- Description bottom (y=84) → date top (y=100) = **16 px**.

The 8 px gap lives **inside** Frame 381 (title↔description sub-cluster). The
16 px gap is between Frame 381 and the date, governed by the outer Content
frame's `gap: 16`. The mixed rhythm is the design intent. **Q5 → Option 5B**.

**Empty-title (Q4)** — the date is structurally a **sibling of Frame 381**,
not nested inside it. Frame 381 holds only [title, description]; the date is
a Content-level child positioned 16 px below it. If both title and
description collapse (auto-layout), Frame 381 shrinks to 0 and the date
sibling still renders. The designer made an explicit choice to keep the date
independent of title/description presence. **Q4 → Option 4B**.

## Problem Statement

Users have asked for visible publish dates on posts so they can tell new
content from classic Vine archives. Per the 2026-04-27 design clarification
from @Chardot, the date appears **only** in the video info sheet — not on
grid tiles, the fullscreen video overlay, or the profile grid — and classic
Vines must show their original Vine-era date (preserved on the Nostr event's
`published_at` tag), not the re-publish date.

The investigation already confirmed there is no data plumbing to do:
`VideoEvent.createdAt` already collapses the Vine-era date and the Nostr
`created_at` into a single integer that prefers `published_at` when present
(`mobile/packages/models/lib/src/video_event.dart:500–505`). This brainstorm
focuses on implementation trade-offs at the presentation and utility layers.

## Constraints

- **Layered architecture** — UI → BLoC → Repository → Client; no logic creep
  into widgets. (`rules/architecture.md`)
- **VineTheme + divine_ui only** — no inline `TextStyle`, no raw colors, no
  `Icons.*`. The date uses `VineTheme.labelMediumFont(color:
  VineTheme.onSurfaceVariant)` to match Inter SemiBold 12px / 75% white in
  the Figma. (`rules/ui_theming.md`)
- **L10n-first** — every user-facing string goes through `context.l10n`. The
  date itself comes from `intl`'s `DateFormat.yMMMd(locale)`, which is
  locale-aware out of the box; any wrapper label (e.g. for `Semantics`)
  needs an ARB key. (`rules/localization.md`)
- **Accessibility** — meaningful text needs screen-reader context. A bare
  date in the middle of a metadata sheet should carry a `Semantics(label:
  ...)` so TalkBack/VoiceOver announces "Posted on April 22, 2003" rather
  than just the date. (`rules/accessibility.md`)
- **Strict-coverage packages** — `divine_ui` is the only confirmed strict
  package per `rules/testing.md`. Need to verify whether `time_formatter`
  also gates on coverage; in any case, a test goes in the same PR as a new
  public method.
- **Page/View pattern + widgets-over-methods** — any new widget is a private
  class, not a `Widget _buildXxx()`. (`rules/code_style.md`)

## Prior Art

- **Info sheet widget** —
  `mobile/lib/widgets/video_feed_item/metadata/metadata_expanded_sheet.dart`.
  `_MetadataContent.build` (line 92) lays out the sheet as a `ListView`;
  `_TitleSection` (line 170) renders the title + description cluster.
- **Video model with effective timestamp** —
  `mobile/packages/models/lib/src/video_event.dart:500–505` (parser preferring
  `published_at` over Nostr `created_at`); `:939–945` (`isVintageRecoveredVine`
  getter, the same logic in reverse).
- **Existing time utilities** —
  `mobile/packages/time_formatter/lib/src/time_formatter.dart` (locale-blind)
  and `mobile/lib/l10n/localized_time_formatter.dart` (locale-aware sibling
  with `AppLocalizations` threaded through). Both already use
  `DateFormat.yMMMd(locale)` internally for cross-year dates
  (`time_formatter.dart:114`, `localized_time_formatter.dart:225`).
- **Existing tests** —
  `mobile/test/widgets/video_feed_item/metadata/metadata_expanded_sheet_test.dart`
  has the `buildSubject` harness with localization delegates already wired,
  and a `_TitleSection (via MetadataExpandedSheet)` group ready to extend.
- **Adjacent timestamp tickets** — #2905 (open) on UTC normalization;
  #2906 / #2694 (closed) precedent for the `isUtc: true → toLocal()` pattern
  the existing `TimeFormatter` uses.

## Approaches Explored

### Axis 1 — Where the date widget lives in the tree

#### Option 1A: Inside `_TitleSection`, nested-Column structure mirroring Figma (recommended)

**Description:** `_TitleSection`'s outer `Column` gets two children: an inner
`Column` for [title, description] (uniform 8 px spacing), and the
`Semantics`-wrapped date `Text` separated by a 16 px `SizedBox`. This
mirrors the Figma frame hierarchy exactly: Frame 381 (title+description
sub-cluster) sibling the date inside the Content frame.

**Layers affected:** Presentation only.

**Pros:**
- Matches the design's structural grouping precisely (two-level Column
  mirrors two-level frame hierarchy).
- Natural mapping for asymmetric spacing (8 px inside the inner cluster,
  16 px between cluster and date) — no need to drop the `spacing:`
  shorthand on the inner Column.
- Date visibility decouples cleanly from title/description visibility:
  the inner Column collapses to 0 height when both are empty, but the
  outer Column still renders the date.

**Cons:**
- Mildly misnames `_TitleSection` if you read it pedantically; rename to
  `_HeaderSection` is optional.

**Complexity:** Low.

#### Option 1B: New `_DateSection` between `_TitleSection` and `MetadataStatsRow`

**Description:** Add a sibling widget at index 1 of `_MetadataContent`'s
`ListView`. Independent gating logic.

**Pros:**
- Date renders regardless of title/description state.
- Cleaner separation of concerns.

**Cons:**
- Doesn't match the Figma cluster (date is visually inside the title card,
  8 px below description, sharing a bordered block).
- Border seam handling becomes awkward — either two cards with two borders,
  or a contrived shared border.

**Complexity:** Low–medium.

#### Option 1C: Add a `trailing` slot parameter to `_TitleSection`

**Description:** Make `_TitleSection` take an optional `Widget? trailing` so
the `_MetadataContent` can pass a date slot.

**Pros:**
- Composable in theory.

**Cons:**
- YAGNI red flag. Single use site, single private widget.

**Complexity:** Low (mechanically), but unjustified abstraction.

### Axis 2 — Where the date formatter lives

#### Option 2A: Extend `mobile/packages/time_formatter` (recommended)

**Description:** Add a static method:

> `static String formatAbsoluteDate(int unixSeconds, {String? locale})`

that returns `DateFormat.yMMMd(locale).format(date)` after the existing
`fromMillisecondsSinceEpoch(..., isUtc: true).toLocal()` dance.

**Pros:**
- Co-located with peer methods (`formatConversationTimestamp` etc.) that
  already use `DateFormat.yMMMd`.
- Pure utility; trivial to unit-test.
- No `AppLocalizations` dep — date format is locale-driven, not
  string-driven.

**Cons:**
- Coverage gate on `time_formatter` needs verification; in practice we add
  a test in the same PR regardless.

**Complexity:** Low.

#### Option 2B: Extend `LocalizedTimeFormatter`

**Description:** Sibling to `formatNotificationTimestamp` taking
`(AppLocalizations l10n, int unixSeconds, {String? locale})`.

**Pros:**
- Sibling-pattern uniformity.

**Cons:**
- Threads `AppLocalizations l10n` purely decoratively — we don't read any
  l10n strings.
- Forces every caller to grab `context.l10n` for a value we don't use.

**Complexity:** Low.

#### Option 2C: Inline `DateFormat.yMMMd(locale).format(...)` at the call site

**Pros:**
- Cheapest possible diff.

**Cons:**
- Loses unit-test isolation.
- Sets a precedent for the next surface needing the same format.
- Bypasses the `time_formatter` package convention.

**Complexity:** Trivial, but corrosive.

### Axis 3 — L10n shape

#### Option 3A: Bare date, no l10n strings

**Description:** Just `Text(formatted)`.

**Pros:** Zero translation churn. `DateFormat.yMMMd(locale)` already
localizes the format string.

**Cons:** Screen readers announce the date with no context.

**Complexity:** Low.

#### Option 3B: Labeled date — "Posted Apr 22, 2003"

**Description:** ARB key `metadataPostedDate({date})` rendered inline.

**Pros:** Self-describing visually and for screen readers.

**Cons:** Diverges from Figma; eats horizontal space; translation cycle for
a leading word.

**Complexity:** Low–medium.

#### Option 3C: Bare visual + `Semantics` label (recommended)

**Description:** Visual is `Text(formatted)` per Figma. Wrap in
`Semantics(label: l10n.metadataPostedDateSemantics(formatted))` so screen
readers say "Posted on April 22, 2003."

**Pros:** Visual matches design exactly; accessibility honored; one ARB key.

**Cons:** One extra wrapping widget and one ARB key. Minor.

**Complexity:** Low.

### Axis 4 — Empty-title fallback (RESOLVED → Option 4B)

`_TitleSection` currently early-returns `SizedBox.shrink()` when title and
description are both empty (`metadata_expanded_sheet.dart:182`).

**Resolution from Figma (see "Figma evidence" above):** the date sits in
the layer tree as a sibling of Frame 381 (the title+description
sub-cluster), not as a child. The designer's structural choice means the
date renders independently of title/description presence. Option 4B is
locked in.

#### Option 4A: Keep early-return; date gated on title or description

**Cons:** Contradicts the Figma layer structure. A classic Vine without
title/description — the prime use case — would lose its date.

**Verdict:** Rejected.

#### Option 4B: Render the section when ANY of {title, description, date} is present ✓ RECOMMENDED

**Description:** Drop the `hasContent` early-return entirely (or weaken it
to `video.createdAt > 0`, effectively always true for a real post). The
inner Column for title/description collapses to 0 height when both are
absent, exactly as Figma's auto-layout does for Frame 381.

**Pros:**
- Matches Figma's structural intent.
- Date always visible — serves the issue's primary motivation
  ("distinguish classic from new content") for every video.

**Cons:** A title-less, description-less video shows just a small grey date
in an otherwise-empty header card. Visually fine; just spare.

**Complexity:** Low.

#### Option 4C: Always-render `_DateSection` separate from title section

(= Option 1B from Axis 1.)

**Verdict:** Rejected on Axis 1 for visual-grouping reasons.

### Axis 5 — Section spacing (RESOLVED → Option 5B)

**Resolution from Figma (see "Figma evidence" above):** absolute pixel
coordinates from `mcp__figma__get_metadata` show 8 px between title bottom
and description top, 16 px between description bottom and date top. The
mixed rhythm is the design intent, not a Figma artifact. Option 5B is
locked in.

#### Option 5A: Uniform `spacing: 8` for all three children

**Cons:** Tighter than Figma between description↔date. Off by 8 px from the
verified design.

**Verdict:** Rejected.

#### Option 5B: Mixed — 8 px title↔description, 16 px description↔date ✓ RECOMMENDED

**Description:** With the nested-Column structure from Axis 1, this falls
out naturally. Inner Column keeps `spacing: 8` (title↔description). Outer
Column uses an explicit `SizedBox(height: 16)` (or `Padding`) between the
inner Column and the date.

**Pros:** Matches Figma exactly. Per `rules/code_style.md`: `SizedBox` is
specifically endorsed when gaps differ. The asymmetric gap is contained at
exactly one boundary, so the cost is one `SizedBox` line.

**Cons:** None — the structural mapping is identical to Figma's.

**Complexity:** Trivial.

## Recommendation

A composite of **1A + 2A + 3C + 4B + 5B**, all locked in by Figma evidence:

- **Widget tree** — `_TitleSection` becomes a two-level `Column`: an inner
  `Column` for [title, description] with `spacing: 8`, then a 16 px
  `SizedBox`, then the `Semantics`-wrapped date `Text`. Mirrors Figma's
  Frame 381 + sibling-date hierarchy.
- **Formatter** — `mobile/packages/time_formatter` gets a new
  `formatAbsoluteDate(int unixSeconds, {String? locale})` using
  `DateFormat.yMMMd(locale)` after the standard
  `fromMillisecondsSinceEpoch(..., isUtc: true).toLocal()` dance. Test in
  the same PR per the strict-coverage convention.
- **L10n** — visual is bare `Text` per Figma; accessibility supplied via a
  single new ARB key `metadataPostedDateSemantics(date)` used only as a
  `Semantics(label: ...)` wrapper (suggested copy: "Posted on {date}").
- **Empty-title** — drop `_TitleSection`'s `hasContent` early-return; the
  inner Column collapses naturally when title and description are both
  empty, and the date sibling still renders. Matches Figma's structural
  choice.
- **Spacing** — 8 px inside the inner cluster (existing `spacing:`
  shorthand), 16 px between cluster and date (one `SizedBox`).

This composite stays inside established lanes (no new packages, no new
BLoCs, no model changes), satisfies every relevant rule in
`self_review_checklist.md`, and produces a small PR that fits a single
review (one new method + test, one widget restructure + Semantics wrapper +
ARB key, one new widget test group).

## Open Questions for /plan

- [ ] **Semantic label copy** — exact wording for
      `metadataPostedDateSemantics(date)`. Suggested: "Posted on {date}".
      Low-priority detail; pick at PR time if not specified.
- [ ] **`time_formatter` coverage gate** — verify whether the package
      enforces 100 % line coverage (the rule in `rules/testing.md` only
      cites `divine_ui` explicitly). Either way, add unit tests for
      `formatAbsoluteDate` in the same PR.

## Prerequisites

None. Both originally-blocking product questions are resolved by Figma
layer evidence.

## Next Step

`/plan https://github.com/divinevideo/divine-mobile/issues/2432`.
Implementation is well-scoped and fits a single PR.
