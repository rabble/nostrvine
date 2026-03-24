Status: Historical

> Historical note
> Preserved for context during the P1 documentation refresh. This file may reference deleted screens, older branding, or superseded implementation details. Start with docs/README.md and docs/archive/README.md for current guidance.

# Aspect Ratio Selection for Video Recording

**Date**: 2025-11-08
**Status**: Design Approved
**Author**: AI Assistant (Claude Code)

## Overview

Add user-selectable aspect ratio for video recording, allowing users to choose between:
- **Square (1:1)** - Classic Vine format (default)
- **Vertical (9:16)** - Modern TikTok/Reels format

## Requirements

1. **Default Behavior**: Square (1:1) aspect ratio by default to maintain Vine aesthetic
2. **Recording**: Record videos at the selected aspect ratio using FFmpeg crop filters
3. **Metadata**: Store dimensions in Nostr event `dim` tags
4. **UI**: Toggle button in upper-right camera controls
5. **Preview**: Camera preview updates to match selected aspect ratio
6. **Persistence**: Aspect ratio stored in draft metadata for resume/edit

## Design

### 1. Data Model & State Management

**AspectRatio Enum**:
```dart
// lib/models/aspect_ratio.dart (new file)
enum AspectRatio {
  square,   // 1:1 (default, classic Vine)
  vertical, // 9:16 (modern vertical video)
}
```

**VineRecordingUIState Updates**:
```dart
// lib/providers/vine_recording_provider.dart
class VineRecordingUIState {
  final AspectRatio aspectRatio; // Add this field (default: AspectRatio.square)

  // Update copyWith() to include aspectRatio
}
```

**VineRecordingController Changes**:
```dart
// lib/services/vine_recording_controller.dart
class VineRecordingController {
  AspectRatio _aspectRatio = AspectRatio.square; // Private field

  AspectRatio get aspectRatio => _aspectRatio; // Getter

  void setAspectRatio(AspectRatio ratio) {
    // Only allow changes when not recording
    if (state != VineRecordingState.recording) {
      _aspectRatio = ratio;
      _stateChangeCallback?.call(); // Notify UI
    }
  }
}
```

**VineRecordingNotifier Updates**:
```dart
// lib/providers/vine_recording_provider.dart
class VineRecordingNotifier {
  AspectRatio get aspectRatio => _controller.aspectRatio;

  void setAspectRatio(AspectRatio ratio) {
    _controller.setAspectRatio(ratio);
    updateState();
  }
}
```

### 2. FFmpeg Video Processing

**Dynamic Crop Filter**:
```dart
// lib/services/vine_recording_controller.dart
String _buildCropFilter(AspectRatio aspectRatio) {
  switch (aspectRatio) {
    case AspectRatio.square:
      // Center crop to 1:1 (existing production logic)
      return "crop=min(iw\\,ih):min(iw\\,ih):(iw-min(iw\\,ih))/2:(ih-min(iw\\,ih))/2";

    case AspectRatio.vertical:
      // Center crop to 9:16 vertical
      // Tested and validated with FFmpeg integration tests
      return "crop='if(gt(iw/ih\\,9/16)\\,ih*9/16\\,iw)':'if(gt(iw/ih\\,9/16)\\,ih\\,iw*16/9)':'(iw-if(gt(iw/ih\\,9/16)\\,ih*9/16\\,iw))/2':'(ih-if(gt(iw/ih\\,9/16)\\,ih\\,iw*16/9))/2'";
  }
}
```

**Update `_concatenateSegments()` method**:
- Replace hardcoded crop filter at line 1153 (single segment)
- Replace hardcoded crop filter at line 1210 (multi-segment)
- Both use: `_buildCropFilter(_aspectRatio)`

**Test Results** (from `test/services/ffmpeg_aspect_ratio_crop_test.dart`):
- ✅ Square: 1920x1080 → 1080x1080 (1:1)
- ✅ Vertical: 1920x1080 → 607x1080 (9:16)
- ✅ Vertical preserve: 1080x1920 → 1080x1920 (9:16, no crop)

### 3. UI Implementation

**Camera Controls** (`lib/screens/pure/universal_camera_screen_pure.dart`):

Add aspect ratio toggle to `_buildCameraControls()` method (around line 438):

```dart
Widget _buildCameraControls(VineRecordingUIState recordingState) {
  return Column(
    children: [
      _buildFlashToggle(),
      const SizedBox(height: 12),
      _buildTimerToggle(),
      const SizedBox(height: 12),
      _buildAspectRatioToggle(recordingState), // NEW
    ],
  );
}

Widget _buildAspectRatioToggle(VineRecordingUIState recordingState) {
  return Container(
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(8),
    ),
    child: IconButton(
      icon: Icon(
        recordingState.aspectRatio == AspectRatio.square
          ? Icons.crop_square  // Square icon for 1:1
          : Icons.crop_portrait, // Portrait icon for 9:16
        color: Colors.white,
        size: 28,
      ),
      onPressed: recordingState.isRecording ? null : () {
        final newRatio = recordingState.aspectRatio == AspectRatio.square
          ? AspectRatio.vertical
          : AspectRatio.square;
        ref.read(vineRecordingProvider.notifier).setAspectRatio(newRatio);
      },
    ),
  );
}
```

**Camera Preview Update** (line 404):
```dart
child: AspectRatio(
  aspectRatio: recordingState.aspectRatio == AspectRatio.square ? 1.0 : 9.0 / 16.0,
  child: ClipRect(
    child: recordingState.isInitialized
      ? ref.read(vineRecordingProvider.notifier).previewWidget
      : CameraPreviewPlaceholder(isRecording: recordingState.isRecording),
  ),
),
```

### 4. Nostr Event Metadata

**Dimension Tag Helper**:
```dart
// lib/utils/video_dimensions.dart (new file)
String getDimensionTag(AspectRatio aspectRatio, int baseResolution) {
  switch (aspectRatio) {
    case AspectRatio.square:
      return '${baseResolution}x${baseResolution}';

    case AspectRatio.vertical:
      final width = (baseResolution * 9 / 16).round();
      return '${width}x${baseResolution}';
  }
}
```

**Examples**:
- Square 1080p: `"1080x1080"`
- Vertical 1080p: `"607x1080"`

**Draft Storage**:
```dart
// lib/models/vine_draft.dart
class VineDraft {
  final AspectRatio aspectRatio; // Add field

  // Update factory constructors and serialization
}
```

Store aspect ratio in draft when creating in `vine_recording_provider.dart:150`.

## Implementation Plan

### Files to Modify

1. **New Files**:
   - `lib/models/aspect_ratio.dart` - AspectRatio enum
   - `lib/utils/video_dimensions.dart` - Dimension tag helper
   - `test/services/vine_recording_controller_aspect_ratio_test.dart` - Unit tests

2. **Modified Files**:
   - `lib/services/vine_recording_controller.dart` - Add aspectRatio state, `_buildCropFilter()`
   - `lib/providers/vine_recording_provider.dart` - Expose aspectRatio, add `setAspectRatio()`
   - `lib/screens/pure/universal_camera_screen_pure.dart` - Add UI toggle, update preview
   - `lib/models/vine_draft.dart` - Add aspectRatio field
   - `test/services/ffmpeg_aspect_ratio_crop_test.dart` - Already written and validated

### Test-Driven Development Approach

**Phase 1: Core State Management**
1. Write failing test: VineRecordingController stores and retrieves aspectRatio
2. Write failing test: setAspectRatio() updates state and notifies listeners
3. Write failing test: setAspectRatio() is blocked during recording
4. Implement minimal code to pass tests

**Phase 2: FFmpeg Filter Generation**
1. Write failing test: _buildCropFilter(square) returns correct filter
2. Write failing test: _buildCropFilter(vertical) returns correct filter
3. Write failing test: _concatenateSegments() uses dynamic crop filter
4. Implement minimal code to pass tests
5. ✅ Already validated with integration tests

**Phase 3: UI Integration**
1. Write failing widget test: Aspect ratio toggle appears in camera controls
2. Write failing widget test: Toggle changes icon based on state
3. Write failing widget test: Toggle disabled during recording
4. Write failing widget test: Camera preview aspect ratio updates
5. Implement minimal code to pass tests

**Phase 4: Draft Storage**
1. Write failing test: VineDraft stores aspectRatio
2. Write failing test: VineDraft serialization includes aspectRatio
3. Write failing test: VineDraft deserialization restores aspectRatio
4. Implement minimal code to pass tests

**Phase 5: Nostr Metadata**
1. Write failing test: getDimensionTag(square) returns correct dimensions
2. Write failing test: getDimensionTag(vertical) returns correct dimensions
3. Write failing test: Video upload sets correct dim tag
4. Implement minimal code to pass tests

## Success Criteria

- ✅ FFmpeg crop filters validated with integration tests
- [ ] User can toggle between square and vertical aspect ratios
- [ ] Camera preview updates to match selected aspect ratio
- [ ] Recorded videos have correct aspect ratio (1:1 or 9:16)
- [ ] Nostr events contain correct `dim` tags
- [ ] Drafts preserve aspect ratio selection
- [ ] All unit tests pass
- [ ] Flutter analyze shows zero issues

## Open Questions

None - design approved and FFmpeg filters validated.
