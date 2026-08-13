# View and loop metrics — investigation findings

**Date:** 2026-08-13
**Status:** Findings record. Companion to
[the design spec](2026-08-13-view-and-loop-metrics-design.md).

Everything established during the 2026-08-13 investigation, with sources, so
none of it has to be rediscovered. Claims are marked **measured**, **read from
code**, **sourced**, or **inferred**. Where an earlier conclusion was wrong it
is recorded as wrong rather than deleted, because several of them were
confidently stated and may have been repeated elsewhere.

---

## 1. The outage (resolved)

**Measured.** Daily mobile viewers fell 676 (Aug 1) → 263 (Aug 12) while
`divine-web/1.0` stayed flat at ~40 through the same ingest and tables. GA4
daily users were flat at ~1,450. The decline tracked 1.0.19 adoption.

**Read from code.** Root cause: #6722 changed `publishViewEvent` to require
`video.addressableId`, which derives strictly from `addressableDTag`.
`ViewEventRetryService._toVideoEvent` rebuilds a `VideoEvent` from stored queue
columns and never set that field, so every swept row hit the guard and returned
before the event was constructed. **The event was never sent** — not rejected
by the relay.

The durable queue is the *primary* path: `AnalyticsService` enqueues first and
only direct-publishes if enqueueing fails, and the sole caller always passes a
non-null pubkey. So for any signed-in user on 1.0.19 the loss was total. That
predicts Aug 12 survivors at ~45% of baseline (the 1.0.17 remainder) ≈ 272
against 263 observed.

Fixed and merged in **#7210** (`625b12f277`). The reviewer's follow-up commit
correctly guarded against `videoVineId == videoId`, which would otherwise mint
bogus addressable coordinates for videos with no real `d` tag.

**Not recoverable:** the stranded on-device backlogs replay at *publish* time,
so they land on rollout day rather than the days they happened. Historical
daily leaderboards for Aug 8–13 stay wrong permanently.

Detection added in **divine-funnelcake#917** — per-client daily volume against
each client's own trailing 7-day median. Backtested: no ordinary-day alerts
across 24 days, fires on 2026-08-08, the first day of the outage.

---

## 2. The undercount is much larger than the outage

### 2.1 Interaction-overlap: the best instrument available

**Measured.** A like, comment, or repost proves the person watched. Comparing
interactors against reporting viewers gives a per-video floor on the loss with
no benchmarks or assumptions.

Event `a3092dfc8d36d15583d0866ae4312fd32b96a8eb59d79a7f23028c1ffc6d5503`
(posted 2026-08-13):

| Measure | Count |
|---|---|
| Distinct people who liked / commented / reposted | 37 |
| Distinct people who registered a view | 26 |
| Interactors who registered a view | **10 of 37** |

**73% of provably-real viewers are absent from the view count.** Displayed 108;
implied floor above 400. A floor twice over — it counts only people who
interacted, and silent viewers are missing on top.

This method works on any video, any day. It should replace the indirect
estimates below.

### 2.2 Weaker corroborating estimates

**Measured, but indirect.** Both agree in direction:

- Recorded views imply an 8–18% per-user interaction rate against a 1–5%
  short-form industry norm.
- Recorded views run at ~1.0 per CDN download, for a format where one download
  serves many playthroughs.

### 2.3 Every known cause subtracts

**Read from code.** None of these inflate:

- A view requires ≥1s of *actual playback* — `_totalWatchDuration` accumulates
  only while playing, so a still-buffering video that is scrolled past records
  nothing.
- Anonymous viewers contribute **zero loops** (§3.2).
- The relay discards the client's real playthrough count (§3.1).
- The queue regression dropped signed-in reporting entirely for six days.

**This is not a choice between accurate and flattering. It is a choice between
wrong-low and less-wrong.**

---

## 3. What the metrics actually are

### 3.1 `loops` is a watch-time ratio, and the real count is discarded

**Read from code.** `crates/relay/src/view_handler.rs`:

```rust
fn watch_loops(watched_seconds: u32, video_duration_seconds: f64) -> f64 {
    let watched_seconds = f64::from(watched_seconds.max(1));
    watched_seconds / effective_duration_seconds(video_duration_seconds)
}
```

So a stored "loop" is `watched_seconds / duration` — a fraction, not a count.
Observed range 0 to 218.2, mean 0.99, median 0.75.

**The mobile client already computes the Vine-correct number and it is thrown
away.** `divine_video_metrics_tracker.dart` increments an integer `_loopCount`
on wrap detection, and `view_event_publisher.dart` emits it:

```dart
if (loopCount != null && loopCount > 0) ['loops', loopCount.toString()],
```

The relay's tag parser matches `a`, `e`, `viewed`, `source`, `client`, and
`_ => {}` for everything else. **The `loops` tag falls through and is
discarded.** Wiring it up is a small change with large consequences.

Caveat on the client counter: wrap detection requires the last sampled position
to be within 1000 ms of the end (`_lastPosition!.inMilliseconds >
duration.inMilliseconds - 1000`). If position updates are sparse or jittery,
wraps are missed. Unquantified.

### 3.2 Anonymous viewers reach views but never loops

**Measured.** `total_views = cdn_views + auth_views` holds exactly, zero
exceptions across 2,201,983 videos. CDN is 42% of all views (4.70M of 11.14M).

But loops derive from `view_interactions`, which is signed-only. So anonymous
viewers — 42% of the audience — contribute **no loops at all**. Loops is the
worse-measured metric, not the smaller one.

### 3.3 The card shows views under a loops label

**Read from code.** `mobile/packages/models/lib/src/video_event.dart`:

```dart
/// Total loops combining archived Vine loops and live diVine views.
int get totalLoops =>
    (originalLoops ?? 0) + (int.tryParse(rawTags['views'] ?? '') ?? 0);
```

For a video with no archive history the first term is zero, so the card's
"N Loops" renders the **view** count. The sampled video displayed "108 Loops"
against a real stored loop value of 42.

**The actual loop number is displayed nowhere in the app.** Independent of the
outage; survives the #7210 fix. Note the trap: pointing the card at the current
loop metric would *cut* every Divine-native card by roughly a third, so the
label fix and the counting fix must ship together.

### 3.4 Loop tracking has a state bug

**Read from code.** `_handleState` returns on its first line when
`!widget.isActive`. Opening a route (e.g. the comment sheet) sets
`_routeAllowsPlayback = false` → `isFeedActive` false → the **pause event is
never processed**. `_isPlaying` stays true and `_lastPlayStartTime` stays set,
so `_finalizeAndPublish` later adds the entire span including the paused
period. Direction of error: **inflates** watch time for users who open
comments. The only known error in that direction.

---

## 4. What Vine actually did

**Sourced** — 2014 trade press, listed at the end.

- **Loops counted every playthrough, not viewers.** "If one person watches a
  video on loop 10 times in a row, this will count as 10 loops — it's not
  per-click, or per-viewer."
- **Autoplay counted, and Vine was criticised for it.** Loops accrued "even if
  the video is not actually being watched"; an embedded Vine incremented as
  long as the tab stayed open. Vine shipped it anyway.
- **Embeds counted**, on Vine and across the web, in real time.
- **Tracking began 3 April 2014.** Older videos showed `+` beside the count,
  meaning the true number is higher than displayed.
- **Calibration:** contemporary commentary treated ~3 loops per viewer as a
  marker of strong engagement.

**Unresolved:** sources conflict on whether the *first* play counted as a loop
or only replays. Needs a better source than 2014 trade press.

### Divine versus Vine

| | Vine | Divine today |
|---|---|---|
| Unit | one playthrough = 1 loop | `watched_seconds / duration`, fractional |
| Autoplay | counted | only if ≥1s and signed in |
| Unattended playback | counted | not counted |
| Anonymous viewers | counted | contribute zero loops |
| Incomplete data | shown as `N+` | silently undercounted |
| Engagement benchmark | ~3 loops/viewer = strong | **0.65 loops/view measured** |

Divine measures ~4.6× below what Vine considered a good video, on a metric
carrying Vine's name.

**The framing that matters:** the word "loops" already carries Vine's meaning.
Printing "108 Loops" for a number computed under stricter-than-Vine rules is
the *misleading* option. Adopting Vine semantics is not inflation — it makes
the number mean what the label already promises. Divine is read as Vine 2.0, so
an undercounted loop number reads as failure rather than as caution.

---

## 5. Ranking archaeology

**Read from deployed `system.tables`**, not migrations — migrations drift.

| Date | Event |
|---|---|
| 2026-01-05 | Trending formula written: `engagement × decay`, no views term |
| 2026-01-16 | Kind-22236 view ingestion ships — 11 days *later* |
| 2026-04-13 | Leaderboard rebuilt, uses `views + unique_viewers × 2` |
| 2026-06-15 | A **second** trending formula added, view-velocity |
| 2026-08-05 | Popular rebuilt, uses views as a linear term |

Nobody chose this. Each surface encoded whatever data existed the day it was
written, and old formulas were carried forward by refactors.

**Two contradictory trending formulas are live at once.** The API serves
`trending_videos_snapshot` (`crates/clickhouse/src/client.rs:3541`), populated
by a **view-velocity** MV (`period_views / prior_period_views`).
`trending_videos_base_snapshot` uses engagement-decay. The naming does not
indicate which is which.

Formulas, verified:

- `engagement_score = reactions + comments×2 + reposts×3` — **no views term**.
  Verified across 74,205 rows, zero mismatches.
- `popular_score = (views + log1p(loops)×0.5 + engagement_score×4) × decay`
- `leaderboard rank_score = views + unique_viewers×2 + log1p(loops)×0.5 +
  reactions×4 + comments×8 + reposts×12`

So Popular and Leaderboard rank on views directly; the served Trending ranks on
view *velocity*. All three were moved by the outage.

**Also affected:** Gorse recommendations consume view feedback with distinct
scores for completed vs extended watches. Extent unmeasured.

---

## 6. Corrections to earlier conclusions

Recorded because each was stated confidently and may have been repeated.

1. **"Trending is corrupted"** → then **"trending is clean, no views term"** →
   **finally: the served trending object *is* view-based.** The middle claim
   came from reading `trending_videos` and `trending_videos_base_snapshot`,
   neither of which is what the API serves.
2. **"Loops is the biggest number, lead with it"** — wrong on today's data
   (0.65 per view). But the ratio comes from a pipeline where 42% of the
   audience contributes zero loops, so it cannot settle the question either.
3. **"`loops >= views` is an invariant"** — false. 91% of `view_counts` rows
   have loops below views.
4. **"The display floor is mis-set and starves creators"** — wrong. Creators
   always see their own count (`isOwnVideo`), so the floor never gated the
   retention effect. Only 0.04% of videos reach 1000; that is deliberate.
5. **"Loops are lost behind the comment sheet"** — wrong. The video pauses on
   route push. The real defect is the opposite (§3.4).
6. **Persistent bias toward conservatism.** Framing the view-definition
   question with "completed loop" among the options, calling a flat number
   "true rather than bigger," repeatedly appending inflation caveats. Every
   measured error runs one way; adding caution on top compounds it.

---

## 7. Open questions

- Does the first play count as a loop under Vine semantics? (§4)
- How much has Gorse skewed since Aug 8? (§5)
- How many wraps does the client's detector miss? (§3.1)
- Integer playthroughs vs fractional ratio as the stored value — and whether
  the fraction survives as a ranking-only signal.
- Whether to fix §3.4, which is correct but reduces loops for engaged users.

## 8. Related work

| Item | Status |
|---|---|
| divine-mobile #7210 — outage fix | **merged**, `625b12f277` |
| divine-funnelcake #917 — volume detector | open, green, awaiting review |
| divine-mobile #7211 — no-release-freezes policy | open, green, awaiting review |
| divine-mobile #7212 — this design spec | open, awaiting review |

## Sources

- [Vine's New "Loop Counts" May Cause Video Marketing Deception — ClickZ](https://www.clickz.com/vines-new-loop-counts-may-cause-video-marketing-deception/30719/)
- [Vine Adds Loop Count, Updating Video Views in Realtime — The Realtime Report](https://therealtimereport.com/2014/07/08/vine-adds-loop-count-updating-video-views-in-realtime/)
- [Vine adds loop counts to reveal how many times people watched a video — TNW](https://thenextweb.com/news/vine-adds-loop-counts-reveal-many-times-people-watched-video)
- [Vine Update Introduces Loop Counts — TechCrunch](https://techcrunch.com/2014/07/01/vine-update-introduces-loop-counts-so-you-know-how-great-you-are/)
