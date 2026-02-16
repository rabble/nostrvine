# Funnelcake Backend Requirements: Subtitle Support

> **Audience**: Funnelcake relay/API developers.
> **Purpose**: The divine-mobile client has full subtitle support built (generation, storage, display), but the funnelcake REST API doesn't return subtitle data yet. This document specifies exactly what the backend needs to do so subtitles "just work" over the REST API fast path.

---

## Background: How Subtitles Work in divine-mobile

### Nostr Data Model

Subtitles are stored as **Kind 39307 addressable events** (per NIP-71 `text-track` convention):

```json
{
  "kind": 39307,
  "pubkey": "<user-pubkey>",
  "tags": [
    ["d", "subtitles:<video-d-tag>"],
    ["L", "ISO-639-1"],
    ["l", "en", "ISO-639-1"],
    ["a", "34236:<user-pubkey>:<video-d-tag>"]
  ],
  "content": "WEBVTT\n\n00:00:00.000 --> 00:00:02.500\nHello world\n\n00:00:03.000 --> 00:00:05.500\nThis is a test\n"
}
```

The **video event** (Kind 34236) references its subtitle track via a `text-track` tag:

```json
["text-track", "39307:<pubkey>:subtitles:<video-d-tag>", "wss://relay.divine.video", "captions", "en"]
```

### Client Dual-Fetch Strategy

The client (`subtitleCuesProvider`) uses two paths, in priority order:

1. **Fast path** -- If the REST API response includes `text_track_content` (the raw VTT string), parse it client-side immediately. **Zero additional network cost.**
2. **Slow path** -- If only `text_track_ref` is available (the addressable coordinates string like `39307:<pubkey>:subtitles:<d-tag>`), the client queries the relay via WebSocket for the Kind 39307 event and parses its `.content` field.

**The fast path is what we want the funnelcake API to enable.** The slow path already works today via relay queries.

---

## What Funnelcake Needs To Do

### 1. Index Kind 39307 Events

Funnelcake should index Kind 39307 events that arrive on the relay. Key fields to extract:

| Field | Source | Description |
|-------|--------|-------------|
| `kind` | `event.kind` | Always `39307` |
| `pubkey` | `event.pubkey` | Author of the subtitle |
| `d_tag` | `event.tags["d"]` | Format: `subtitles:<video-d-tag>` |
| `content` | `event.content` | Raw WebVTT string |
| `language` | `event.tags["l"]` where namespace = `ISO-639-1` | Language code, e.g. `en` |
| `video_ref` | `event.tags["a"]` | Addressable coords of the parent video: `34236:<pubkey>:<video-d-tag>` |

Being addressable events, newer events with the same `(kind, pubkey, d_tag)` tuple replace older ones (standard NIP-33 deduplication).

### 2. Parse `text-track` Tags on Kind 34236 Events

When indexing video events (Kind 34236), extract the `text-track` tag:

```
["text-track", "<coordinates-or-url>", "<relay-hint>", "<type>", "<lang>"]
```

Store:
- `text_track_ref`: The second element (addressable coordinates string, e.g. `39307:<pubkey>:subtitles:<d-tag>`)
- `text_track_lang`: The fifth element (language code, e.g. `en`)

### 3. Return Subtitle Data in REST API Responses

#### Option A: Embed VTT Content (Recommended -- Enables Fast Path)

When the `/api/videos` endpoint returns video data, look up the referenced Kind 39307 event and embed its VTT content directly. This is the **optimal approach** because it eliminates relay round-trips for subtitle display.

Add two new fields to the video response JSON:

```json
{
  "event": {
    "id": "...",
    "pubkey": "...",
    "kind": 34236,
    "tags": ["..."],
    "content": "...",
    "created_at": 1700000000
  },
  "stats": {
    "reactions": 42,
    "comments": 5,
    "reposts": 3,
    "engagement_score": 150
  },
  "text_track_ref": "39307:aaaa...aaaa:subtitles:my-vine-id",
  "text_track_content": "WEBVTT\n\n00:00:00.000 --> 00:00:02.500\nHello world\n\n00:00:03.000 --> 00:00:05.500\nThis is a test\n"
}
```

| New Field | Type | Description |
|-----------|------|-------------|
| `text_track_ref` | `string \| null` | Addressable coordinates from the `text-track` tag on the video event. `null` if no subtitles. |
| `text_track_content` | `string \| null` | Raw WebVTT content from the Kind 39307 event's `.content`. `null` if subtitle event not found or no subtitles. |

**Lookup logic**:
1. From the video's `text-track` tag, extract the coordinates: `39307:<pubkey>:subtitles:<d-tag>`
2. Query the local ClickHouse store for the Kind 39307 event matching `(kind=39307, pubkey=<pubkey>, d_tag=subtitles:<d-tag>)`
3. Return its `.content` as `text_track_content`

#### Option B: Return Only the Reference (Minimum Viable)

If embedding VTT content is too complex initially, just returning `text_track_ref` still helps -- the client will fall back to the relay query (slow path):

```json
{
  "event": { "..." : "..." },
  "stats": { "..." : "..." },
  "text_track_ref": "39307:aaaa...aaaa:subtitles:my-vine-id"
}
```

This is lower effort but means every subtitle display incurs a relay WebSocket query.

### 4. Affected Endpoints

All endpoints that return video data should include subtitle fields:

| Endpoint | Description |
|----------|-------------|
| `GET /api/videos` | Discovery/trending/recent feeds |
| `GET /api/videos/:id/stats` | Individual video stats |
| `GET /api/users/:pubkey/videos` | User's published videos |
| `GET /api/users/:pubkey/feed` | User's personalized feed |
| `GET /api/search` | Video search results |
| `GET /api/videos?tag=...` | Hashtag-filtered videos |
| `GET /api/videos?classic=true` | Classic Vine videos |
| `GET /api/users/:pubkey/recommendations` | Recommended videos |
| `GET /api/videos/stats/bulk` | Bulk stats lookup |

---

## Client-Side Integration (Already Built)

The divine-mobile client changes needed to consume the new fields are minimal and already planned:

**File**: `lib/services/analytics_api_service.dart`

1. Add `textTrackRef` and `textTrackContent` fields to `VideoStats` class
2. Parse them in `VideoStats.fromJson()`:
   ```
   text_track_ref: json['text_track_ref'] or from event tags
   text_track_content: json['text_track_content']
   ```
3. Pass them through in `VideoStats.toVideoEvent()`:
   ```
   textTrackRef: textTrackRef,
   textTrackContent: textTrackContent,
   ```

The `subtitleCuesProvider` already handles both `textTrackContent` (fast path) and `textTrackRef` (slow path) -- no changes needed there.

---

## Testing Checklist for Backend

- [ ] Kind 39307 events are indexed when published to the relay
- [ ] `text-track` tags on Kind 34236 events are parsed and stored
- [ ] `/api/videos` responses include `text_track_ref` when a video has subtitles
- [ ] `/api/videos` responses include `text_track_content` with valid VTT when subtitle event exists
- [ ] Both fields are `null` when a video has no subtitles (not omitted -- explicitly null)
- [ ] Addressable event replacement works: re-publishing a Kind 39307 with same d-tag updates the stored VTT
- [ ] Bulk endpoints (`/api/videos/stats/bulk`) also include subtitle fields
- [ ] VTT content is returned as-is (no transformation/escaping beyond standard JSON string escaping)

---

## Example: Full Flow

1. User records video -> publishes Kind 34236 event (no subtitles yet)
2. User taps "Generate Subtitles" -> client runs Whisper locally -> publishes Kind 39307 event with VTT content
3. Client republishes Kind 34236 with new `text-track` tag referencing the Kind 39307 event
4. Funnelcake indexes both events
5. Next time any client fetches this video via REST API -> response includes `text_track_ref` + `text_track_content`
6. Client parses VTT directly from response (fast path) -> subtitles display immediately, no relay query needed
