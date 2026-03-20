Status: Historical

> Historical note
> Preserved for context during the P1 documentation refresh. This file may reference deleted screens, older branding, or superseded implementation details. Start with docs/README.md and docs/archive/README.md for current guidance.

# Video Audio Mute Feature Design

**Date:** 2025-11-15
**Status:** Approved
**Author:** Claude (via brainstorming skill)

## Overview

Add ability for users to mute audio from videos in the publishing screen. Supports both privacy (removing background conversations) and creative (preparing for music overlay) use cases.

## User Experience

1. User records video with audio (normal flow)
2. In VideoMetadataScreenPure (publishing screen), user sees "Mute Audio" toggle
3. Toggle mute → FFmpeg strips audio track → preview updates with muted video
4. Toggle unmute → switches back to original with audio (no re-processing)
5. User can toggle multiple times before publishing
6. No visual indicator in feed (viewer just hears silence if muted)

## Architecture

### Approach: Process-on-Toggle (Option A2)

- Video is concatenated/processed during recording as normal
- When user toggles audio mute in metadata screen, FFmpeg re-processes video
- Creates new file for muted version, keeps original for unmuting
- Upload manager uploads whichever file is current in draft

**Why this approach:**
- User can preview muted result before publishing
- Can toggle multiple times without quality loss (always processes from original)
- Upload pipeline doesn't need to know about audio processing
- Simpler than recording-time configuration (irreversible)

### Data Model

```dart
class VineDraft {
  final File videoFile;              // Current file (original or processed)
  final File? originalVideoFile;     // Original with audio (null if videoFile is original)
  final bool muteAudio;              // Whether current file has audio muted

  // Factory creates draft with videoFile as original
  factory VineDraft.create({
    required File videoFile,
    bool muteAudio = false,  // Default: keep audio
  }) {
    return VineDraft(
      videoFile: videoFile,
      originalVideoFile: null,  // videoFile IS the original initially
      muteAudio: muteAudio,
    );
  }
}
```

**State transitions:**
- Initial: `videoFile = original.mp4, originalVideoFile = null, muteAudio = false`
- After mute: `videoFile = muted_123.mp4, originalVideoFile = original.mp4, muteAudio = true`
- After unmute: `videoFile = original.mp4, originalVideoFile = null, muteAudio = false`

### UI Component

**Location:** VideoMetadataScreenPure (after expiring post toggle, ~line 650)

```dart
SwitchListTile(
  title: const Text('Mute Audio'),
  subtitle: _isProcessingAudio
      ? Row(children: [CircularProgressIndicator(), Text('Processing video...')])
      : Text(_muteAudio ? 'Video has no sound' : 'Video includes recorded audio'),
  value: _muteAudio,
  onChanged: _isProcessingAudio ? null : (value) async {
    await _handleAudioToggle(value);
  },
)
```

**Processing flow:**
1. User toggles → disable toggle (show spinner)
2. Cancel background upload if in progress
3. Process video with FFmpeg
4. Update draft with new file + muteAudio flag
5. Reinitialize video preview with new file
6. Restart background upload
7. Re-enable toggle

### FFmpeg Processing

**Muting (strip audio):**
```bash
ffmpeg -i "original.mp4" -c:v copy -an "muted_123.mp4"
```
- `-c:v copy`: Stream copy video (no re-encoding, fast)
- `-an`: Remove audio track entirely

**Unmuting (restore original):**
- No FFmpeg needed - just switch `videoFile` back to `originalVideoFile`
- Delete the muted processed file

### File Management

**File lifecycle:**
1. **Recording:** Creates `original.mp4` (with audio)
2. **First mute:** Creates `muted_123.mp4`, keeps `original.mp4`
3. **Unmute:** Deletes `muted_123.mp4`, uses `original.mp4`
4. **Second mute:** Creates `muted_456.mp4`, deletes old `muted_123.mp4` (if exists)
5. **Draft deletion/publish:** Deletes both current file and original (if separate)

**Cleanup rules:**
- Original file: Never delete until draft is deleted/published
- Processed file: Delete when creating new processed file or unmuting
- Safe deletion: Log errors but don't throw (disk leak better than blocking user)

## Error Handling

| Scenario | Handling |
|----------|----------|
| FFmpeg fails | Show error snackbar, keep previous state, re-enable toggle |
| Processed file missing | Throw exception, show error, keep previous state |
| Background upload in progress | Cancel upload before processing, restart after |
| User toggles during processing | Disabled via `_isProcessingAudio` flag |
| Unmute but no original | Throw exception (shouldn't happen, defensive check) |

## Implementation Tasks

### 1. Data Model (VineDraft)
- [ ] Add `muteAudio: bool` field (required)
- [ ] Add `originalVideoFile: File?` field
- [ ] Update `VineDraft.create()` factory
- [ ] Update `copyWith()` with `videoFile` and `originalVideoFile` parameters
- [ ] Update `toJson()` / `fromJson()` serialization
- [ ] Handle sentinel value for nullable `originalVideoFile` in copyWith

### 2. VideoMetadataScreenPure UI
- [ ] Add `_muteAudio` and `_isProcessingAudio` state variables
- [ ] Load `muteAudio` from draft in `_loadDraft()`
- [ ] Add SwitchListTile after expiring post toggle
- [ ] Implement `_handleAudioToggle()` method
- [ ] Implement `_processVideoAudio()` FFmpeg wrapper
- [ ] Implement `_safeDeleteFile()` helper
- [ ] Cancel/restart background upload around processing
- [ ] Reinitialize video preview after processing
- [ ] Add error handling with SnackBar feedback

### 3. File Cleanup
- [ ] Update draft deletion to clean up both videoFile and originalVideoFile
- [ ] Verify DraftStorageService handles file cleanup properly

### 4. Testing
- [ ] Test mute → unmute → mute cycle (multiple toggles)
- [ ] Test FFmpeg failure handling
- [ ] Test background upload cancellation/restart
- [ ] Test draft deletion cleans up all files
- [ ] Test large video files (processing time)
- [ ] Test video preview reload (no flicker/crashes)

## Open Questions

None - design approved for implementation.

## Success Criteria

- [ ] User can toggle audio mute in VideoMetadataScreenPure
- [ ] Toggle shows processing indicator while FFmpeg runs
- [ ] Multiple toggles work without quality loss
- [ ] Unmuting restores original audio perfectly
- [ ] Old processed files are cleaned up (no disk leak)
- [ ] Background upload restarts with new file after toggle
- [ ] Errors are handled gracefully with user feedback
- [ ] Draft deletion cleans up all video files

## FFmpeg Command Reference

**Mute (strip audio):**
```bash
ffmpeg -i "input.mp4" -c:v copy -an "output_muted.mp4"
```

**Key flags:**
- `-i "input.mp4"`: Input file
- `-c:v copy`: Copy video stream (no re-encoding)
- `-an`: No audio stream
- `"output_muted.mp4"`: Output file

**Fallback if stream copy fails:**
```bash
ffmpeg -i "input.mp4" -c:v libx264 -preset ultrafast -an "output_muted.mp4"
```
