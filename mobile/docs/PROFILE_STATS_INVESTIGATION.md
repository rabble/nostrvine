# Profile Stats Investigation: Missing Likes & Loops

## Problem Statement

The profile screen shows Followers and Following counts correctly, but Likes and Loops always display as "—" (hidden, since we added conditional visibility for null stats). This affects both own-profile and other-user profiles.

---

## Investigation Timeline

### 1. Initial Discovery

The `_ProfileStatsRow` widget displays Likes and Loops using `profileStats?.totalLikes` and `profileStats?.totalViews`. When `profileStats` is null, the columns are hidden.

### 2. Data Flow Analysis

We traced the full chain from API to UI:

```
REST API (/api/users/{pubkey})
  → FunnelcakeApiClient.getUserProfile()
    → ProfileRepository._doFetchFreshProfile()
      → ProfileStatsDao.upsertStats()
        → Drift DB (profile_stats table)
          → ProfileRepository.watchProfileStats()
            → userProfileStatsReactiveProvider (StreamProvider)
              → OtherProfileScreen watches provider
                → ProfileGridView.profileStats
                  → ProfileHeaderWidget._ProfileStatsRow
```

### 3. Five Breaks Identified

#### Break 1: `getUserProfile()` discarded stats from API response

**File:** `packages/funnelcake_api_client/lib/src/funnelcake_api_client.dart`

The `/api/users/{pubkey}` endpoint returns `social`, `stats`, and `engagement` objects alongside `profile`, but `getUserProfile()` only extracted the `profile` fields and discarded everything else.

**Fix applied:** Extended the returned map to include `social`, `stats`, and `engagement` when present.

#### Break 2: No `_cacheProfileStats()` method existed

**File:** `packages/profile_repository/lib/src/profile_repository.dart`

Even if the API returned stats, there was no code to write them to the `ProfileStatsDao`.

**Fix applied:** Added `_cacheProfileStats()` method that extracts:
- `social.follower_count` → `followerCount`
- `social.following_count` → `followingCount`
- `stats.video_count` → `videoCount`
- `engagement.total_reactions` → `totalLikes`
- `engagement.total_loops` → `totalViews` (rounded, since the backend returns fractional values due to a ClickHouse aggregation issue)

Called after every successful REST profile fetch in `_doFetchFreshProfile()`.

#### Break 3: `ProfileStatsDao` not injected into `ProfileRepository`

**File:** `lib/providers/app_providers.dart`

The `ProfileRepository` constructor accepts an optional `profileStatsDao` parameter, but `app_providers.dart` never passed it. This caused `watchProfileStats()` to return `Stream.empty()` — the reactive provider would never emit data.

**Fix applied:** Added `profileStatsDao: ref.watch(databaseProvider).profileStatsDao` to the `ProfileRepository` construction.

#### Break 4: Own-profile path doesn't watch `userProfileStatsReactiveProvider`

**File:** `lib/screens/profile_screen_router.dart`

Unlike `OtherProfileScreen` (which watches `userProfileStatsReactiveProvider` and passes `headerStats` to `ProfileGridView`), the own-profile flow through `ProfileScreenRouter` → `ProfileViewSwitcher` → `ProfileGridView` never watches this provider. The `profileStats` parameter is always null for own profiles.

**Status:** Not fixed on `fix-stats` branch. Deferred to `new-profile` branch integration.

#### Break 5: `_confirmedMissing` permanently blocks profile fetches

**File:** `packages/profile_repository/lib/src/profile_repository.dart`

`fetchFreshProfile()` has an early return: `if (_confirmedMissing.contains(pubkey)) return Future.value()`. This set is populated when the batch profile fetch (during video feed loading) gets a `_noProfile` sentinel from the API. Once a pubkey is in this set, it is **never retried** — even when the user explicitly navigates to that profile.

This was confirmed by debug logging: `confirmedMissing=true` for the test user.

**Fix applied:** Added `_confirmedMissing.remove(pubkey)` at the start of `fetchFreshProfile()` so explicit profile requests always re-check the API.

### 4. Debug Logging Challenge

During investigation, we discovered that `developer.log()` (used throughout `ProfileRepository`) does **not** appear in the `flutter run` console output. Only `print()` and the app's unified `Log.info()` logger show in the terminal. `developer.log()` requires Dart DevTools. This caused confusion when debug logs appeared to be missing — the code was executing but the output was invisible.

### 5. Debug Log Visibility Issue

We added `developer.log()` debug statements to `ProfileRepository` but they never appeared in the `flutter run` console. After investigation, we discovered that `developer.log()` only outputs to Dart DevTools, not the terminal. Switching to `print()` immediately showed the logs. This cost several debug cycles.

### 6. `_confirmedMissing` Blocking Fetches

With `print()` logs, we confirmed `fetchFreshProfile` was being called but `confirmedMissing=true` caused an early return. The user's pubkey was added to `_confirmedMissing` during batch profile fetching on the video feed. The fix (clearing the entry on explicit fetch) allowed `_doFetchFreshProfile` to proceed.

### 7. Break 6: `_noProfile` Sentinel Discards Stats Data

**The critical finding.** Even after fixing all previous breaks, the REST API returned `noProfile=true, hasEngagement=false`.

We verified with `curl` that the production API returns `"profile": null` for this specific user (they have 50+ videos and engagement but never published a Kind 0 Nostr profile event). However, the API still returns valid `social`, `stats`, and `engagement` objects in the same response.

The problem was **two-layered**:

#### 6a. `getUserProfile()` discards stats on `_noProfile` sentinel

**File:** `packages/funnelcake_api_client/lib/src/funnelcake_api_client.dart`

When `profile` is null (no name or display_name), the method returns:
```dart
return {'_noProfile': true, 'pubkey': pubkey};
```
This discards the `social`, `stats`, and `engagement` data that was in the full API response.

**Fix:** Include stats in the sentinel response:
```dart
final sentinel = <String, dynamic>{'_noProfile': true, 'pubkey': pubkey};
if (social != null) sentinel['social'] = social;
if (stats != null) sentinel['stats'] = stats;
if (engagement != null) sentinel['engagement'] = engagement;
return sentinel;
```

#### 6b. `_doFetchFreshProfile()` skips stats caching on `_noProfile`

**File:** `packages/profile_repository/lib/src/profile_repository.dart`

The `_noProfile` branch added the pubkey to `_confirmedMissing` and returned null without calling `_cacheProfileStats()`.

**Fix:** Call `_cacheProfileStats()` before adding to `_confirmedMissing`:
```dart
if (data != null && data['_noProfile'] == true) {
  await _cacheProfileStats(pubkey, data);  // NEW: cache stats even without profile
  _confirmedMissing.add(pubkey);
  return null;
}
```

### 8. Current Status (In Progress)

All six breaks have fixes applied. Awaiting cold-restart verification that:
1. `_doFetchFreshProfile` is reached (confirmed working)
2. The sentinel response includes engagement data (fix applied)
3. `_cacheProfileStats` is called on the `_noProfile` path (fix applied)
4. Stats are written to the Drift DB
5. The `userProfileStatsReactiveProvider` stream emits the new data
6. The UI rebuilds with visible Likes/Loops columns

---

## Production API Response Structure

Verified against production (`https://api.divine.video/api/users/{pubkey}`):

```json
{
  "pubkey": "...",
  "profile": {
    "name": "...", "display_name": "...", "about": "...",
    "picture": "...", "banner": "...", "nip05": "...", "lud16": "..."
  },
  "social": {
    "follower_count": 71,
    "following_count": 29
  },
  "stats": {
    "video_count": 2,
    "reaction_count": 44,
    "comment_count": 4,
    "repost_count": 6
  },
  "engagement": {
    "total_reactions": 6452,    // → maps to Likes
    "total_comments": 768,
    "total_reposts": 0,
    "total_loops": 42.5,        // → maps to Loops (rounded)
    "total_views": 46
  }
}
```

### Field Mapping

| API Field | ProfileStats Field | UI Column |
|-----------|-------------------|-----------|
| `engagement.total_reactions` | `totalLikes` | Likes |
| `engagement.total_loops` | `totalViews` | Loops |
| `social.follower_count` | `followers` | Followers |
| `social.following_count` | `following` | Following |
| `stats.video_count` | `videoCount` | (not displayed) |

Note: `total_loops` is fractional due to a backend ClickHouse aggregation issue. We round to the nearest integer.

Note: `total_views` (unique views) and `total_loops` (loop plays) are different metrics. The "Loops" column shows `total_loops`.

---

## Break 7: Backend Aggregation Bug — `engagement` Numbers Are Unreliable

### Discovery

After fixing all client-side pipeline breaks and successfully displaying stats in the UI, the Likes numbers appeared disproportionately large. A creator with 78 followers and 93 videos was showing 121,139 likes.

### Verification

We compared the `engagement` aggregate with the sum of per-video stats from `/api/users/{pubkey}/videos`:

**User: 963368c4...** (93 videos, 78 followers)

| Metric | Per-video sum (real) | `engagement` aggregate | Factor |
|--------|---------------------|----------------------|--------|
| Reactions (Likes) | **473** | 121,139 | ~256x inflated |
| Loops | **616** | 478 | 0.77x deflated |
| Views | **966** | 719 | 0.74x deflated |

**User: 295dbec7...** (Sebastian, 2 videos)

| Metric | Per-video sum (real) | `engagement` aggregate | Factor |
|--------|---------------------|----------------------|--------|
| Reactions (Likes) | **~9** (from 1 video) | 6,452 | ~700x inflated |

### Conclusion

The `engagement.total_reactions` field returned by `GET /api/users/{pubkey}` is **massively inflated** — likely a ClickHouse aggregation bug (possibly counting duplicates across relays/shards, or a multiplication error in the query). The per-video `reactions` field from `GET /api/users/{pubkey}/videos` is accurate.

`engagement.total_loops` and `engagement.total_views` are also inaccurate but deflated rather than inflated, suggesting a different aggregation issue.

### Impact

We **cannot use `engagement.*` fields** for profile stats until the backend team fixes the aggregation.

### Options Under Consideration

1. **Client-side aggregation**: Fetch all videos via `/api/users/{pubkey}/videos` (paginated) and sum `reactions` and `loops` per video. Accurate but expensive — requires fetching all pages for users with many videos.

2. **Hide Likes and Loops for now**: Revert to showing only Followers and Following until the backend aggregation is fixed. The conditional visibility already handles this (null stats hide the columns).

3. **Use `stats.reaction_count` instead**: This field (120 for the test user) represents reactions *given by* the user, not *received*. Wrong semantics — this is how many times the user liked others' content.

4. **Request backend fix**: Report the issue to the backend team with the evidence above, and wait for a corrected `engagement` endpoint.

---

## Architecture: How It Should Work

```
1. User navigates to a profile screen
2. OtherProfileBloc dispatches OtherProfileLoadRequested
3. ProfileRepository.fetchFreshProfile() is called
4. _confirmedMissing check passes (fix: entry is removed on explicit fetch)
5. FunnelcakeApiClient.getUserProfile() calls GET /api/users/{pubkey}
6. Response includes profile + social + stats + engagement
7. UserProfile.fromFunnelcake() creates the profile model
8. _cacheProfileStats() writes stats to ProfileStatsDao (Drift DB)
9. userProfileStatsReactiveProvider (StreamProvider) emits new ProfileStats
10. OtherProfileScreen rebuilds with headerStats populated
11. ProfileGridView → ProfileHeaderWidget → _ProfileStatsRow renders
    Likes and Loops columns (visible because values are non-null)
```

---

## All Breaks Summary

| # | Break | Root Cause | Fix |
|---|-------|------------|-----|
| 1 | `getUserProfile()` discarded stats | Only extracted `profile` field from API response | Include `social`/`stats`/`engagement` in returned map |
| 2 | No stats caching method | `_cacheProfileStats()` didn't exist | Added method to extract and write stats to `ProfileStatsDao` |
| 3 | `ProfileStatsDao` not injected | `app_providers.dart` didn't pass DAO to `ProfileRepository` | Added `profileStatsDao` parameter |
| 4 | Own-profile doesn't watch stats | `ProfileScreenRouter` chain never watches `userProfileStatsReactiveProvider` | Deferred to `new-profile` branch |
| 5 | `_confirmedMissing` permanently blocks | Batch fetch sentinel permanently skips explicit profile fetches | Clear entry at start of `fetchFreshProfile()` |
| 6a | Sentinel discards stats data | `getUserProfile()` returns `{_noProfile, pubkey}` without stats | Include `social`/`stats`/`engagement` in sentinel |
| 6b | No stats caching on `_noProfile` path | `_doFetchFreshProfile()` skips `_cacheProfileStats()` for sentinel | Call `_cacheProfileStats()` before adding to `_confirmedMissing` |

## Files Modified (fix-stats branch)

| File | Changes |
|------|---------|
| `packages/funnelcake_api_client/lib/src/funnelcake_api_client.dart` | Include stats in both normal and `_noProfile` sentinel returns from `getUserProfile()` |
| `packages/profile_repository/lib/src/profile_repository.dart` | Add `_cacheProfileStats()`, clear `_confirmedMissing` on explicit fetch, cache stats on `_noProfile` path |
| `lib/providers/app_providers.dart` | Inject `profileStatsDao` into `ProfileRepository` constructor |

## Remaining Work

- Verify the full pipeline works end-to-end after Break 6 fixes
- Remove temporary debug statements
- Wire own-profile stats (Break 4) — needs `userProfileStatsReactiveProvider` watched in `ProfileScreenRouter` chain
- Write tests for the new stats caching logic
- Create PR for `fix-stats` branch
