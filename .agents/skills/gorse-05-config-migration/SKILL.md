---
name: gorse-05-config-migration
description: |
  Fix Gorse 0.5.x recommendation engine silently disabled or degraded due to config incompatibility
  with 0.4. Use when: (1) Gorse 0.5 recommendations are poor/empty despite having data, (2) collaborative
  filtering appears disabled even though [recommend.collaborative] section exists, (3) migrating Gorse
  config from 0.4 to 0.5, (4) old config keys like [recommend.popular], [recommend.neighbors],
  [recommend.online], [recommend.offline] are being used with Gorse 0.5. Critical: type="mf" must be
  explicitly set in [recommend.collaborative] or CF is silently disabled (default "none").
author: Claude Code
version: 1.0.0
date: 2026-02-28
---

# Gorse 0.5.x Config Migration from 0.4

## Problem

Gorse 0.5 introduced breaking config changes from 0.4. Old config sections are silently ignored
(no error, no warning), making it appear that features like collaborative filtering, trending,
and item neighbors are configured when they're actually disabled.

The most critical issue: `[recommend.collaborative]` defaults to `type = "none"` in 0.5, meaning
collaborative filtering is **silently disabled** unless you explicitly set `type = "mf"`.

## Context / Trigger Conditions

- Gorse 0.5.x is deployed but recommendations seem random or low quality
- Collaborative filtering doesn't seem to work despite config having `[recommend.collaborative]`
- Config has old 0.4 sections: `[recommend.popular]`, `[recommend.neighbors]`, `[recommend.online]`, `[recommend.offline]`
- Upgrading from Gorse 0.4 to 0.5
- Gorse master starts successfully but old config features don't take effect

## Solution

### Removed 0.4 Sections (silently ignored in 0.5)

| 0.4 Section | 0.5 Replacement |
|---|---|
| `[recommend.popular]` | `[[recommend.non-personalized]]` (TOML array of tables) |
| `[recommend.neighbors]` | `[[recommend.item-to-item]]` + `[[recommend.user-to-user]]` |
| `[recommend.online]` (explore/exploit) | `[recommend.ranker]` (FM or LLM-based) |
| `[recommend.offline]` | `[recommend.ranker]` cache_expire + `[recommend.fallback]` |

### Removed 0.4 Keys (do not exist in 0.5)

- `enable_item_neighbor_index`
- `enable_user_neighbor_index`
- `item_neighbor_type`
- `neighbor_type`
- `explore_recommend`
- `popular_window`

### Critical Fix: Enable Collaborative Filtering

```toml
# 0.4 style (BROKEN in 0.5 — CF silently disabled):
[recommend.collaborative]
fit_period = "60m"
fit_epoch = 100

# 0.5 style (WORKING — must add type = "mf"):
[recommend.collaborative]
type = "mf"
fit_period = "60m"
fit_epoch = 100
```

### Complete 0.5 Config Template

```toml
[recommend]
cache_size = 100
cache_expire = "72h"
context_size = 100

[recommend.data_source]
positive_feedback_types = ["reaction", "comment", "repost"]
read_feedback_types = ["view"]
positive_feedback_ttl = 0
item_ttl = 0

# Collaborative filtering — MUST set type = "mf" to enable
[recommend.collaborative]
type = "mf"
fit_period = "60m"
fit_epoch = 100
optimize_period = "360m"
optimize_trials = 10

[recommend.collaborative.early_stopping]
patience = 10

# Trending/popular — TOML array syntax [[...]] for multiple leaderboards
[[recommend.non-personalized]]
name = "trending_weekly"
score = "count(feedback, .FeedbackType == 'reaction') + count(feedback, .FeedbackType == 'comment') * 2"
filter = "(now() - item.Timestamp).Hours() < 168"

# Content-based item similarity (requires items to have Labels)
[[recommend.item-to-item]]
name = "similar_content"
type = "tags"         # matches on item Labels

# Collaborative item similarity
[[recommend.item-to-item]]
name = "also_liked"
type = "users"        # users who liked X also liked Y

# User similarity
[[recommend.user-to-user]]
name = "similar_users"
type = "items"        # users who share liked items

# FM ranker blends all candidate sources
[recommend.ranker]
type = "fm"           # or "llm" for LLM-based reranking
recommenders = ["latest", "collaborative", "non-personalized/trending_weekly", "item-to-item/similar_content", "item-to-item/also_liked", "user-to-user/similar_users"]
fit_period = "60m"
fit_epoch = 100

[recommend.ranker.early_stopping]
patience = 10

[recommend.fallback]
recommenders = ["latest"]

[recommend.replacement]
enable_replacement = true
positive_replacement_decay = 0.8
read_replacement_decay = 0.6
```

### Key 0.5 Config Differences

1. **`[[recommend.non-personalized]]`** uses Expr language for score/filter functions
   - Available: `count(feedback, .FeedbackType == 'X')`, `item.Timestamp`, `now()`
   - Filter: `(now() - item.Timestamp).Hours() < N`

2. **`[[recommend.item-to-item]]`** types: `"tags"` (label similarity), `"users"` (collaborative), `"embedding"`

3. **`[[recommend.user-to-user]]`** types: `"items"` (shared items), `"tags"`, `"embedding"`

4. **`[recommend.ranker]`** types: `"none"`, `"fm"` (factorization machines), `"llm"`
   - `recommenders` list uses `"category/name"` format to reference specific recommenders

5. **Custom feedback types**: Any string is valid in `positive_feedback_types` (e.g., `"extended_view"`, `"bookmark"`)

## Verification

After updating the config:
1. Restart Gorse master and check logs for config parse errors
2. Visit Gorse dashboard (port 8088) — new recommenders should appear
3. Check `/api/dashboard/config` endpoint to verify config was accepted
4. After fit_period (default 60m), verify model training runs in worker logs

## Notes

- Gorse 0.5 does NOT warn about unrecognized config keys — they're silently ignored
- The `[[double.bracket]]` syntax is TOML array of tables — allows multiple entries
- The `[single.bracket]` syntax is a regular table — only one allowed
- `[recommend.ranker].recommenders` must reference recommenders by their `"category/name"` path
- Custom feedback types are supported — Gorse doesn't validate feedback type names

## References

- Gorse 0.5 config template: https://github.com/gorse-io/gorse (master branch config)
- Gorse documentation: https://gorse.io/docs/config
