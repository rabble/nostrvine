---
name: nostr-rest-api-field-mapping-gap
description: |
  Fix features broken by REST API responses that flatten Nostr events, losing tag data.
  Use when: (1) A feature works for WebSocket-loaded events but not REST API-loaded ones,
  (2) A model field (like sha256, textTrackRef) is null for REST API data but set for
  WebSocket data, (3) REST API returns denormalized fields (d_tag, video_url) but omits
  raw tags array, (4) hasSubtitles/hasFeature returns false for REST-loaded videos.
  Common in Nostr clients that use both REST APIs (for analytics/bulk queries) and
  WebSocket (for real-time events).
author: Claude Code
version: 1.0.0
date: 2026-02-23
---

# Nostr REST API Field Mapping Gap

## Problem

Nostr clients that use both REST APIs and WebSocket connections to load events can
have features that work inconsistently. Features that depend on Nostr tag values
(like the `x` tag for sha256, or custom tags for text tracks) work when events are
loaded via WebSocket (which provides the full raw event with all tags), but break
when the same events are loaded via REST API (which returns flattened/denormalized
JSON without the raw tags array).

## Context / Trigger Conditions

- A feature works for some videos/events but not others (data source dependent)
- A UI element (like a CC button) shows for WebSocket-loaded events but not REST ones
- A model has null fields that should be populated (sha256, textTrackRef, etc.)
- The REST API response has fields like `d_tag`, `video_url`, `title` but NO `tags` array
- The `fromJson()` factory parses tags for values like `x` (sha256), but the REST API
  doesn't include raw tags
- `hasSubtitles`, `hasFeature`, or similar getters return false for REST API data

## Root Cause

REST APIs that index Nostr events typically:
1. Extract commonly-used tag values into dedicated columns (d_tag, title, thumbnail, etc.)
2. Do NOT return the full raw tags array in their response
3. May have semantically equivalent fields under different names

For example, in a Blossom-based video system:
- The Nostr `x` tag contains the SHA256 content hash
- The REST API returns `d_tag` (which for Blossom uploads IS the SHA256) but not `sha256`
- The model's `fromJson()` tries to find `sha256` from direct field or `x` tag, finds neither
- Features that depend on `sha256` (like subtitle fetching) break silently

## Solution

### Step 1: Identify the mapping gap

Compare what the REST API returns vs what the model needs:

```bash
# Fetch a sample REST API response
curl -s "https://your-api.example.com/api/videos?limit=1" | jq '.[0] | keys'
```

Check which model fields are null after parsing:
- Look at the `fromJson()` factory method
- Identify fields populated from tag parsing (tags array) that won't exist in REST response
- Check if any REST API fields are semantically equivalent but differently named

### Step 2: Add fallback mappings

In the model's `fromJson()`, add fallback logic AFTER the primary parsing:

```dart
// Primary: try direct field and tags
var sha256 = eventData['sha256']?.toString() ?? json['sha256']?.toString();

// Parse from tags if available
if (eventData['tags'] is List) {
  // ... tag parsing for 'x' tag ...
}

// Normalize
if (sha256 != null && sha256.isEmpty) sha256 = null;

// FALLBACK: Use semantically equivalent field from REST API
// For Blossom uploads, d_tag IS the content hash (64 hex chars)
if (sha256 == null && dTag.length == 64 && _isHex(dTag)) {
  sha256 = dTag;
}
```

### Step 3: Validate the fallback is safe

Ensure the fallback only triggers when appropriate:
- Check format/length (SHA256 = 64 hex chars)
- Don't override explicitly-set values
- Handle edge cases (classic imports where d_tag is NOT a hash)

### Step 4: Add tests

```dart
test('falls back to d_tag as sha256 when d_tag is 64-char hex', () {
  final json = {
    'd_tag': 'a04b70820ef370e90aae19d23e46b1482d3af0e7c9d994d1594a1384a62d3972',
    // No sha256 field, no tags array (REST API response)
    ...otherFields,
  };
  final model = Model.fromJson(json);
  expect(model.sha256, equals(json['d_tag']));
});

test('does not use d_tag as sha256 when d_tag is not a hex hash', () {
  final json = {'d_tag': 'my-video-slug', ...otherFields};
  final model = Model.fromJson(json);
  expect(model.sha256, isNull);
});

test('does not override explicit sha256 with d_tag', () {
  final json = {
    'd_tag': 'a04b708...', // 64 hex
    'sha256': 'explicit-value',
    ...otherFields,
  };
  final model = Model.fromJson(json);
  expect(model.sha256, equals('explicit-value'));
});
```

## Verification

1. Load the app and navigate to a feed that uses the REST API (e.g., trending/discovery)
2. Verify the feature works (e.g., CC button shows AND subtitles display when toggled)
3. Also verify WebSocket-loaded events still work (e.g., home feed from followed users)
4. Check that non-hash d_tags (classic imports, custom slugs) don't get false positives

## Debugging Approach

When a feature works inconsistently across events:

1. **Identify data source**: Is the broken event from REST API or WebSocket?
2. **Compare raw data**: Fetch the same event from both sources, diff the fields
3. **Trace the pipeline**: `API response -> fromJson() -> model -> getter -> UI condition`
4. **Check conditional guards**: Look for `if (model.hasX)` or `if (field != null)` in UI
5. **Log at the model level**: Add temporary logging in `fromJson()` to see what's null

## Notes

- This pattern applies to ANY Nostr client that uses both REST and WebSocket data sources
- The REST API may evolve to include more fields over time, so the fallback approach
  is forward-compatible (explicit fields take priority over fallbacks)
- Consider requesting the REST API team add the missing fields directly
- The `_isHex()` validation prevents false positives from non-hash d_tag values
- Similar gaps may exist for other tag-derived fields (textTrackRef, duration, etc.)

## Related Skills

- `rest-api-optimistic-update-race-condition` - Another REST API data consistency issue
- `nostr-addressable-event-d-tag-requirement` - Related d_tag handling
