# Analytics Observability

Status: Current contract with semantic route screen views and comments sheet
surface load instrumentation live.
Baseline validated against: `mobile/lib/services/screen_analytics_service.dart`,
`mobile/lib/services/page_load_observer.dart`,
`mobile/lib/screens/comments/comments_screen.dart`.

Current code still contains legacy `screen_load` and `screen_data_loaded`
analytics paths for compatibility. The required semantic `screen_view`
parameters are implemented for routes, and `surface_load` is live for
`comments_sheet`. Additional user-visible surfaces should use the same
`surface_load` contract as they are instrumented.

## Purpose

Analytics must answer operational questions:

- Which user-visible screens or surfaces are slow?
- How slow are they at p50, p75, p95, and p99?
- Did the user see real content, an empty state, or an error?
- Is slowness isolated to an entry point, platform, app version, network type,
  or feature flag?

## Naming

Use semantic snake_case names, never Flutter/native class names.

Examples:

- `home_feed`
- `explore`
- `profile`
- `video_detail`
- `comments_sheet`
- `settings`
- `notifications`

Do not log Nostr event IDs, pubkeys, npubs, nsecs, user-entered search text,
comment text, or raw URLs in analytics parameters.

## Core Events

### `screen_view`

Logged when the user navigates to a full-screen route.

Required parameters:

- `screen_name`
- `entry_point`
- `route_name`

### `surface_load`

Logged once when a user-visible surface reaches a terminal load state.

Required parameters:

- `surface_name`
- `entry_point`
- `result`: `success`, `empty`, `failure`, or `dismissed`
- `visible_ms`
- `data_ms`
- `total_ms`
- `slow_bucket`: `under_1s`, `1_3s`, `3_5s`, `5_10s`, or `over_10s`

Optional safe parameters:

- `item_count`
- `initial_count`
- `has_more`
- `sort_mode`
- `feature_flag`

## Comments Sheet

The comments sheet measures:

- tap/open intent to first rendered sheet frame
- tap/open intent to comments success, empty state, or failure
- count loaded
- whether video replies were enabled
- whether the user dismissed before data loaded

## Firebase Console Checks

Use Firebase Analytics events to inspect:

- `surface_load` filtered by `surface_name = comments_sheet`
- `slow_bucket` distribution
- p95/p99 in BigQuery export when available
- app version and platform breakdowns

Use Firebase Performance to inspect:

- network request traces for media/API domains
- custom traces only when the span represents a real user wait

## First Dashboard To Build

Create a Firebase/GA4 exploration or BigQuery query for:

- event name: `surface_load`
- dimension: `surface_name`
- dimension: `slow_bucket`
- dimension: `result`
- metric: event count
- metric: p95/p99 of `total_ms`

First target filter:

```text
surface_name = comments_sheet
```

## Divine Brain Check

Divine Brain is read-only from agent tooling. To make this contract discoverable
there, keep this document and the implementation PR detailed enough for the
GitHub ingest pipeline.

Before changing analytics behavior, search Divine Brain for recent context:

```text
Firebase Analytics mobile screen_view surface_load observability divine-mobile
```

After this PR merges and Brain's hourly ingest has run, verify that Brain can
find this contract by searching:

```text
analytics observability comments_sheet surface_load divine-mobile
```
