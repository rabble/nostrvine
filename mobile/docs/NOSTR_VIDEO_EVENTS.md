# Nostr Video Events Schema

This document describes the Nostr event schemas for video-related events as implemented in OpenVine.

## Event Kinds

| Kind | Type | Range | Description |
|------|------|-------|-------------|
| 34236 | Addressable short video | Parameterized replaceable | Primary video content (NIP-71) |
| 34235 | Addressable normal video | Parameterized replaceable | Horizontal/longer videos (NIP-71) |
| 22236 | Video view event | Ephemeral | Analytics for video views |

---

## Kind 34236 - Addressable Short Video

This is the primary video content kind used by OpenVine for short looping videos per NIP-71.

## Event Structure

```
Kind: 34236 (NIP-71 addressable short looping videos)
Content: Video description/caption (optional)
Tags: Array of [tagName, tagValue, ...additionalParams]
```

## Core NIP-71 Tags

### Video Content Tags

| Tag | Format | Description | Required |
|-----|--------|-------------|----------|
| `url` | `["url", "https://..."]` | Direct video URL | Recommended |
| `streaming` | `["streaming", "https://...m3u8", "hls"]` | HLS/DASH streaming URL | Optional |
| `imeta` | `["imeta", "url https://...", "m video/mp4", ...]` | NIP-92 inline metadata with multiple key-value pairs | Recommended |

### Media Metadata Tags

| Tag | Format | Description | Required |
|-----|--------|-------------|----------|
| `title` | `["title", "Video Title"]` | Video title | Recommended |
| `m` | `["m", "video/mp4"]` | MIME type (video/mp4, video/webm, etc.) | Recommended |
| `x` | `["x", "sha256hash"]` | SHA-256 hash of video file | Optional |
| `size` | `["size", "12345678"]` | File size in bytes | Optional |
| `dim` | `["dim", "1080x1920"]` | Video dimensions (width x height) | Optional |
| `duration` | `["duration", "6"]` | Duration in seconds | Recommended |
| `alt` | `["alt", "Description for accessibility"]` | Alt text for accessibility | Optional |

### Thumbnail Tags

| Tag | Format | Description | Required |
|-----|--------|-------------|----------|
| `thumb` | `["thumb", "https://...jpg"]` | Static thumbnail image URL | Recommended |
| `image` | `["image", "https://...jpg"]` | Alternative thumbnail tag | Optional |
| `preview` | `["preview", "https://...gif"]` | Animated GIF preview (not used as main thumbnail) | Optional |
| `blurhash` | `["blurhash", "LKO2?U%2Tw=w]~RBVZRi.AaxE1H"]` | Blurhash for progressive loading | Optional |

### Hashtags

| Tag | Format | Description | Required |
|-----|--------|-------------|----------|
| `t` | `["t", "funny"]` | Hashtag (without #) | Optional |

### Event Metadata

| Tag | Format | Description | Required |
|-----|--------|-------------|----------|
| `d` | `["d", "unique-identifier"]` | Replaceable event identifier (required for kind 34236) | **Required** |
| `published_at` | `["published_at", "1234567890"]` | Publication timestamp | Optional |
| `h` | `["h", "group-id"]` | Group/community identifier | Optional |

## OpenVine-Specific Tags

### Original Vine Metrics (for imported vintage vines)

| Tag | Format | Description |
|-----|--------|-------------|
| `vine_id` | `["vine_id", "original-vine-id"]` | Original Vine platform ID |
| `loops` | `["loops", "1000000"]` | Original loop count from Vine |
| `likes` | `["likes", "50000"]` | Original like count from Vine |
| `comments` | `["comments", "1000"]` | Original comment count from Vine |
| `reposts` | `["reposts", "25000"]` | Original repost count from Vine |

## ProofMode Tags (Verification System)

### Verification Level

| Tag | Format | Description |
|-----|--------|-------------|
| `proof-verification-level` | `["proof-verification-level", "verified_mobile"]` | Verification tier: `verified_mobile`, `verified_web`, `basic_proof`, or `unverified` |

### ProofMode Metadata

| Tag | Format | Description |
|-----|--------|-------------|
| `proof-manifest` | `["proof-manifest", "{\"sessionId\":\"...\"}"]` | JSON manifest with frame hashes and session data |
| `proof-device-attestation` | `["proof-device-attestation", "ATTESTATION_TOKEN"]` | Device attestation token from secure hardware |
| `proof-pgp-fingerprint` | `["proof-pgp-fingerprint", "ABCD1234EFGH5678"]` | PGP public key fingerprint for signature verification |

### Verification Levels Explained

- **verified_mobile**: Highest level - includes device attestation + manifest + PGP signature
- **verified_web**: Medium level - includes manifest + PGP signature (no hardware attestation)
- **basic_proof**: Low level - has some proof data but doesn't meet higher criteria
- **unverified**: No ProofMode data present

## NIP-92 imeta Tag Structure

The `imeta` tag provides inline metadata as key-value pairs:

```
["imeta",
  "url https://cdn.example.com/video.mp4",
  "m video/mp4",
  "x sha256hash",
  "size 12345678",
  "dim 1080x1920",
  "duration 6.5",
  "blurhash LKO2...",
  "thumb https://cdn.example.com/thumb.jpg"
]
```

## Tag Processing Order

OpenVine processes tags with the following priorities:

1. **Video URL**: Searches in order: `imeta` → `url` → `streaming` → `r` → content fallback
2. **Thumbnail**: Searches in order: `imeta.thumb` → `imeta.image` → `thumb` → `image` → generated fallback
3. **Metadata**: Direct tags override `imeta` values (first wins)

## URL Validation

Video URLs must match one of these patterns:
- `http://` or `https://`
- File extensions: `.mp4`, `.webm`, `.mov`, `.m4v`, `.avi`, `.mkv`, `.flv`, `.wmv`, `.m3u8`

## Fallback Behavior

### Missing Tags
- **No `d` tag**: Falls back to event ID
- **No `title`**: Uses empty string
- **No thumbnail**: Generates thumbnail URL via API service
- **No duration**: Displays as unknown

### Invalid URLs
- Automatically fixes `apt.openvine.co` → `api.openvine.co` typos
- Accepts URLs in any tag via Postel's Law (be liberal in what you accept)

## Storage

All tags are stored in `VideoEvent.rawTags` as a `Map<String, String>` for:
- ProofMode verification lookups
- Future extensibility
- Debug/analysis purposes

## Example Event

```json
{
  "kind": 34236,
  "content": "Check out this amazing sunset! 🌅 #nature #beautiful",
  "tags": [
    ["d", "sunset-video-2024"],
    ["title", "Beautiful Sunset Timelapse"],
    ["url", "https://cdn.divine.video/videos/sunset.mp4"],
    ["imeta",
      "url https://cdn.divine.video/videos/sunset.mp4",
      "m video/mp4",
      "dim 1080x1920",
      "duration 6",
      "thumb https://cdn.divine.video/thumbs/sunset.jpg",
      "blurhash LKO2?U%2Tw=w]~RBVZRi.AaxE1H"
    ],
    ["t", "nature"],
    ["t", "beautiful"],
    ["proof-verification-level", "verified_mobile"],
    ["proof-manifest", "{\"sessionId\":\"abc123\",\"frameHashes\":[...]}"],
    ["proof-device-attestation", "ATTESTATION_TOKEN_HERE"],
    ["proof-pgp-fingerprint", "ABCD1234EFGH5678"]
  ]
}
```

---

## Kind 22236 - Ephemeral Video View Event

Kind 22236 is an **ephemeral event** for tracking video views for analytics purposes.

### Purpose

These events are published when a user views a video and are consumed by analytics services. As ephemeral events (20000-29999 range per NIP-01), relays keep them in memory only and do not persist them to disk.

The `.content` field is optional and could contain a free-form note.

### Event Range

- **Kind 22236** is in the ephemeral range (20000-29999)
- Relays will NOT store these events permanently
- Multiple events per user+video are expected (one per view session)
- Designed for analytics consumption, not user-facing history

### Tags

| Tag | Format | Description | Required |
|-----|--------|-------------|----------|
| `a` | `["a", "<kind>:<pubkey>:<d-tag>", "<relay-url>"]` | Addressable reference to kind 34235 or 34236 video event | **Required** |
| `e` | `["e", "<event-id>", "<relay-url>"]` | Event ID reference (specific version viewed) | **Required** |
| `viewed` | `["viewed", "<start>", "<end>"]` | Start/end timestamps in seconds (can repeat) | **Required** |
| `source` | `["source", "<source-type>"]` | Traffic source: `home`, `discovery`, `profile`, `share`, `search` | Optional |
| `client` | `["client", "<client-identifier>"]` | Client identifier (e.g., "divine-mobile/1.0") | Optional |

### Traffic Sources

| Source | Description |
|--------|-------------|
| `home` | Video viewed from home/following feed |
| `discovery` | Video viewed from explore/discovery feed |
| `profile` | Video viewed from a user's profile page |
| `share` | Video viewed via shared link |
| `search` | Video viewed from search results |

### Example Event

```json
{
  "id": "<32-bytes lowercase hex-encoded SHA-256 of the serialized event data>",
  "pubkey": "<32-bytes lowercase hex-encoded public key of the viewer>",
  "created_at": <Unix timestamp in seconds>,
  "kind": 22236,
  "content": "",
  "tags": [
    ["a", "34236:<video event author pubkey>:<d-identifier of video event>", "<relay url>"],
    ["e", "<event-id>", "<relay-url>"],
    ["viewed", "0", "6"],
    ["source", "discovery"],
    ["client", "divine-mobile/1.0"]
  ]
}
```

### Notes

- **No `d` tag** - ephemeral events are not addressable/replaceable
- **Both `a` and `e` tags are required** - `a` provides stable addressable reference, `e` tracks specific version viewed
- Multiple `viewed` tags can track multiple segments watched in a single session
- The `viewed` tag timestamps represent seconds within the video (e.g., `["viewed", "0", "6"]` = watched first 6 seconds)
- Analytics services should consume these events in real-time before relays discard them
- Minimum watch threshold: views under 1 second are discarded
- Deduplication: same user+video combination is deduplicated within 1 hour
