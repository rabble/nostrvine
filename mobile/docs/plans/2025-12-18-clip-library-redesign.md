# Clip Library Redesign

**Date:** 2025-12-18
**Status:** Approved

## Overview

Replace drafts with a persistent clip library. Clips become the primary storage unit - recorded once, saved forever, reusable across multiple videos.

## Problem

Current system auto-creates "drafts" (concatenated videos) that are single-use. If you don't finish the flow, you might lose your recording. Drafts can't be reused or combined with other clips.

## Solution

Every recorded segment is immediately saved as a clip in the library. Users build videos by selecting and combining clips. Clips persist until manually deleted.

## Core Principles

1. **Never lose recorded video** - Segments auto-save immediately
2. **Clips are reusable** - Same clip can be in multiple videos
3. **Simple flow** - Select clips → Edit → Publish (no intermediate draft state)

## Data Model Changes

### SavedClip (modified)

```dart
class SavedClip {
  final String id;
  final String filePath;
  final String? thumbnailPath;
  final Duration duration;
  final DateTime createdAt;
  final String aspectRatio;
  final String? sessionId;  // NEW: groups clips recorded together
}
```

### Migration

- Each existing `VineDraft` becomes a `SavedClip`
- Session ID = `"migrated_{draft.id}"`
- After migration, remove `DraftStorageService` and `VineDraft`

## UI Changes

### Profile Screen
- Rename "Drafts" button to "Clips"
- Count shows clips in library

### Clip Library Screen (replaces Drafts screen)
- Grid view of clips grouped by session/day
- Tap clip → preview
- Long-press or X button → delete
- "Select" mode → pick multiple clips → "Create Video" button
- "Record New" button

### ClipManager Screen
- Starts with clips from current recording session
- "Add from Library" button → opens Clip Library in selection mode
- Shows running total duration
- Can exceed 6.3s - shows warning "Video will be trimmed to 6.3 seconds"
- Auto-trim from end on publish

## Recording Flow

### Current
```
Record → finishRecording() → concatenate → create VineDraft → ClipManager
```

### New
```
Record segment → immediately save as SavedClip → continue or finish
                              ↓
Finish → ClipManager (new clips pre-selected) → Add from library? → Edit → Publish
```

### Changes to VineRecordingProvider
- On segment stop: save to `ClipLibraryService` immediately
- Generate thumbnail immediately
- Track current `sessionId` for grouping
- Remove auto-draft creation
- `finishRecording()` navigates to ClipManager, doesn't concatenate

### Concatenation
- Moves to publish time
- ClipManager orders clips
- "Next" → concatenate selected clips → VideoEditor
- VideoEditor adds text/sound → render → publish

## Publish Flow

```
ClipManager → VideoEditor (text/sound) → Publish
```

- No intermediate draft state
- If app closes mid-edit, clips are safe (edit progress lost, acceptable)
- Clips stay in library after publish (reusable)

## Duration Handling

- Max video duration: 6.3 seconds
- Users CAN add clips totaling > 6.3s
- UI shows warning when over limit
- Auto-trim from end on publish

## Files to Modify

### Remove
- `lib/models/vine_draft.dart`
- `lib/services/draft_storage_service.dart`
- `lib/providers/draft_count_provider.dart`
- `lib/screens/vine_drafts_screen.dart`
- `test/` files for above

### Modify
- `lib/models/saved_clip.dart` - add sessionId
- `lib/services/clip_library_service.dart` - add session grouping
- `lib/providers/vine_recording_provider.dart` - save clips immediately, remove draft creation
- `lib/screens/clip_library_screen.dart` - add selection mode, grouping UI
- `lib/screens/clip_manager_screen.dart` - add "Add from Library", duration warning
- `lib/screens/profile_screen_router.dart` - rename Drafts to Clips
- `lib/router/app_router.dart` - update routes

### Create
- `lib/providers/clip_count_provider.dart` - replaces draft_count_provider
- Migration script/function for existing drafts

## Testing Strategy

All changes follow TDD:
1. Write failing tests first
2. Implement minimal code to pass
3. Refactor

Key test areas:
- SavedClip sessionId grouping
- Auto-save on segment stop
- Clip Library selection mode
- Duration warning/auto-trim logic
- Migration of existing drafts
