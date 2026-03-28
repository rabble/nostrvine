Status: Historical

> Historical note
> Preserved for context during the P1 documentation refresh. This file may reference deleted screens, older branding, or superseded implementation details. Start with docs/README.md and docs/archive/README.md for current guidance.

# Background Upload Implementation Plan

**Date**: 2025-11-08
**Design Doc**: `2025-11-08-background-upload-design.md`
**Execution Strategy**: Parallel subagents using TDD

## Overview

This plan breaks the background upload feature into **4 independent tasks** that can be executed in parallel by different agents. Each task follows strict TDD: write failing tests first, then implement.

## Parallel Task Breakdown

### Task 1: UploadManager Enhancement
**Agent**: general-purpose
**Estimated Time**: 15 minutes

**Objective**: Ensure `UploadManager` has `cancelUpload()` method for aborting in-progress uploads.

**Steps**:
1. Check if `lib/services/upload_manager.dart` already has `cancelUpload(String id)` method
2. If YES: Skip to step 6 (verification tests)
3. If NO: Proceed with TDD implementation

**TDD Cycle**:
4. Write unit test: `test/services/upload_manager_test.dart`
   - Test: `cancelUpload() aborts in-progress upload`
   - Test: `cancelUpload() cleans up temp files`
   - Test: `cancelUpload() updates status to 'cancelled'`
5. Run tests → confirm they fail
6. Implement `cancelUpload()` in `UploadManager`
7. Run tests → confirm they pass
8. Run `flutter analyze` → fix any issues

**Deliverables**:
- ✅ `cancelUpload(String id)` method exists
- ✅ Unit tests pass
- ✅ No analyzer warnings

---

### Task 2: Upload Progress Dialog Component
**Agent**: general-purpose
**Estimated Time**: 20 minutes

**Objective**: Create reusable dialog widget that shows upload progress with blocking UI.

**Files to Create/Modify**:
- `lib/widgets/upload_progress_dialog.dart` (new)
- `test/widgets/upload_progress_dialog_test.dart` (new)

**TDD Cycle**:
1. Write widget tests:
   - Test: Dialog displays current upload progress percentage
   - Test: Dialog is non-dismissible (barrierDismissible: false)
   - Test: Dialog auto-closes when upload reaches readyToPublish status
   - Test: Dialog polls UploadManager every 500ms for status updates
2. Run tests → confirm they fail
3. Implement `UploadProgressDialog` widget:
   ```dart
   class UploadProgressDialog extends StatefulWidget {
     final String uploadId;
     final UploadManager uploadManager;

     // Poll upload status, show progress bar
     // Auto-close when status == UploadStatus.readyToPublish
   }
   ```
4. Run tests → confirm they pass
5. Run `flutter analyze` → fix any issues

**Design Requirements**:
- Dark mode styling (black background, white text)
- Progress bar with percentage: "Uploading video... 73%"
- Non-dismissible (user must wait)
- Polls upload status every 500ms
- Auto-closes on completion

**Deliverables**:
- ✅ `UploadProgressDialog` widget created
- ✅ Widget tests pass
- ✅ Follows VineTheme dark mode styling
- ✅ No analyzer warnings

---

### Task 3: Background Upload Lifecycle
**Agent**: general-purpose
**Estimated Time**: 30 minutes

**Objective**: Modify `VideoMetadataScreenPure` to start upload in `initState()` and cancel in `dispose()`.

**Files to Modify**:
- `lib/screens/pure/video_metadata_screen_pure.dart`
- `test/screens/video_metadata_screen_pure_test.dart`

**TDD Cycle**:
1. Write unit tests:
   - Test: `initState()` starts background upload immediately
   - Test: `dispose()` cancels upload if still in progress
   - Test: `dispose()` does not cancel if upload already complete
   - Test: Upload ID is stored in `_backgroundUploadId` state variable
2. Run tests → confirm they fail
3. Add state variables to `_VideoMetadataScreenPureState`:
   ```dart
   String? _backgroundUploadId;
   UploadStatus? _uploadStatus;
   StreamSubscription? _uploadProgressListener;
   ```
4. Implement `_startBackgroundUpload()` method (called from `initState()`)
5. Implement `_cancelBackgroundUpload()` method (called from `dispose()`)
6. Run tests → confirm they pass
7. Run `flutter analyze` → fix any issues

**Key Implementation Details**:
- `_startBackgroundUpload()` should:
  - Call `uploadManager.startUpload()` with current draft
  - Store returned upload ID in `_backgroundUploadId`
  - Set up status listener (optional, for UI updates)
- `_cancelBackgroundUpload()` should:
  - Check if `_backgroundUploadId` is not null
  - Check if upload status is still in-progress (uploading/processing)
  - Call `uploadManager.cancelUpload(_backgroundUploadId!)`
  - Cancel `_uploadProgressListener` subscription

**Deliverables**:
- ✅ Background upload starts in `initState()`
- ✅ Upload cancelled in `dispose()` if in-progress
- ✅ Unit tests pass
- ✅ No analyzer warnings

---

### Task 4: Publish Button Integration
**Agent**: general-purpose
**Estimated Time**: 35 minutes

**Objective**: Modify `_publishVideo()` to check upload status and wait if needed before publishing Nostr event.

**Files to Modify**:
- `lib/screens/pure/video_metadata_screen_pure.dart` (same file as Task 3, but different method)
- `test/screens/video_metadata_screen_pure_test.dart`

**TDD Cycle**:
1. Write integration tests:
   - Test: Publish pressed when upload complete → immediately publishes
   - Test: Publish pressed when upload in-progress → shows progress dialog, waits, then publishes
   - Test: Publish pressed when upload failed → shows error dialog with retry option
   - Test: User retries failed upload → restarts upload, shows progress dialog
2. Run tests → confirm they fail
3. Modify `_publishVideo()` method:
   ```dart
   Future<void> _publishVideo() async {
     final upload = uploadManager.getUpload(_backgroundUploadId!);

     // Handle different upload states
     if (upload.status == UploadStatus.uploading ||
         upload.status == UploadStatus.processing) {
       // Show blocking progress dialog
       await showDialog(
         context: context,
         barrierDismissible: false,
         builder: (_) => UploadProgressDialog(
           uploadId: _backgroundUploadId!,
           uploadManager: uploadManager,
         ),
       );
     } else if (upload.status == UploadStatus.failed) {
       // Show error dialog with retry option
       final shouldRetry = await _showUploadErrorDialog();
       if (shouldRetry) {
         await _retryUpload();
         // Recursively call _publishVideo after retry
         return _publishVideo();
       } else {
         return; // User cancelled
       }
     }

     // Proceed with Nostr event creation (existing logic)
     final published = await videoEventPublisher.publishDirectUpload(upload);
     // ... rest of existing publish logic
   }
   ```
4. Implement `_showUploadErrorDialog()` helper
5. Implement `_retryUpload()` helper
6. Run tests → confirm they pass
7. Run `flutter analyze` → fix any issues

**Deliverables**:
- ✅ Publish button waits for upload completion
- ✅ Progress dialog shown when upload in-progress
- ✅ Error dialog shown when upload failed
- ✅ Retry functionality works
- ✅ Integration tests pass
- ✅ No analyzer warnings

---

## Execution Order

**Phase 1: Parallel Execution** (Tasks can run simultaneously)
- Launch Task 1, 2, 3, 4 in parallel using 4 separate agents

**Phase 2: Integration** (After all tasks complete)
- Run full test suite: `cd mobile && flutter test`
- Run analyzer: `flutter analyze`
- Manual testing on macOS build: `./run_dev.sh macos debug`
- Verify UX flows:
  1. Start recording → go to metadata → upload starts immediately → edit metadata → press publish → Nostr event created
  2. Start recording → go to metadata → press back button → upload cancelled, draft saved
  3. Start recording → go to metadata → simulate upload failure → press publish → error dialog → retry → success

**Phase 3: Code Review**
- Run `.claude/review_checklist.sh`
- Ensure all tests pass
- Ensure no TODOs left in code
- Check for duplicate classes

---

## Success Criteria

✅ All unit tests pass
✅ All integration tests pass
✅ All widget tests pass
✅ `flutter analyze` returns zero issues
✅ Manual testing confirms expected UX behavior
✅ No code duplication introduced
✅ Dark mode styling maintained throughout
✅ Code review checklist passes

---

## Notes for Subagents

- **Strict TDD**: Write tests FIRST, confirm they fail, then implement
- **Dark Mode Only**: Use `VineTheme` constants (no light mode)
- **No Timeouts**: Do not add timeout parameters to `flutter test` commands
- **Full Nostr IDs**: Never truncate event IDs or pubkeys
- **ABOUTME Comments**: Add 2-line ABOUTME comment at top of new files
- **No Future.delayed**: Use proper async patterns (Completers, Streams, callbacks)

---

## Rollback Plan

If any task fails or causes regression:
1. Identify failing task
2. Revert changes to affected files
3. Re-run tests to confirm stability
4. Debug root cause before re-attempting
