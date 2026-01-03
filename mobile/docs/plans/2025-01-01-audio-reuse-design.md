# Audio Reuse Feature Design

## Overview

Enable users to reuse audio from existing videos in their own recordings, similar to TikTok's "Use this sound" feature. Audio becomes a first-class discoverable entity on Nostr.

## Data Model

### Kind 1063 - Audio Event

Published when user opts in to make their audio available for reuse.

```json
{
  "kind": 1063,
  "pubkey": "<creator-pubkey>",
  "content": "",
  "tags": [
    ["url", "https://blossom.example/abc123.aac"],
    ["m", "audio/aac"],
    ["x", "<sha256-hash>"],
    ["size", "98765"],
    ["duration", "6.2"],
    ["title", "Original sound - @username"],
    ["a", "34236:<pubkey>:<vine-id>", "<relay>"]
  ]
}
```

**Fields:**
- `url` - Blossom audio file URL
- `m` - MIME type (audio/aac, audio/mp4)
- `x` - SHA-256 hash of audio file
- `size` - File size in bytes
- `duration` - Length in seconds
- `title` - Auto-generated: video title or "Original sound - @username"
- `a` tag - Addressable reference to source video (Kind 34236)

### Kind 34236 - Video Event (with audio reference)

Videos using external audio include an `e` tag with "audio" marker.

```json
{
  "kind": 34236,
  "tags": [
    ["d", "<vine-id>"],
    ["imeta", "url ...", "m video/mp4", ...],
    ["e", "<audio-1063-event-id>", "<relay>", "audio"],
    // ... other tags
  ]
}
```

### Relationships

- Audio (1063) → Source Video (34236) via `a` tag
- Video (34236) → Audio (1063) via `e` tag with "audio" marker
- Query videos using a sound: `{"kinds": [34236], "#e": ["<audio-id>"]}`

## User Flows

### Publishing with Audio Available

```
1. User records/imports video
2. On publish screen:
   └── Toggle: "Allow others to use this audio"
       (pre-set from global setting in app settings)
3. If toggle ON:
   ├── FFmpeg extracts audio locally → .aac file
   ├── Upload video + audio to Blossom
   ├── Publish Kind 1063 (audio) with `a` tag → source video
   └── Publish Kind 34236 (video) with `e` tag → audio event
4. If toggle OFF:
   └── Upload video only, publish video event (no audio event)
```

### Using Existing Audio - Entry Points

**Path A: From a video**
```
1. User watches video with reusable audio
2. Taps Share menu → "Use this sound"
3. Opens recording screen with audio pre-loaded
```

**Path B: From recording screen**
```
1. User opens recording screen
2. Taps "Add sound" button
3. Opens sounds browser
4. Selects a sound
5. Returns to recording with audio loaded
```

**Path C: From sounds browser**
```
1. User browses Sounds tab
2. Finds a sound, taps "Use this sound"
3. Opens recording screen with audio pre-loaded
```

### Recording with Audio (Lip Sync Mode)

```
┌─────────────────────────────────────────┐
│  No headphones detected                 │
│  ├── Mic: MUTED                         │
│  ├── Audio: plays through speaker       │
│  ├── Visual: waveform + countdown       │
│  └── Output: video + selected audio     │
├─────────────────────────────────────────┤
│  Headphones detected                    │
│  ├── Audio: plays through headphones    │
│  ├── Toggle: "Add your voice" (off)     │
│  │   ├── Off: Mic muted                 │
│  │   │   └── Output: video + audio      │
│  │   └── On: Mic enabled                │
│  │       └── Output: video + audio + voice mixed
│  └── Visual: waveform + countdown       │
└─────────────────────────────────────────┘
```

**Post-recording:**
1. FFmpeg mixes selected audio with video (and voice if enabled)
2. Upload merged video to Blossom
3. Publish Kind 34236 with `e` tag referencing the audio event

## UI Components

### Sounds Browser (New Screen)

```
┌─────────────────────────────┐
│  🔥 Trending Sounds         │
│  ┌─────┐ ┌─────┐ ┌─────┐   │
│  │thumb│ │thumb│ │thumb│ → │  horizontal scroll
│  │ ♪6s │ │ ♪4s │ │ ♪5s │   │  tap to preview
│  └─────┘ └─────┘ └─────┘   │
├─────────────────────────────┤
│  🔍 Search sounds...        │
├─────────────────────────────┤
│  ♪ Original sound - @user1  │
│    6s · 142 videos          │
├─────────────────────────────┤
│  ♪ Cool beat - @user2       │
│    4s · 89 videos           │
└─────────────────────────────┘
```

### Sound Detail Page

```
┌─────────────────────────────┐
│  ♪ Original sound - @user1  │
│  6.2s · 142 videos          │
│  [▶ Preview]  [Use Sound]   │
├─────────────────────────────┤
│  Videos using this sound:   │
│  ┌─────┐ ┌─────┐ ┌─────┐   │
│  │vid 1│ │vid 2│ │vid 3│   │
│  └─────┘ └─────┘ └─────┘   │
└─────────────────────────────┘
```

### Recording Screen with Audio

```
┌─────────────────────────────┐
│  [Camera Preview]           │
│                             │
│  ♪ Sound name    [x remove] │
│  ════════════════ waveform  │
│                             │
│  🎤 Add your voice (toggle) │  ← only with headphones
│                             │
│      [Record Button]        │
└─────────────────────────────┘
```

### Video Attribution Display

```
┌─────────────────────────────┐
│  [Video Player]             │
├─────────────────────────────┤
│  @username                  │
│  Video description #hashtag │
│                             │
│  ♪ Sound name · @creator    │  ← tappable → sound detail
└─────────────────────────────┘
```

### Share Menu Addition

```
┌─────────────────────────────┐
│  Share to...                │
│  Copy link                  │
│  ♪ Use this sound           │  ← new option (if audio available)
│  Report                     │
└─────────────────────────────┘
```

## Settings

**Global Setting:**
- Location: App Settings
- Toggle: "Make my audio available for reuse"
- Default: OFF
- Description: "When enabled, others can use audio from your videos in their own"

**Per-Video Override:**
- Location: Publish screen
- Toggle: "Allow others to use this audio"
- Pre-populated from global setting
- Can override per video

## Implementation Components

### New Files

| File | Purpose |
|------|---------|
| `lib/models/audio_event.dart` | Kind 1063 model, parsing, creation |
| `lib/services/audio_extraction_service.dart` | FFmpeg audio extraction from video |
| `lib/services/audio_playback_service.dart` | Playback during recording, headphone detection |
| `lib/repositories/sounds_repository.dart` | Fetch/cache Kind 1063 events, usage counts |
| `lib/providers/sounds_providers.dart` | Riverpod providers for sounds |
| `lib/screens/sounds_screen.dart` | Sounds browser (trending + list) |
| `lib/screens/sound_detail_screen.dart` | Sound info + videos using it |
| `lib/widgets/sound_tile.dart` | Sound list item widget |
| `lib/widgets/audio_waveform.dart` | Visual waveform during recording |

### Modified Files

| File | Changes |
|------|---------|
| `lib/models/video_event.dart` | Add `audioEventId` getter, parse `e` tag with "audio" marker |
| `lib/services/video_export_service.dart` | Modify to mix external audio + optional voice |
| `lib/services/video_event_publisher.dart` | Publish Kind 1063 when audio sharing enabled, add `e` tag to video |
| `lib/screens/recording_screen.dart` | Add sound button, audio playback, waveform, voice toggle |
| `lib/screens/publish_screen.dart` | Add audio sharing toggle |
| `lib/screens/video_detail_screen.dart` | Show audio attribution, add share menu option |
| `lib/screens/settings_screen.dart` | Add global audio sharing preference |

### Dependencies

| Package | Purpose | Status |
|---------|---------|--------|
| `ffmpeg_kit_flutter` | Audio extraction + mixing | Already have |
| `just_audio` | Audio playback during recording | Already have |
| `audio_session` | Headphone detection | Need to add |

## Queries

**Fetch trending sounds:**
```
{"kinds": [1063], "limit": 20}
+ backend service provides usage counts
```

**Fetch videos using a sound:**
```
{"kinds": [34236], "#e": ["<audio-event-id>"]}
```

**Count videos using a sound (NIP-45):**
```
["COUNT", "<sub-id>", {"kinds": [34236], "#e": ["<audio-event-id>"]}]
```

## Edge Cases & Failure Handling

- **Audio event missing / deleted / unavailable URL**: video still plays normally; attribution row hidden and “Use this sound” disabled.
- **Audio event exists but relay unavailable**: allow opening Sound Detail if the event is cached; otherwise show a non-fatal error and retry.
- **Duplicate audio events**: prefer de-dupe by `x` (sha256) when browsing sounds; if multiple Kind 1063 events share the same `x`, treat them as the same sound entity for list UI.
- **Source video already uses external audio**:
  - Publishing flow should clarify whether “Allow others to use this audio” applies to the video’s *final* mixed audio, or only the creator’s original audio.
  - If it’s the final mixed audio, Kind 1063 `a` tag still points to the video; attribution should indicate both original sound creator and re-poster (future).
- **Recording flow interruptions** (incoming call, app background): audio preview/recording should pause and resume safely; do not publish partial audio events.
- **No headphones**: enforce mic-muted mode (as described) to avoid feedback/echo; explicitly warn user.

## Implementation Notes

### Audio Extraction / Mixing

- Prefer a consistent extracted format for reuse (e.g., AAC LC) to keep playback/mixing predictable across platforms.
- Extraction should be deterministic (same input → same `x` hash) by normalizing:
  - Sample rate (e.g., 44.1kHz)
  - Channels (stereo/mono)
  - Bitrate (fixed)
- Store the extracted audio locally until publish completes; delete on success and on user cancel.

### Sound Identity

- Treat the **sha256 `x`** tag as the primary identity for the “sound” concept in UI.
- The **event id** remains the canonical reference in video events (`e` tag), but browsing and caching should key by `x` to avoid duplicates.

### Caching

- Cache fetched Kind 1063 events locally (by `id` and by `x`).
- Cache usage counts separately with a TTL (e.g., 5–15 minutes), since counts can change rapidly.

## Acceptance Criteria

- User can publish a video with audio reuse enabled and a Kind 1063 event is published and linked to the Kind 34236 video.
- User can tap “Use this sound” from a video that has an audio reference and land on recording with the sound preloaded.
- User can browse sounds, preview a sound, and use it to record.
- Video detail displays sound attribution when a video references an audio event.
- Videos using a sound are queryable by `{"kinds": [34236], "#e": ["<audio-event-id>"]}`.
- Failure states are non-fatal (missing audio event, missing URL, relay issues).

## Open Questions

- Should Kind 1063 be **replaceable/addressable** (has `d` tag) to allow updates (e.g., title edits), or intentionally immutable?
- How should we define “trending” without a centralized backend (pure relay counts vs backend aggregation)?
- For “Use this sound”, do we always reference the **audio event id** in Kind 34236, or can we reference by `x` when the event isn’t available (not recommended unless explicitly decided)?
- Do we want to allow trimming/selecting a segment of a longer audio clip for reuse (not in current scope)?

## Future Considerations

- Curated/licensed audio library (deals with artists)
- Audio search by waveform matching
- Audio categories/genres
- Audio playlists
- Collaborative audio (multiple creators)
