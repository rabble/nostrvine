# Video card view-count display

**Date:** 2026-08-08
**Status:** Approved, ready for implementation planning
**Target:** Release before the ~2026-08-13 freeze

## Problem

A video card's secondary line renders an unconditional loop count. A freshly
posted video reads `0 loops`, and funnelcake is about to guarantee new
creators' first videos 100–200 impressions through an exploration budget. Those
videos would surface stamped with a discouraging number: we pay for the
distribution and simultaneously tell every viewer not to bother.

Supporting measurements:

- 80% of new creators never reach 100 views on any first-week video.
- Crossing ~100 views roughly doubles the chance they keep posting (31% → 61%).
- New-creator content out-performs established-creator content per impression
  (loops 1.143 vs 1.092, completion 1.147 vs 1.097), so it deserves a fair
  viewing that a low count denies it.

Creator-facing counts are the opposite case. Bernstein et al. (CHI 2013) found
people badly underestimate their audience, and that perceived audience drives
production. The exploration floor will create exactly that underestimate, so
the creator's own view of their numbers stays intact.

The date is more useful on Divine than on other platforms: ~2.2M archived vines
from 2013–16 sit alongside content posted minutes ago. "Apr 22, 2014" vs
"3h ago" reframes what the viewer is watching and turns a bare clip into an
artifact. It also partly addresses a recurring review complaint about confusing
archive content ("weird videos of old people", App Store, 2026-08-06, v0.1.17).

## What the code actually does today

The number on the card is a **loop** count, not a view count.

The live site is `mobile/lib/widgets/video_feed_item/video_feed_item.dart:394`,
inside `VideoOverlayActions.build`. It renders `videoFeedLoopCountLine` directly
under the author name, unconditionally — so `0 loops` on a fresh post is real.

`VideoEvent.totalLoops` (`mobile/packages/models/lib/src/video_event.dart:1084`)
is:

```dart
int get totalLoops =>
    (originalLoops ?? 0) + (int.tryParse(rawTags['views'] ?? '') ?? 0);
```

Archive Vine loops **plus** live Divine views, summed into one number. The two
components are available separately, which is what makes the rule below
non-arbitrary.

Other surfaces carrying the same line:

- `mobile/lib/widgets/video_feed_item/metadata/metadata_stats_row.dart` — the
  more-info sheet. Already shows Loops/Likes/Comments/Reposts plus a
  Vine-vs-Divine breakdown for classic vines.
- `mobile/lib/screens/inbox/conversation/widgets/message_bubble.dart:1161` — DM
  video previews. **Out of scope.**
- `video_author_info_section.dart` and `actions/video_description_overlay.dart`
  are dead code — instantiated only by their own tests, referenced in `lib`
  only from two comments. **Left untouched.**

## Decisions

### Scope: display change only

The spec that motivated this work asked for a randomized variant flag and a
`video_card_shown` impression event. Neither is cheap here:

- `mobile/lib/features/feature_flags/` is the wired flag system: enum-based,
  boolean only, local SharedPreferences plus build config. No user bucketing,
  no variants.
- `mobile/lib/services/feature_flag_service.dart` is HTTP-backed and *does*
  support variants and rollout hashing — but has zero imports anywhere in `lib`
  or `test`. Dead code.
- No impression event exists. `AnalyticsService` has a generic `track()`, but
  all view tracking is playback-side.

So randomized measurement is infrastructure work, not a flag toggle. It was cut
from this change and deferred to separate post-freeze work. **The hypothesis in
the originating spec therefore stays untested by this change** — that is a
deliberate trade, made because this was already the third client change queued
for the same four days and the designated one to slip.

### Display rule

| Case | Date | Count | Renders |
|---|---|---|---|
| Flag off | — | `totalLoops` | `12 loops` (today's behavior, unchanged) |
| Own video | post date | `totalLoops` | `3h ago · 12 loops` |
| Classic vine | post date | `originalLoops` | `Apr 22, 2014 · 2.1M loops` |
| Someone else's Divine post | post date | none | `3h ago` |
| Preview mode (`video == null`) | none | none | line omitted |

Cases are evaluated in the order listed, so `isOwnVideo` wins over
`isOriginalVine`. A creator viewing their own classic vine — possible where a
vine account has been claimed — sees `totalLoops`, the combined archive plus
live number, because at that point it is their own performance data rather than
a public signal.

Two further consequences worth stating explicitly:

**Classic vines use `originalLoops`, not `totalLoops`.** The archival number is
the historical fact being surfaced. `totalLoops` would silently fold live
Divine views into "how famous this vine was".

**Preview mode currently renders a bogus `0 loops`** — `video?.totalLoops ?? 0`
with a null video. The rule drops the line instead. This is a behavior change
on share previews that was not requested; it is small and an improvement, but
it is a change.

The creator's own zero stays visible. `0 loops` on your own fresh post is
accurate, it is the status quo, and it is the number the exploration budget
exists to move.

### Date format: age-adaptive

Relative under 7 days (`3h ago`), absolute with the year beyond it
(`Apr 22, 2014`). This produces the fresh-vs-archive contrast the change is
for. Always-absolute reads cold on a ten-minute-old post; always-relative turns
a classic vine into `12y ago`, which reads as neglect rather than history and
works against the App Store complaint above.

### Card copy: reuse the shipped key

The card keeps `videoFeedLoopCountLine` ("12 loops"). No new ARB key, so no
16-locale mirroring for the card. The warmer "12 people watched this" framing
goes to the creator analytics screen instead, where the line is not width-
constrained.

### More-info sheet: reorder, don't restyle

Move the Loops `_StatColumn` from first to last position in
`MetadataStatsRow`. The count stays available per the originating spec's
"de-emphasised, not removed", de-emphasised by reading order. Restyling it
smaller in place was considered and rejected — a visually downgraded first
column reads as broken rather than intentional.

## Design

### 1. Pure resolver

New file `mobile/lib/widgets/video_feed_item/video_card_meta.dart`:

```dart
@immutable
class VideoCardMeta {
  const VideoCardMeta({this.timestamp, this.loopCount});
  final int? timestamp;   // unix seconds; null when the date is unknown
  final int? loopCount;   // null when the count stays private
  bool get isEmpty => timestamp == null && loopCount == null;
}

VideoCardMeta resolveVideoCardMeta({
  required VideoEvent? video,
  required bool isOwnVideo,
  required bool showPostDate,
});
```

No Flutter dependency, so the whole truth table above is unit-testable without
pumping a widget.

Date source matches the more-info sheet:
`int.tryParse(video.publishedAt ?? '') ?? video.createdAt`, suppressed when
`video.hasUnknownOriginalDate` — classic vines whose original date is not
recoverable. A classic vine with neither a usable date nor an archive count
yields `isEmpty`, and the line is omitted.

### 2. Date formatting

Extend `mobile/lib/l10n/localized_time_formatter.dart`. It already wraps the
l10n-free `TimeFormatter` package with ARB strings and uses `package:clock`, so
tests pin time with `withClock`:

```dart
/// Recent posts read as elapsed time; a week or older falls back to an
/// absolute date with the year, so archives read as artifacts.
static String formatPostAge(
  AppLocalizations l10n,
  int unixSeconds, {
  String? locale,
});
```

Under 7 days delegates to the existing localized `formatRelativeVerbose`.
Beyond, `TimeFormatter.formatAbsoluteDate` — `DateFormat.yMMMd(locale)`, whose
doc comment already notes that Vine archives need their year visible.

### 3. Feature flag

`FeatureFlag.videoCardPostDate`, `audience: user`, **default off**. Adding the
enum case forces both exhaustive switches in
`mobile/lib/features/feature_flags/services/build_configuration.dart` to be
updated; the compiler catches an omission.

This is a kill switch and an internal preview toggle. It does not randomize and
does not fetch remotely.

### 4. Widget changes

**`video_feed_item.dart:394`** — replace the unconditional `Text` with the
resolved line. `VideoOverlayActions.build` is already a `ConsumerWidget` with
`ref`, so `isOwnVideo` comes from
`ref.watch(authServiceProvider).currentPublicKeyHex`, the same read
`VideoOverlayActionColumn` already performs at line 673.

Date and count join with `' · '` at the widget layer. That is the established
idiom in this codebase (`sound_tile.dart`, `audio_attribution_row.dart`,
`metadata_sounds_section.dart`, and five other call sites), and it avoids a new
ARB key. The separator is bidi-neutral, so RTL locales order the whole string
correctly.

**`metadata_stats_row.dart`** — move the Loops `_StatColumn` to last.

### 5. Analytics wording

`creator_analytics_screen.dart:718` and `:930` use `analyticsViewsCount` =
`"{count} views"`. Reaching "12 people watched this" requires a **new** key
(`analyticsWatchedCount`), not an edit of the existing value: editing in place
would leave 16 locales holding translations of "views" while English said
something else, which `.claude/rules/localization.md` explicitly warns against.

New key means mirroring across all `app_*.arb` locales or an entry in
`_knownUntranslatedDebt` in `test/l10n/arb_consistency_test.dart`.

**This is the most cuttable item in the change.** It is the only piece carrying
l10n cost, and it is furthest from the stated goal — the card and the more-info
sheet deliver the whole "hide discouraging counts, show dates" outcome without
it. If the pre-freeze window tightens, cut §5 first.

## Testing

| File | Covers |
|---|---|
| `test/widgets/video_feed_item/video_card_meta_test.dart` (new) | Every row of the truth table; `originalLoops` vs `totalLoops` for classic vines; `hasUnknownOriginalDate`; the empty case |
| `test/l10n/localized_time_formatter_test.dart` (extend) | `formatPostAge` either side of the 7-day boundary, under `withClock` |
| `test/widgets/video_feed_item/video_feed_item_meta_line_test.dart` (new) | Flag off renders today's string; flag on + own video renders date and count; flag on + another's Divine post renders no count |
| `test/widgets/video_feed_item/metadata/metadata_stats_row_test.dart` (new) | Column order; classic-vine breakdown still rendering. This file has no test today. |

Widget tests need `AppLocalizations.localizationsDelegates` and
`supportedLocales` on their `MaterialApp`, and must resolve expected strings
from `AppLocalizations` rather than hardcoding English.

No goldens cover these widgets, so there is no golden churn.

## Out of scope

- DM video previews (`message_bubble.dart:1161`) keep the old line.
- The two dead widgets stay as-is.
- `video_card_shown` impression event and variant bucketing — separate
  post-freeze work. Without them this change ships unmeasured.
- Any further de-emphasis of the more-info sheet beyond column order.

## Open risk

This is the third client change queued for the same pre-freeze window, and the
one already designated to slip if something must. Nothing here depends on the
other two, so it can be dropped late without unpicking them.
