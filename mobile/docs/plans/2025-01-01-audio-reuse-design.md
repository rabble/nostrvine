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

## Future Considerations

- Curated/licensed audio library (deals with artists)
- Audio search by waveform matching
- Audio categories/genres
- Audio playlists
- Collaborative audio (multiple creators)
