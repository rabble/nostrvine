Status: Historical

> Historical note
> Preserved for context during the P1 documentation refresh. This file may reference deleted screens, older branding, or superseded implementation details. Start with docs/README.md and docs/archive/README.md for current guidance.

# Background Upload Design

**Date**: 2025-11-08
**Status**: Approved
**Author**: AI Assistant (via brainstorming skill)

## Problem Statement

Currently, video upload starts only when the user presses the "Publish" button on the metadata screen. This makes the app feel slow because:
- User must wait for entire upload to complete before publishing
- Upload time is wasted opportunity (user could be editing metadata simultaneously)
- No feedback that upload is happening in background

**Goal**: Start upload immediately when metadata screen loads, complete it in background while user edits title/hashtags, making the app feel faster.

## Design Decisions

### 1. Upload Timing
**Decision**: Start upload immediately in `initState()` of `VideoMetadataScreenPure`

**Rationale**: Maximizes background upload time. By the time user finishes editing metadata, upload is likely complete.

### 2. Publish Button Behavior (Upload in Progress)
**Decision**: Blocking dialog with progress bar

**UX Flow**:
1. User presses "Publish" while upload is at 50%
2. Dialog appears: "Uploading video... 50%" with progress bar
3. User cannot dismiss dialog (must wait)
4. Upload completes → dialog auto-closes
5. Nostr event created with metadata + URL
6. Navigate to home feed

**Code Pattern**:
```dart
Future<void> _publishVideo() async {
  final upload = uploadManager.getUpload(_backgroundUploadId!);

  if (upload.status == UploadStatus.uploading ||
      upload.status == UploadStatus.processing) {
    // Show blocking progress dialog
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => UploadProgressDialog(uploadId: _backgroundUploadId!),
    );
  }

  // Proceed with Nostr event creation
  final published = await videoEventPublisher.publishDirectUpload(upload);
}
```

### 3. Cancellation Behavior
**Decision**: Navigating back cancels upload, keeps draft saved

**Rationale**:
- Draft represents user's recording effort → preserve it
- Upload is network operation → safe to cancel
- User can resume from drafts screen later

**Implementation**: `dispose()` calls `uploadManager.cancelUpload(_backgroundUploadId)`

### 4. Upload Failure Handling
**Decision**: Show error dialog with retry option when publish pressed

**UX Flow**:
1. Upload fails in background (network error)
2. Status becomes `UploadStatus.failed`
3. User presses "Publish"
4. Error dialog: "Upload failed: [reason]. Retry?"
5. User chooses:
   - Retry → restart upload, show progress dialog
   - Cancel → return to metadata screen

## Architecture

### State Management

**New State Variables** (added to `_VideoMetadataScreenPureState`):
```dart
String? _backgroundUploadId;        // Track upload across widget lifecycle
UploadStatus? _uploadStatus;        // Cache status for UI updates
StreamSubscription? _uploadProgressListener;  // Listen to progress events
```

### Component Changes

**VideoMetadataScreenPure**:
- `initState()`: Start background upload via `_startBackgroundUpload()`
- `dispose()`: Cancel upload via `_cancelBackgroundUpload()`
- `_publishVideo()`: Check upload status, wait if needed, then publish Nostr event

**UploadManager** (enhancement if needed):
- Add `cancelUpload(String id)` method to abort in-progress uploads

### Data Flow

#### Happy Path (User Publishes)
```
1. Screen loads
   ↓
2. initState() → _startBackgroundUpload()
   ↓
3. UploadManager.startUpload() returns uploadId
   ↓
4. Background: Upload progresses (pending → uploading → processing → readyToPublish)
   Foreground: User edits title/hashtags
   ↓
5. User presses "Publish" button
   ↓
6. _publishVideo() checks upload status:
   - If readyToPublish → immediately create Nostr event
   - If uploading → show progress dialog, wait for completion
   - If failed → show error dialog, offer retry
   ↓
7. VideoEventPublisher.publishDirectUpload() creates event
   ↓
8. Navigate to home feed
```

#### Cancellation Path (User Navigates Back)
```
1. Screen loads → upload starts
   ↓
2. Upload is in progress (uploading)
   ↓
3. User presses back button
   ↓
4. dispose() → _cancelBackgroundUpload()
   ↓
5. UploadManager.cancelUpload(id)
   ↓
6. Temp upload artifacts cleaned up
   ↓
7. Draft remains saved (not deleted)
   ↓
8. Return to previous screen
```

#### Failure Path (Upload Fails)
```
1. Upload starts in background
   ↓
2. Network error / Cloudinary error
   ↓
3. Status → UploadStatus.failed
   ↓
4. User presses "Publish"
   ↓
5. Check status → show error dialog
   ↓
6. User chooses:
   - Retry → _retryUpload() → show progress dialog
   - Cancel → stay on metadata screen
```

## Error Handling

### Edge Cases

| Scenario | Behavior |
|----------|----------|
| Upload in progress when publish pressed | Show blocking progress dialog, wait for completion |
| Upload failed | Show error dialog with retry option |
| Network loss during upload | UploadManager handles retries (uses `UploadStatus.retrying`) |
| User navigates back mid-upload | Cancel upload, keep draft saved |
| App killed mid-upload | On restart, orphaned uploads ignored (no auto-resume) |

### UI States

```dart
enum PublishButtonState {
  uploading,        // Show progress dialog when pressed
  readyToPublish,   // Immediately publish Nostr event
  uploadFailed,     // Show error dialog with retry option
}
```

## Testing Strategy

### Unit Tests (`test/screens/video_metadata_screen_test.dart`)
- ✅ `initState()` starts background upload immediately
- ✅ `dispose()` cancels upload if still in progress
- ✅ Publish button waits for upload completion
- ✅ Upload failure shows error dialog with retry option
- ✅ Navigation cancels upload without deleting draft
- ✅ Draft remains accessible from drafts screen after cancellation

### Integration Tests (`test/integration/background_upload_flow_test.dart`)
- ✅ Full flow: Screen load → upload → edit metadata → publish → Nostr event created
- ✅ Cancellation flow: Screen load → upload starts → navigate back → upload cancelled
- ✅ Retry flow: Upload fails → user retries → success → publish
- ✅ Early publish: User presses publish at 50% upload → dialog shows → completes → publishes

### Widget Tests (`test/widgets/video_metadata_screen_widget_test.dart`)
- ✅ Progress dialog appears when publish pressed during upload
- ✅ Error dialog appears on upload failure
- ✅ Retry button in error dialog restarts upload

## Implementation Plan

See `docs/plans/2025-11-08-background-upload-implementation.md` for detailed TDD implementation steps (to be created in Phase 6).

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| User closes app mid-upload | Accept data loss (no auto-resume). User can retry from drafts. |
| Upload completes but screen disposed | Check `mounted` before UI updates. |
| Multiple rapid navigations (back/forward) | Track upload ID, cancel old uploads in `dispose()`. |
| Memory leak from uncancelled upload | Ensure `dispose()` always cancels subscription and upload. |

## Future Enhancements

- **Auto-retry on network recovery**: Resume upload when network returns
- **Upload queue**: Support multiple simultaneous uploads from drafts screen
- **Offline mode**: Queue uploads for later when network unavailable
- **Upload analytics**: Track success/failure rates, average upload time
