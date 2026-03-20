Status: Historical

> Historical note
> Preserved for context during the P1 documentation refresh. This file may reference deleted screens, older branding, or superseded implementation details. Start with docs/README.md and docs/archive/README.md for current guidance.

# Auto-Drafts Feature Design

**Date**: 2025-11-08
**Status**: Approved for Implementation
**Author**: Claude (via brainstorming session with Rabble)

## Overview

Implement automatic draft creation for all recorded videos to ensure no user work is lost. Every video recording automatically becomes a draft, and publishing attempts are tracked within the draft lifecycle.

## Requirements

1. **Auto-Draft Creation**: Every recorded video automatically becomes a draft immediately after recording stops
2. **Publish Tracking**: Publishing attempts update the existing draft (no duplicates)
3. **Failed Publish Handling**: Failed publishes keep draft with error message, allow immediate retry
4. **Draft Persistence**: Drafts persist until successfully published
5. **Video Preview**: Preview/metadata screens show video playback before publishing
6. **Save Draft Buttons**: Both camera and preview screens have save draft functionality

## Architecture: Provider-Centric Auto-Draft

### Core Principle
`VineRecordingProvider` owns the complete recording-to-draft lifecycle. Recording completion triggers automatic draft creation, eliminating screen-level draft creation logic.

### Component Changes

#### 1. VineDraft Model Enhancements

**New Fields**:
```dart
enum PublishStatus { draft, publishing, failed, published }

class VineDraft {
  final PublishStatus publishStatus;
  final String? publishError;
  final int publishAttempts;
  // ... existing fields (id, videoFile, title, description, hashtags, etc.)
}
```

**Purpose**: Track draft publishing lifecycle and enable retry logic.

**Migration**: Old drafts default to `PublishStatus.draft` with 0 attempts.

#### 2. VineRecordingProvider Modifications

**Dependency Injection**:
- Inject `DraftStorageService` into provider
- Add `_currentDraftId` tracking field

**Auto-Draft Logic**:
```dart
class VineRecordingProvider extends StateNotifier<VineRecordingUIState> {
  final DraftStorageService _draftStorage;
  String? _currentDraftId;

  Future<RecordingResult> stopRecording() async {
    // ... existing stop and finalize logic ...

    // Auto-create draft immediately after video finalized
    final draft = VineDraft.create(
      videoFile: finalVideo,
      title: 'Do it for the Vine!',
      description: '',
      hashtags: ['openvine', 'vine'],
      frameCount: segments.length,
      selectedApproach: 'native',
      publishStatus: PublishStatus.draft,
      publishError: null,
      publishAttempts: 0,
    );

    await _draftStorage.saveDraft(draft);
    _currentDraftId = draft.id;

    return RecordingResult(
      videoFile: finalVideo,
      draftId: draft.id,
    );
  }
}
```

**Benefits**:
- Single source of truth for draft creation
- No duplicate drafts (one draft per recording session)
- Clean separation: provider creates, screens edit

#### 3. Preview Screen Refactoring

**VinePreviewScreenPure Changes**:
- **New required parameter**: `String draftId`
- **Remove parameters**: `videoFile`, `frameCount`, `selectedApproach` (load from draft)
- **Initialization**: Load existing draft by ID in `initState()`
- **Save Draft**: Update existing draft with current form values
- **Publish Flow**:
  1. Update draft status to `publishing`
  2. Attempt upload
  3. On success: delete draft
  4. On failure: update draft with error, show retry UI

**VideoMetadataScreenPure Changes**: Same refactoring pattern as VinePreviewScreenPure.

**Video Preview Implementation**:
Both screens already have `VideoPlayerController` and preview logic. Ensure:
- Video loads from draft's `videoFile` path
- Looping playback enabled
- Preview shows during metadata editing
- Proper disposal on screen exit

#### 4. Navigation Updates

**Camera → Preview**:
```dart
// UniversalCameraScreenPure
final result = await ref.read(vineRecordingProvider.notifier).stopRecording();
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => VinePreviewScreenPure(draftId: result.draftId!),
  ),
);
```

**Drafts List → Preview**:
```dart
// VineDraftsScreen (minimal change)
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => VinePreviewScreenPure(draftId: draft.id),
  ),
);
```

#### 5. Camera Draft Button

**Current Behavior**: Navigates to `VineDraftsScreen` to view all saved drafts.

**Decision**: Keep unchanged. Button serves as "view my drafts" since auto-drafting eliminates need for manual "save as draft" action during recording.

## Data Flow

### Recording to Draft Flow
```
User records → Recording stops → Provider auto-creates draft
  → Provider returns (videoFile, draftId)
  → Navigate to preview with draftId
  → Preview loads draft, shows video, allows editing
```

### Publishing Flow
```
User edits metadata → Clicks Publish → Draft status = "publishing"
  → Upload attempt
    ├─ Success → Delete draft → Navigate to feed
    └─ Failure → Draft status = "failed" → Show error + retry button
```

### Retry Flow
```
User clicks retry → Draft status = "publishing" → Upload attempt
  → (repeat success/failure handling)
```

## Testing Strategy (TDD)

### Unit Tests (Write First)
1. **VineDraft Model**:
   - Test `PublishStatus` enum serialization
   - Test `copyWith()` with publish status fields
   - Test `fromJson()` migration (old drafts without status)
   - Test `toJson()` includes all new fields

2. **DraftStorageService**:
   - Test save/load draft with publish status
   - Test update existing draft preserves draft ID
   - Test multiple save operations don't create duplicates

3. **VineRecordingProvider**:
   - Test `stopRecording()` creates draft automatically
   - Test draft has correct default metadata
   - Test draft ID returned in `RecordingResult`
   - Test subsequent recordings create separate drafts

### Widget Tests (Write First)
1. **VinePreviewScreenPure**:
   - Test screen loads draft by ID
   - Test video preview initializes from draft
   - Test save button updates existing draft
   - Test publish button updates draft status
   - Test failed publish shows error UI
   - Test retry button visible when status = failed

2. **VideoMetadataScreenPure**: Same test coverage as preview screen

### Integration Tests (Write First)
1. **Full Recording Flow**:
   - Record video → auto-draft created → navigate → preview shows video
   - Edit metadata → save → draft updated
   - Publish → success → draft deleted

2. **Failed Publish Flow**:
   - Publish fails → draft kept with error → retry → success → draft deleted

## Implementation Order (TDD Red-Green-Refactor)

1. **VineDraft Model**: Add fields, write tests, implement
2. **DraftStorageService**: Update persistence, write tests, implement
3. **VineRecordingProvider**: Add auto-draft, write tests, implement
4. **Navigation Layer**: Update result types, write tests, implement
5. **VinePreviewScreenPure**: Refactor to load by ID, write tests, implement
6. **VideoMetadataScreenPure**: Same refactor, write tests, implement
7. **Integration Tests**: Full flow verification

## Migration Notes

**Existing Drafts**: `VineDraft.fromJson()` handles old drafts without publish status by defaulting to `PublishStatus.draft` with 0 attempts.

**No Breaking Changes**: Old drafts continue to work, just gain new publishing capabilities.

## Success Criteria

- ✅ Every recording creates draft automatically
- ✅ No duplicate drafts for same recording session
- ✅ Failed publishes keep draft with error message
- ✅ Retry functionality works from preview screen
- ✅ Video preview shows on publish screens
- ✅ All tests pass (unit, widget, integration)
- ✅ `flutter analyze` shows no errors
- ✅ Existing drafts migrate seamlessly
