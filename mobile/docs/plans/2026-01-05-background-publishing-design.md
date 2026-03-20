Status: Historical

> Historical note
> Preserved for context during the P1 documentation refresh. This file may reference deleted screens, older branding, or superseded implementation details. Start with docs/README.md and docs/archive/README.md for current guidance.

# Background Publishing Design

**Date**: 2026-01-05
**Status**: Approved

## Overview

When user taps Publish on the video metadata screen, navigate back immediately while publishing continues in background. Show notification when done.

## Core Flow

When user taps **Publish**:

1. **Immediate actions** (< 100ms):
   - Save metadata to the existing `PendingUpload` record
   - Mark upload status as `publishing`
   - Pop the entire recording flow (camera → clips → editor → metadata) back to previous screen

2. **Background continues**:
   - If video processing still running → wait for it
   - If upload still running → wait for it
   - Create and broadcast Nostr event
   - Update status to `published`
   - Delete draft, clean up temp files

3. **User feedback**:
   - If app in foreground → show toast "Video published!"
   - If app backgrounded → show local notification "Your video is live"
   - On failure after retries → notification "Publishing failed" + save as draft

## Architecture

**Key change**: Move the Nostr publishing logic from `VideoMetadataScreenPure` into `UploadManager`.

Currently:
```
MetadataScreen._publishVideo() → waits for upload → creates Nostr event → navigates
```

New:
```
MetadataScreen._publishVideo() → saves metadata → triggers background publish → navigates immediately
UploadManager.completePublish() → waits for upload → creates Nostr event → sends notification
```

### Components involved

| Component | Change |
|-----------|--------|
| `UploadManager` | Add `completePublish()` method that handles Nostr event creation |
| `PendingUpload` | Add metadata fields (title, description, hashtags, expiration, allowAudioReuse) |
| `VideoMetadataScreenPure` | Simplify `_publishVideo()` to just save + navigate |
| `NotificationService` | Wire up existing notifications to upload lifecycle |
| App startup | Check for pending publishes, resume them |

## Error Handling & Resume

### Retry behavior (already exists, just wire it up)
- Upload failures: 5 retries with exponential backoff
- Nostr relay failures: 3 retries
- After exhausted: mark as `failed`, save draft, notify user

### App restart resume
- On app startup, `UploadManager.init()` checks Hive for uploads with status `publishing` or `uploading`
- Automatically resumes any incomplete uploads
- User sees nothing unless it fails

### Draft recovery
- Failed uploads stay in Hive with `failed` status
- Existing drafts UI can show these for retry
- No new UI needed

### Notification triggers

| Event | In-app | Push notification |
|-------|--------|-------------------|
| Published successfully | Toast: "Video published!" | "Your video is now live" |
| Failed after retries | Toast: "Publishing failed" | "Couldn't publish video. Saved as draft." |

## App Kill / Crash Recovery

What happens at each stage if the app dies:

**During video processing** (FFmpeg running):
- Temp files may be incomplete
- On restart: processing restarts from original video (still have it)

**During upload to Blossom**:
- Partial upload discarded by server
- On restart: upload restarts (Blossom dedupes by hash, so safe to retry)

**During Nostr event broadcast**:
- Some relays may have received it, some not
- On restart: re-broadcast same event (relays dedupe by event ID, no duplicates)

**After success, before cleanup**:
- Video is live, draft/temp files still exist
- On restart: detect `published` status, just run cleanup

### Key safety
Everything is idempotent. Retrying any step won't create duplicates.

### What we store in Hive (survives app death)
- Original video path
- Processing params (text overlays, audio)
- Upload status
- Metadata (title, hashtags, etc.)
- CDN URL once uploaded

So on restart, we have everything needed to resume from wherever it died.
