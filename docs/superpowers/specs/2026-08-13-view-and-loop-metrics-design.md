# View and loop metrics

**Date:** 2026-08-13
**Status:** Design — decisions settled
**Target:** No freeze applies; ships on the normal release path

## Problem

Divine has no shared definition of a view, and three discovery surfaces that
each rank on a different theory of merit. None of it was decided — it accreted
as data became available, and old formulas were carried forward by refactors
rather than revisited.

| Date | Event |
|---|---|
| 2026-01-05 | Trending formula written: `engagement × decay`, **no views term** |
| 2026-01-16 | Kind-22236 view ingestion ships — 11 days *later* |
| 2026-04-13 | Leaderboard rebuilt, uses `views + unique_viewers × 2` |
| 2026-06-15 | A **second** trending formula added, view-velocity |
| 2026-08-05 | Popular rebuilt, uses views as a linear term |

Two contradictory trending formulas are live simultaneously on
near-identically-named objects. The one the API serves
(`trending_videos_snapshot`, via `client.rs:3541`) is the view-velocity one —
not the one the object naming suggests.

The kind-22236 outage (#7210) exposed this. When mobile view reporting stopped,
`views`, `unique_viewers` and `loops` all fell ~60–69% in six days, which moved
Trending, Popular and the creator Leaderboard while Divine had no way to notice.
Detection is being added separately (divine-funnelcake#917).

Underneath the outage sits a permanent undercount. Two independent estimates
put recorded views at roughly a third of reality:

- Recorded views imply an 8–18% per-user interaction rate against a 1–5%
  short-form industry norm.
- Recorded views run at ~1.0 per CDN download, for a format where one download
  serves many playthroughs.

Causes are definitional, not defects. A view today requires **≥1s of actual
playback**, which excludes the scroll-past and the still-buffering.

Anonymous coverage is split, and the split is the confusing part. Because view
events are Nostr-signed, anonymous viewers appear in `total_views` via CDN
delivery — 42% of all views — but are entirely absent from everything derived
from `view_interactions`: `unique_viewers`, `loops`, and the daily stats that
feed the leaderboard. So the headline view count sees them and the hero loop
metric does not.

Numbers are not cosmetic here.
[The video-card view-count spec](2026-08-08-video-card-view-count-display-design.md)
measured that crossing ~100 views roughly doubles the chance a new creator keeps
posting (31% → 61%), and that 80% of new creators never reach it. Understated
counts suppress the behaviour the product depends on.

## Decisions

**1. Two metrics, not one.** Views and loops answer different questions and
must stop being conflated.

- **Loops** — every playthrough. Depth. Unbounded by nature.
- **Views** — one per playback start, per session. Reach. Bounded per person.

**2. A view is a playback start.** Not ≥1s, not a completed loop. This matches
TikTok and Reels, so a creator arriving from either reads Divine's numbers in
familiar units. It is also the largest defensible definition.

Rejected: *completed loop* (strictest option; 60.3% of current view events never
complete one, so it would cut recorded views to ~40%) and *≥1s* (today's rule,
comparable to nothing).

**3. Both metrics count everyone.** Signed-in and anonymous alike. Anonymous
viewers are roughly half of daily users and are currently invisible. This is the
single largest correction available and every other platform already does it.

**4. Loops is the hero number.** Largest, Vine-native, and unique to Divine —
no other platform can quote a loop count. It is already what the video card
renders.

**5. A displayed number is never reduced — but it may be withheld.** These are
different acts and only one of them is a lie.

- **Never reduce.** No damping, capping, or silent dedup on any number that is
  shown. A creator can count their own loops; a shaved number is a trust
  violation and a discoverable one.
- **Withholding is legitimate.** Showing nothing is an editorial choice, not a
  false statement.
  [The video-card spec](2026-08-08-video-card-view-count-display-design.md)
  already establishes this: a public count renders only at or above
  `publicLoopCountFloor` (1000), because below that it reads as a warning rather
  than a recommendation, and small numbers were themselves suppressing adoption.
- **A creator always sees their own true number**, however small — correcting a
  creator's underestimate of their audience is what keeps them posting
  (Bernstein et al., CHI 2013).

The three rules compose: raw counts everywhere they appear, a floor governing
whether a *public* count appears at all, and no floor on a creator's own view of
their own work.

**6. Anti-spam lives entirely in ranking.** Nobody is owed a slot on Popular, so
ranking can be as aggressive as it needs to be. Because public counts never
move, aggressive filtering produces no creator-facing complaint — which makes it
easier to be strict, not harder.

**7. Each surface gets one stated job and one formula.** The duplicate and
contradictory ranking objects are removed, not left alongside.

| Surface | Job, in words a user could repeat |
|---|---|
| Trending | Rising fastest right now |
| Popular | Most-watched over a window |
| Leaderboard | Best creators over a period |

## Design

### Metric definitions

```
loop   := one completed playthrough of the video
view   := one playback start, deduplicated per viewing session
session:= a continuous period of engagement with one video by one viewer
```

`loops >= views` always holds. Both are emitted per viewing session, so one
session reports one view and N loops.

The existing `view_interactions.loops` column already stores a fractional
playthrough count (observed range 0 to 218.2, mean 0.99), so the loop metric is
derivable from data collected today. It is `views` that changes definition.

### Display versus ranking

Two pipelines from one event stream, and they must not be collapsed:

- **Display path** — raw sums. What a viewer or creator sees on a video, a
  profile, or in analytics. No filtering of any kind. Whether a public count is
  *shown* is governed separately by `publicLoopCountFloor`; that gate decides
  visibility, never magnitude.
- **Ranking path** — the same events, then anti-spam, then damping. Feeds
  Trending, Popular, Leaderboard, and recommendations.

A single event contributes fully to display and conditionally to ranking. The
divergence is intentional and should be documented wherever both appear, so a
creator asking "why am I not on Popular with 50k loops" gets a real answer.

### Ranking inputs

Ranking damps loops and trusts views, because views are bounded per person and
loops are not — one observed session already carries 218 loops, which under raw
weighting outranks 218 distinct viewers.

Retained from current behaviour: `log1p(loops) × 0.5`, already used by
`popular_score` and the leaderboard. This is not a new brake; it is the existing
one, kept deliberately rather than by accident.

Anonymous events carry weaker identity guarantees than signed ones and should
therefore weigh less in ranking than signed-in events. They still count fully
for display. The exact weighting is a tuning question, not an architectural one.

### Anonymous signal: CDN-derived, one loop assumed

**Decision: each CDN delivery without a matching signed view event counts as one
view and one loop.**

This is not new machinery — it is already how the platform reports. Every
`video_total_views_data` row satisfies `total_views = cdn_views + auth_views`
exactly, with zero exceptions across 2,201,983 videos, and CDN accounts for 42%
of all views (4.70M of 11.14M). The decision is to make the existing behaviour
the stated definition rather than an undocumented accident, and to extend the
same treatment to loops.

It needs no client work, no new ingest endpoint, no unsigned-write abuse
surface, and no privacy decision on a device identifier. An unsigned client
beacon was considered and rejected on that basis: it would measure anonymous
loop depth accurately, but every one of those costs is real and the accuracy
gain does not carry them.

Two limits, stated so nobody later mistakes them for defects:

- **Anonymous loop depth is assumed, not measured.** One delivery serves many
  playthroughs, so an anonymous viewer who loops a video twenty times reports
  one loop. Anonymous engagement depth is therefore systematically conservative
  against signed-in depth. This understates the hero metric rather than
  inflating it, which is the safe direction to be wrong in.
- **CDN counts are noisy.** Observed daily totals swing between 21k and 110k,
  driven by cache behaviour and range requests rather than by audience. Ranking
  should not treat a CDN-derived loop as equivalent in confidence to an observed
  one.

If anonymous loop depth later proves worth measuring properly, the beacon
remains available as an additive change; nothing in this design forecloses it.

### Expected movement

Stacked against today's reported numbers:

| Change | Effect on views | Effect on loops |
|---|---|---|
| #7210 view-event fix (merged) | ×1.7 recovery on the signed-in share | ×1.7 recovery |
| View = playback start | ×2–3 on the signed-in share | — |
| Anonymous counted | already counted (42% of views) | **new — CDN deliveries begin contributing** |
| Loops promoted as headline | — | larger again than views |

Views grow mostly from the redefinition, since anonymous views already flow into
`total_views`. Loops grow mostly from anonymous, since loops are currently
signed-in only and CDN deliveries have never contributed one.

The compounding matters more than either figure: loops is the hero number, and
it is the metric that has been missing 42% of its audience entirely.

The effect compounds with the display floor. `publicLoopCountFloor` is 1000, and
today most videos fall below it — which is why the video-card spec had to
suppress counts in the first place. An order-of-magnitude correction moves a
large share of the catalogue above the floor, so counts start appearing on cards
that currently show only a date. The suppression rule stops being load-bearing
because fewer numbers are embarrassing, rather than because the rule changed.

That is the same lever from both ends: the Aug 8 spec hid small numbers because
small numbers were suppressing adoption; this work makes the numbers correct, so
there are fewer to hide. The floor should be re-examined after rollout — at
truthful volumes 1000 may be set too low or too high, and it is deliberately a
one-line constant.

## Testing

- Unit tests pinning `view`/`loop`/`session` boundaries: a scroll-past with no
  playback start emits nothing; one session with N playthroughs emits one view
  and N loops; `loops >= views` holds as an invariant.
- A test asserting the display path applies no filtering — the property most
  likely to be broken later by someone adding a well-meant cap.
- Ranking-path tests over adversarial input: a single session with hundreds of
  loops must not outrank many distinct viewers.
- Parity test between the signed and anonymous paths, so the two cannot drift to
  different definitions of the same word.
- The divine-funnelcake#917 detector already covers per-client reporting
  collapse and should stay green through the rollout.

## Out of scope

- Recomputing historical rankings for 2026-08-08 onward. The events were never
  sent and cannot be recovered; the on-device backlog replays with publish-time
  timestamps, so it lands on rollout day rather than the days it happened.
  Historical daily leaderboards for that window stay wrong permanently.
- Gorse recommendation retraining. Recommendations consumed the biased sample
  during the outage; the extent is unmeasured and is its own piece of work.
- The sybil-shaped reaction traffic since 2026-08-06. It inflates engagement
  terms rather than view terms and is tracked separately.

## Open risk

**Rollout-day spike.** The #7210 fix replays every stranded on-device backlog at
publish time. Expect a one-day artificial peak that is recovered history, not
growth, and do not read any view metric on that day without accounting for it.

**Numbers move for two reasons at once.** The redefinition and the outage
recovery land close together, so a jump will be hard to attribute. Ship the
detector and record a pre-change baseline first, or the effect of each becomes
unrecoverable.

**Anonymous loop depth is assumed rather than measured.** One CDN delivery
counts as one loop, so anonymous viewers who rewatch report a single loop. The
hero metric is therefore conservative for 42% of the audience. That is the safe
direction to be wrong in, but it should be stated wherever the number is
published rather than discovered later by someone reconciling it.

**CDN delivery is inflatable without an account.** Repeated media requests raise
displayed counts, and decision 5 says displayed numbers are never reduced, so
the only remedy is at ingest — deduplication and rate limiting on delivery
logging. Decision 6 keeps the blast radius out of ranking, but it does not
protect the public number.
