# Audio Attribution on All Videos (TikTok-Style)

**Date:** 2026-04-09
**Status:** Draft

## Problem

The audio attribution row (`♪ Sound name · Creator`) only appears on videos that have an explicit `["e", ..., "audio"]` tag — meaning the creator opted into audio reuse and published a separate Kind 1063 audio event. Most videos don't have this tag, so the attribution row never appears.

TikTok shows "Original sound - @creator" on every video. This builds awareness of audio as a feature, makes the feed feel richer, and drives audio reuse adoption.

## Design

### Always show audio attribution

Remove the `if (video.hasAudioReference)` gate. Every video in the feed shows an audio attribution row at the bottom of the overlay.

### Two display modes

**Mode 1 — Explicit audio reference (existing)**
When `video.hasAudioReference == true`:
- Display: `♪ Sound name · Creator` (unchanged)
- On tap: navigate to SoundDetailScreen with "Use Sound" button (unchanged)
- This is the existing flow, no changes needed

**Mode 2 — Original sound (new)**
When `video.hasAudioReference == false`:
- Display: `♪ Original sound - @creator_display_name`
- On tap: navigate to SoundDetailScreen in a "view-only" mode
  - Shows creator info, the source video
  - No "Use Sound" button (audio isn't separately available)
  - Could show a message like "This creator hasn't shared their audio for reuse"

### UI Changes

1. **`video_feed_item.dart`** — Remove the `if (video.hasAudioReference)` condition around `AudioAttributionRow`
2. **`feed_video_overlay.dart`** — Same removal if it has the same gate
3. **`AudioAttributionRow`** — Handle the case where there's no audio event:
   - Instead of returning `SizedBox.shrink()` when `!hasAudioReference`, show "Original sound - @creator"
   - Fetch creator display name from the video's pubkey
   - On tap, navigate to SoundDetailScreen with a synthetic/minimal context (video pubkey, no audio event)
4. **`SoundDetailScreen`** — Add support for "original sound" mode:
   - Accept either an `AudioEvent` or a video pubkey + video reference
   - When no audio event: show creator info, source video, but hide "Use Sound" button
   - Show encouragement text for creators to share their audio

### Data flow

No new Nostr events. No audio extraction. No new network requests beyond what's already needed to display the creator's name (which is already fetched for the video overlay).

The `AudioAttributionRow` widget gets the creator display name from the video's author profile, which is already loaded by the feed.

## Files to modify

| File | Change |
|------|--------|
| `mobile/lib/widgets/video_feed_item/video_feed_item.dart` | Remove `hasAudioReference` gate |
| `mobile/lib/widgets/video_feed_item/feed_video_overlay.dart` | Remove `hasAudioReference` gate (if present) |
| `mobile/lib/widgets/video_feed_item/audio_attribution_row.dart` | Handle no-audio-event case with "Original sound" display |
| `mobile/lib/screens/sound_detail_screen.dart` | Support "original sound" mode (no audio event) |

## Out of scope

- On-demand audio extraction (user taps "Use Sound" on a video without shared audio)
- Auto-extracting audio for all videos at publish time
- Changing the default for "allow audio reuse" toggle
- Audio waveform visualization for original sounds

## Testing

- Widget test: AudioAttributionRow renders "Original sound - @creator" when video has no audio reference
- Widget test: AudioAttributionRow renders sound name when video has audio reference (existing)
- Widget test: SoundDetailScreen hides "Use Sound" when in original-sound mode
- Widget test: Tapping original sound row navigates to SoundDetailScreen
