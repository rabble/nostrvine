Status: Historical

> Historical note
> Preserved for context during the P1 documentation refresh. This file may reference deleted screens, older branding, or superseded implementation details. Start with docs/README.md and docs/archive/README.md for current guidance.

# Aspect Ratio Selection Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add user-selectable aspect ratio for video recording (square 1:1 vs vertical 9:16)

**Architecture:** Add AspectRatio enum to VineRecordingController state, expose through Riverpod provider, add UI toggle in camera screen, update FFmpeg crop filters dynamically, store in draft metadata and Nostr dim tags.

**Tech Stack:** Flutter, Riverpod, FFmpeg, Nostr NIP-71

---

## Task 1: Create AspectRatio Enum

**Files:**
- Create: `lib/models/aspect_ratio.dart`
- Test: `test/models/aspect_ratio_test.dart`

**Step 1: Write the failing test**

```dart
// test/models/aspect_ratio_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/aspect_ratio.dart';

void main() {
  group('AspectRatio', () {
    test('has square value', () {
      expect(AspectRatio.square, isNotNull);
    });

    test('has vertical value', () {
      expect(AspectRatio.vertical, isNotNull);
    });

    test('square is default (first enum value)', () {
      expect(AspectRatio.values.first, equals(AspectRatio.square));
    });
  });
}
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/models/aspect_ratio_test.dart`

Expected: FAIL with "Target of URI doesn't exist: 'package:openvine/models/aspect_ratio.dart'"

**Step 3: Write minimal implementation**

```dart
// lib/models/aspect_ratio.dart
// ABOUTME: Aspect ratio options for video recording
// ABOUTME: Used to configure camera preview and FFmpeg crop filters

/// Aspect ratio options for video recording
enum AspectRatio {
  square,   // 1:1 (default, classic Vine)
  vertical, // 9:16 (modern vertical video)
}
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/models/aspect_ratio_test.dart`

Expected: PASS (3 tests)

**Step 5: Commit**

```bash
git add lib/models/aspect_ratio.dart test/models/aspect_ratio_test.dart
git commit -m "feat: add AspectRatio enum for video recording

- Add square (1:1) and vertical (9:16) aspect ratio options
- Square is default (first enum value)

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 2: Add AspectRatio State to VineRecordingController

**Files:**
- Modify: `lib/services/vine_recording_controller.dart`
- Test: `test/services/vine_recording_controller_aspect_ratio_test.dart`

**Step 1: Write the failing test**

```dart
// test/services/vine_recording_controller_aspect_ratio_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/aspect_ratio.dart';
import 'package:openvine/services/vine_recording_controller.dart';

void main() {
  group('VineRecordingController AspectRatio', () {
    test('defaults to square aspect ratio', () {
      final controller = VineRecordingController();
      expect(controller.aspectRatio, equals(AspectRatio.square));
    });

    test('setAspectRatio updates aspectRatio', () {
      final controller = VineRecordingController();
      controller.setAspectRatio(AspectRatio.vertical);
      expect(controller.aspectRatio, equals(AspectRatio.vertical));
    });

    test('setAspectRatio triggers state change callback', () {
      final controller = VineRecordingController();
      var callbackCalled = false;
      controller.setStateChangeCallback(() {
        callbackCalled = true;
      });

      controller.setAspectRatio(AspectRatio.vertical);
      expect(callbackCalled, isTrue);
    });

    test('setAspectRatio blocked during recording', () {
      final controller = VineRecordingController();
      // Simulate recording state
      controller.state = VineRecordingState.recording;

      controller.setAspectRatio(AspectRatio.vertical);

      // Should still be square (default)
      expect(controller.aspectRatio, equals(AspectRatio.square));
    });
  });
}
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/services/vine_recording_controller_aspect_ratio_test.dart`

Expected: FAIL with "The getter 'aspectRatio' isn't defined for the type 'VineRecordingController'"

**Step 3: Write minimal implementation**

```dart
// lib/services/vine_recording_controller.dart

// Add import at top
import 'package:openvine/models/aspect_ratio.dart';

// Inside VineRecordingController class, add after _segments field:
  AspectRatio _aspectRatio = AspectRatio.square;

  /// Get current aspect ratio
  AspectRatio get aspectRatio => _aspectRatio;

  /// Set aspect ratio (only allowed when not recording)
  void setAspectRatio(AspectRatio ratio) {
    if (state == VineRecordingState.recording) {
      Log.warning('Cannot change aspect ratio while recording',
          name: 'VineRecordingController', category: LogCategory.system);
      return;
    }

    _aspectRatio = ratio;
    Log.info('Aspect ratio changed to: $ratio',
        name: 'VineRecordingController', category: LogCategory.system);
    _stateChangeCallback?.call();
  }
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/services/vine_recording_controller_aspect_ratio_test.dart`

Expected: PASS (4 tests)

**Step 5: Commit**

```bash
git add lib/services/vine_recording_controller.dart test/services/vine_recording_controller_aspect_ratio_test.dart
git commit -m "feat: add aspect ratio state to VineRecordingController

- Add _aspectRatio field (defaults to square)
- Add setAspectRatio() method with recording state validation
- Block aspect ratio changes during active recording

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 3: Add Dynamic FFmpeg Crop Filter

**Files:**
- Modify: `lib/services/vine_recording_controller.dart:1123-1220`
- Test: Already validated in `test/services/ffmpeg_aspect_ratio_crop_test.dart`

**Step 1: Add _buildCropFilter() method**

Find the `_concatenateSegments()` method and add this helper method BEFORE it:

```dart
// lib/services/vine_recording_controller.dart

  /// Build FFmpeg crop filter for the specified aspect ratio
  ///
  /// Square: Center crop to 1:1 (minimum dimension)
  /// Vertical: Center crop to 9:16 (portrait)
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

**Step 2: Update single-segment crop (line ~1153)**

Replace:
```dart
final command = '-i "$inputPath" -vf "crop=min(iw\\,ih):min(iw\\,ih):(iw-min(iw\\,ih))/2:(ih-min(iw\\,ih))/2" -c:a copy "$outputPath"';
```

With:
```dart
final cropFilter = _buildCropFilter(_aspectRatio);
final command = '-i "$inputPath" -vf "$cropFilter" -c:a copy "$outputPath"';
```

**Step 3: Update multi-segment crop (line ~1210)**

Replace:
```dart
final command = '-f concat -safe 0 -i "$concatFilePath" -vf "crop=min(iw\\,ih):min(iw\\,ih):(iw-min(iw\\,ih))/2:(ih-min(iw\\,ih))/2" -c:a copy "$outputPath"';
```

With:
```dart
final cropFilter = _buildCropFilter(_aspectRatio);
final command = '-f concat -safe 0 -i "$concatFilePath" -vf "$cropFilter" -c:a copy "$outputPath"';
```

**Step 4: Run existing FFmpeg tests to verify**

Run: `flutter test test/services/ffmpeg_aspect_ratio_crop_test.dart`

Expected: PASS (6 tests) - validates crop filters work correctly

**Step 5: Commit**

```bash
git add lib/services/vine_recording_controller.dart
git commit -m "feat: add dynamic FFmpeg crop filter based on aspect ratio

- Add _buildCropFilter() method supporting square and vertical
- Update single-segment concatenation to use dynamic filter
- Update multi-segment concatenation to use dynamic filter
- Validated with FFmpeg integration tests

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 4: Expose AspectRatio in VineRecordingUIState

**Files:**
- Modify: `lib/providers/vine_recording_provider.dart:34-82`
- Test: `test/providers/vine_recording_provider_aspect_ratio_test.dart`

**Step 1: Write the failing test**

```dart
// test/providers/vine_recording_provider_aspect_ratio_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/aspect_ratio.dart';
import 'package:openvine/providers/vine_recording_provider.dart';
import 'package:openvine/services/vine_recording_controller.dart';

void main() {
  group('VineRecordingUIState AspectRatio', () {
    test('includes aspectRatio in state', () {
      final controller = VineRecordingController();
      final state = VineRecordingUIState(
        recordingState: controller.state,
        progress: controller.progress,
        totalRecordedDuration: controller.totalRecordedDuration,
        remainingDuration: controller.remainingDuration,
        canRecord: controller.canRecord,
        segments: controller.segments,
        isCameraInitialized: controller.isCameraInitialized,
        aspectRatio: controller.aspectRatio,
      );

      expect(state.aspectRatio, equals(AspectRatio.square));
    });

    test('copyWith updates aspectRatio', () {
      final controller = VineRecordingController();
      final state = VineRecordingUIState(
        recordingState: controller.state,
        progress: controller.progress,
        totalRecordedDuration: controller.totalRecordedDuration,
        remainingDuration: controller.remainingDuration,
        canRecord: controller.canRecord,
        segments: controller.segments,
        isCameraInitialized: controller.isCameraInitialized,
        aspectRatio: AspectRatio.square,
      );

      final updated = state.copyWith(aspectRatio: AspectRatio.vertical);
      expect(updated.aspectRatio, equals(AspectRatio.vertical));
    });
  });
}
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/providers/vine_recording_provider_aspect_ratio_test.dart`

Expected: FAIL with "The named parameter 'aspectRatio' isn't defined"

**Step 3: Update VineRecordingUIState class**

```dart
// lib/providers/vine_recording_provider.dart

// Add import at top
import 'package:openvine/models/aspect_ratio.dart';

// Update VineRecordingUIState class (around line 34-82):

class VineRecordingUIState {
  const VineRecordingUIState({
    required this.recordingState,
    required this.progress,
    required this.totalRecordedDuration,
    required this.remainingDuration,
    required this.canRecord,
    required this.segments,
    required this.isCameraInitialized,
    required this.aspectRatio,  // ADD THIS
  });

  final VineRecordingState recordingState;
  final double progress;
  final Duration totalRecordedDuration;
  final Duration remainingDuration;
  final bool canRecord;
  final List<RecordingSegment> segments;
  final bool isCameraInitialized;
  final AspectRatio aspectRatio;  // ADD THIS

  // ... existing convenience getters ...

  VineRecordingUIState copyWith({
    VineRecordingState? recordingState,
    double? progress,
    Duration? totalRecordedDuration,
    Duration? remainingDuration,
    bool? canRecord,
    List<RecordingSegment>? segments,
    bool? isCameraInitialized,
    AspectRatio? aspectRatio,  // ADD THIS
  }) {
    return VineRecordingUIState(
      recordingState: recordingState ?? this.recordingState,
      progress: progress ?? this.progress,
      totalRecordedDuration: totalRecordedDuration ?? this.totalRecordedDuration,
      remainingDuration: remainingDuration ?? this.remainingDuration,
      canRecord: canRecord ?? this.canRecord,
      segments: segments ?? this.segments,
      isCameraInitialized: isCameraInitialized ?? this.isCameraInitialized,
      aspectRatio: aspectRatio ?? this.aspectRatio,  // ADD THIS
    );
  }
}
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/providers/vine_recording_provider_aspect_ratio_test.dart`

Expected: PASS (2 tests)

**Step 5: Commit**

```bash
git add lib/providers/vine_recording_provider.dart test/providers/vine_recording_provider_aspect_ratio_test.dart
git commit -m "feat: add aspectRatio to VineRecordingUIState

- Add aspectRatio field to state class
- Update copyWith() to support aspect ratio changes
- Include in state initialization

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 5: Update VineRecordingNotifier to Expose AspectRatio

**Files:**
- Modify: `lib/providers/vine_recording_provider.dart:85-127`
- Test: `test/providers/vine_recording_provider_notifier_test.dart`

**Step 1: Write the failing test**

```dart
// test/providers/vine_recording_provider_notifier_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/aspect_ratio.dart';
import 'package:openvine/providers/vine_recording_provider.dart';

void main() {
  group('VineRecordingNotifier AspectRatio', () {
    test('initial state includes square aspect ratio', () {
      final container = ProviderContainer();
      final state = container.read(vineRecordingProvider);

      expect(state.aspectRatio, equals(AspectRatio.square));
      container.dispose();
    });

    test('setAspectRatio updates state', () {
      final container = ProviderContainer();
      final notifier = container.read(vineRecordingProvider.notifier);

      notifier.setAspectRatio(AspectRatio.vertical);

      final state = container.read(vineRecordingProvider);
      expect(state.aspectRatio, equals(AspectRatio.vertical));
      container.dispose();
    });
  });
}
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/providers/vine_recording_provider_notifier_test.dart`

Expected: FAIL with "1 positional argument(s) expected, but 8 found" (missing aspectRatio in constructor)

**Step 3: Update VineRecordingNotifier class**

```dart
// lib/providers/vine_recording_provider.dart

// Update VineRecordingNotifier constructor (around line 85-102):

class VineRecordingNotifier extends StateNotifier<VineRecordingUIState> {
  VineRecordingNotifier(
    this._controller,
    this._ref,
  ) : super(
          VineRecordingUIState(
            recordingState: _controller.state,
            progress: _controller.progress,
            totalRecordedDuration: _controller.totalRecordedDuration,
            remainingDuration: _controller.remainingDuration,
            canRecord: _controller.canRecord,
            segments: _controller.segments,
            isCameraInitialized: _controller.isCameraInitialized,
            aspectRatio: _controller.aspectRatio,  // ADD THIS
          ),
        ) {
    _controller.setStateChangeCallback(updateState);
  }

  // ... existing fields ...

  /// Update the state based on the current controller state
  void updateState() {
    state = VineRecordingUIState(
      recordingState: _controller.state,
      progress: _controller.progress,
      totalRecordedDuration: _controller.totalRecordedDuration,
      remainingDuration: _controller.remainingDuration,
      canRecord: _controller.canRecord,
      segments: _controller.segments,
      isCameraInitialized: _controller.isCameraInitialized,
      aspectRatio: _controller.aspectRatio,  // ADD THIS
    );
  }

  // ADD NEW METHOD after updateState():

  /// Set aspect ratio for recording
  void setAspectRatio(AspectRatio ratio) {
    _controller.setAspectRatio(ratio);
    updateState();
  }
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/providers/vine_recording_provider_notifier_test.dart`

Expected: PASS (2 tests)

**Step 5: Commit**

```bash
git add lib/providers/vine_recording_provider.dart test/providers/vine_recording_provider_notifier_test.dart
git commit -m "feat: expose aspectRatio in VineRecordingNotifier

- Include aspectRatio in state initialization
- Update updateState() to sync aspect ratio from controller
- Add setAspectRatio() method to notifier

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 6: Add UI Toggle to Camera Screen

**Files:**
- Modify: `lib/screens/pure/universal_camera_screen_pure.dart:404,438-443`
- Test: `test/screens/universal_camera_screen_aspect_ratio_test.dart`

**Step 1: Write the failing widget test**

```dart
// test/screens/universal_camera_screen_aspect_ratio_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/aspect_ratio.dart';
import 'package:openvine/screens/pure/universal_camera_screen_pure.dart';

void main() {
  group('UniversalCameraScreenPure AspectRatio', () {
    testWidgets('displays aspect ratio toggle button', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: UniversalCameraScreenPure(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Look for crop_square icon (default square aspect ratio)
      expect(find.byIcon(Icons.crop_square), findsOneWidget);
    });

    testWidgets('toggle button changes icon when tapped', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: UniversalCameraScreenPure(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Initial state: square icon
      expect(find.byIcon(Icons.crop_square), findsOneWidget);

      // Tap toggle button
      await tester.tap(find.byIcon(Icons.crop_square));
      await tester.pumpAndSettle();

      // After toggle: portrait icon
      expect(find.byIcon(Icons.crop_portrait), findsOneWidget);
    });
  });
}
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/screens/universal_camera_screen_aspect_ratio_test.dart`

Expected: FAIL with "Expected: exactly one matching node, Actual: _WidgetIconFinder:<zero widgets>"

**Step 3: Add _buildAspectRatioToggle() method**

```dart
// lib/screens/pure/universal_camera_screen_pure.dart

// Add import at top
import 'package:openvine/models/aspect_ratio.dart';

// Find _buildCameraControls() method (around line 438) and update it:

  Widget _buildCameraControls(VineRecordingUIState recordingState) {
    return Column(
      children: [
        // Flash toggle
        _buildFlashToggle(),
        const SizedBox(height: 12),

        // Timer toggle
        _buildTimerToggle(),
        const SizedBox(height: 12),

        // Aspect ratio toggle (NEW)
        _buildAspectRatioToggle(recordingState),
      ],
    );
  }

  // ADD NEW METHOD after _buildCameraControls():

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

**Step 4: Update camera preview aspect ratio (line ~404)**

```dart
// lib/screens/pure/universal_camera_screen_pure.dart

// Find the camera preview AspectRatio widget (around line 404):

              Positioned.fill(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: recordingState.aspectRatio == AspectRatio.square
                      ? 1.0
                      : 9.0 / 16.0,  // UPDATE THIS LINE
                    child: ClipRect(
                      child: recordingState.isInitialized
                        ? ref.read(vineRecordingProvider.notifier).previewWidget
                        : CameraPreviewPlaceholder(
                            isRecording: recordingState.isRecording,
                          ),
                    ),
                  ),
                ),
              ),
```

**Step 5: Run test to verify it passes**

Run: `flutter test test/screens/universal_camera_screen_aspect_ratio_test.dart`

Expected: PASS (2 tests)

**Step 6: Commit**

```bash
git add lib/screens/pure/universal_camera_screen_pure.dart test/screens/universal_camera_screen_aspect_ratio_test.dart
git commit -m "feat: add aspect ratio toggle to camera screen UI

- Add _buildAspectRatioToggle() method with icon toggle
- Update camera preview to use dynamic aspect ratio
- Disable toggle during active recording

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 7: Add AspectRatio to VineDraft Model

**Files:**
- Modify: `lib/models/vine_draft.dart`
- Test: `test/models/vine_draft_aspect_ratio_test.dart`

**Step 1: Write the failing test**

```dart
// test/models/vine_draft_aspect_ratio_test.dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/aspect_ratio.dart';
import 'package:openvine/models/vine_draft.dart';

void main() {
  group('VineDraft AspectRatio', () {
    test('create() includes aspect ratio', () {
      final testFile = File('test_video.mp4');
      final draft = VineDraft.create(
        videoFile: testFile,
        duration: const Duration(seconds: 5),
        aspectRatio: AspectRatio.vertical,
      );

      expect(draft.aspectRatio, equals(AspectRatio.vertical));
    });

    test('defaults to square if not specified', () {
      final testFile = File('test_video.mp4');
      final draft = VineDraft.create(
        videoFile: testFile,
        duration: const Duration(seconds: 5),
      );

      expect(draft.aspectRatio, equals(AspectRatio.square));
    });

    test('toJson includes aspectRatio', () {
      final testFile = File('test_video.mp4');
      final draft = VineDraft.create(
        videoFile: testFile,
        duration: const Duration(seconds: 5),
        aspectRatio: AspectRatio.vertical,
      );

      final json = draft.toJson();
      expect(json['aspectRatio'], equals('vertical'));
    });

    test('fromJson restores aspectRatio', () {
      final json = {
        'id': 'test-id',
        'videoPath': '/path/to/video.mp4',
        'duration': 5000,
        'title': '',
        'description': '',
        'hashtags': <String>[],
        'createdAt': DateTime.now().toIso8601String(),
        'aspectRatio': 'vertical',
      };

      final draft = VineDraft.fromJson(json);
      expect(draft.aspectRatio, equals(AspectRatio.vertical));
    });

    test('fromJson defaults to square for legacy drafts', () {
      final json = {
        'id': 'test-id',
        'videoPath': '/path/to/video.mp4',
        'duration': 5000,
        'title': '',
        'description': '',
        'hashtags': <String>[],
        'createdAt': DateTime.now().toIso8601String(),
        // No aspectRatio field (legacy draft)
      };

      final draft = VineDraft.fromJson(json);
      expect(draft.aspectRatio, equals(AspectRatio.square));
    });
  });
}
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/models/vine_draft_aspect_ratio_test.dart`

Expected: FAIL with "The named parameter 'aspectRatio' isn't defined"

**Step 3: Update VineDraft class**

```dart
// lib/models/vine_draft.dart

// Add import at top
import 'package:openvine/models/aspect_ratio.dart';

// Update VineDraft class:

class VineDraft {
  final String id;
  final File videoFile;
  final Duration duration;
  final String title;
  final String description;
  final List<String> hashtags;
  final DateTime createdAt;
  final AspectRatio aspectRatio;  // ADD THIS

  VineDraft({
    required this.id,
    required this.videoFile,
    required this.duration,
    required this.title,
    required this.description,
    required this.hashtags,
    required this.createdAt,
    required this.aspectRatio,  // ADD THIS
  });

  factory VineDraft.create({
    required File videoFile,
    required Duration duration,
    String title = '',
    String description = '',
    List<String> hashtags = const [],
    AspectRatio aspectRatio = AspectRatio.square,  // ADD THIS with default
  }) {
    return VineDraft(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      videoFile: videoFile,
      duration: duration,
      title: title,
      description: description,
      hashtags: hashtags,
      createdAt: DateTime.now(),
      aspectRatio: aspectRatio,  // ADD THIS
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'videoPath': videoFile.path,
      'duration': duration.inMilliseconds,
      'title': title,
      'description': description,
      'hashtags': hashtags,
      'createdAt': createdAt.toIso8601String(),
      'aspectRatio': aspectRatio.name,  // ADD THIS
    };
  }

  factory VineDraft.fromJson(Map<String, dynamic> json) {
    return VineDraft(
      id: json['id'] as String,
      videoFile: File(json['videoPath'] as String),
      duration: Duration(milliseconds: json['duration'] as int),
      title: json['title'] as String,
      description: json['description'] as String,
      hashtags: List<String>.from(json['hashtags'] as List),
      createdAt: DateTime.parse(json['createdAt'] as String),
      aspectRatio: json['aspectRatio'] != null  // ADD THIS
        ? AspectRatio.values.firstWhere(
            (e) => e.name == json['aspectRatio'],
            orElse: () => AspectRatio.square,
          )
        : AspectRatio.square,  // Default for legacy drafts
    );
  }
}
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/models/vine_draft_aspect_ratio_test.dart`

Expected: PASS (5 tests)

**Step 5: Commit**

```bash
git add lib/models/vine_draft.dart test/models/vine_draft_aspect_ratio_test.dart
git commit -m "feat: add aspectRatio to VineDraft model

- Add aspectRatio field with square default
- Update toJson/fromJson for persistence
- Support legacy drafts (default to square)

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 8: Update Draft Creation to Capture AspectRatio

**Files:**
- Modify: `lib/providers/vine_recording_provider.dart:140-170`
- Test: Integration test covered by existing draft storage tests

**Step 1: Update draft creation in stopRecording()**

```dart
// lib/providers/vine_recording_provider.dart

// Find the stopRecording() method (around line 140-170):

  Future<RecordingResult> stopRecording() async {
    await _controller.stopRecording();
    final result = await _controller.finishRecording();
    updateState();

    // Auto-create draft immediately after recording finishes
    if (result.$1 != null) {
      try {
        final draftStorage = await _ref.read(draftStorageServiceProvider.future);

        final draft = VineDraft.create(
          videoFile: result.$1!,
          duration: _controller.totalRecordedDuration,
          aspectRatio: _controller.aspectRatio,  // ADD THIS LINE
        );

        await draftStorage.saveDraft(draft);
        _currentDraftId = draft.id;

        Log.info('📹 Auto-created draft: ${draft.id}',
            name: 'VineRecordingProvider', category: LogCategory.video);

        return RecordingResult(
          videoFile: result.$1,
          draftId: draft.id,
          proofManifest: result.$2,
        );
      } catch (e) {
        Log.error('📹 Failed to create draft: $e',
            name: 'VineRecordingProvider', category: LogCategory.video);

        return RecordingResult(
          videoFile: result.$1,
          draftId: null,
          proofManifest: result.$2,
        );
      }
    }

    return RecordingResult(
      videoFile: null,
      draftId: null,
      proofManifest: null,
    );
  }
```

**Step 2: Verify no test failures**

Run: `flutter test test/providers/vine_recording_provider_test.dart`

Expected: PASS (all existing tests)

**Step 3: Commit**

```bash
git add lib/providers/vine_recording_provider.dart
git commit -m "feat: capture aspect ratio when creating drafts

- Pass aspectRatio from controller to VineDraft.create()
- Ensures draft preserves recording aspect ratio

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 9: Add Dimension Tag Helper for Nostr Events

**Files:**
- Create: `lib/utils/video_dimensions.dart`
- Test: `test/utils/video_dimensions_test.dart`

**Step 1: Write the failing test**

```dart
// test/utils/video_dimensions_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/aspect_ratio.dart';
import 'package:openvine/utils/video_dimensions.dart';

void main() {
  group('getDimensionTag', () {
    test('returns correct dimensions for square 1080p', () {
      final result = getDimensionTag(AspectRatio.square, 1080);
      expect(result, equals('1080x1080'));
    });

    test('returns correct dimensions for vertical 1080p', () {
      final result = getDimensionTag(AspectRatio.vertical, 1080);
      expect(result, equals('607x1080'));
    });

    test('returns correct dimensions for square 720p', () {
      final result = getDimensionTag(AspectRatio.square, 720);
      expect(result, equals('720x720'));
    });

    test('returns correct dimensions for vertical 720p', () {
      final result = getDimensionTag(AspectRatio.vertical, 720);
      expect(result, equals('405x720'));
    });

    test('vertical width rounds correctly', () {
      // 1080 * 9/16 = 607.5, should round to 607
      final result = getDimensionTag(AspectRatio.vertical, 1080);
      expect(result, equals('607x1080'));
    });
  });
}
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/utils/video_dimensions_test.dart`

Expected: FAIL with "Target of URI doesn't exist: 'package:openvine/utils/video_dimensions.dart'"

**Step 3: Write minimal implementation**

```dart
// lib/utils/video_dimensions.dart
// ABOUTME: Helper functions for video dimension calculations
// ABOUTME: Converts aspect ratios to Nostr NIP-71 dimension tags

import 'package:openvine/models/aspect_ratio.dart';

/// Get dimension tag for Nostr event based on aspect ratio
///
/// Returns dimension string in format "widthxheight" for NIP-71 dim tag
///
/// Examples:
/// - Square 1080p: "1080x1080"
/// - Vertical 1080p: "607x1080" (9:16 ratio)
String getDimensionTag(AspectRatio aspectRatio, int baseResolution) {
  switch (aspectRatio) {
    case AspectRatio.square:
      // 1:1 - width and height are equal
      return '${baseResolution}x${baseResolution}';

    case AspectRatio.vertical:
      // 9:16 - width is 9/16 of height
      final width = (baseResolution * 9 / 16).round();
      return '${width}x${baseResolution}';
  }
}
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/utils/video_dimensions_test.dart`

Expected: PASS (5 tests)

**Step 5: Commit**

```bash
git add lib/utils/video_dimensions.dart test/utils/video_dimensions_test.dart
git commit -m "feat: add dimension tag helper for Nostr events

- Add getDimensionTag() for aspect ratio to dimensions
- Support square (1:1) and vertical (9:16) aspect ratios
- Calculate correct width for vertical videos

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 10: Run Full Test Suite and Flutter Analyze

**Step 1: Run all tests**

Run: `flutter test`

Expected: All tests PASS (including new aspect ratio tests)

**Step 2: Run flutter analyze**

Run: `flutter analyze`

Expected: No issues found

**Step 3: Manual testing checklist**

Test on macOS debug build:
1. Open camera screen
2. Verify aspect ratio toggle appears in upper-right controls
3. Toggle between square and vertical - preview should update
4. Record video in square mode - verify 1:1 output
5. Record video in vertical mode - verify 9:16 output
6. Verify toggle is disabled during recording
7. Create draft - verify aspect ratio preserved on resume

**Step 4: Final commit**

```bash
git add -A
git commit -m "feat: aspect ratio selection complete

All tests passing, flutter analyze clean.
Ready for manual testing.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Success Criteria

- [x] FFmpeg crop filters validated with integration tests
- [ ] User can toggle between square and vertical aspect ratios
- [ ] Camera preview updates to match selected aspect ratio
- [ ] Recorded videos have correct aspect ratio (1:1 or 9:16)
- [ ] Nostr events contain correct `dim` tags (future task)
- [ ] Drafts preserve aspect ratio selection
- [ ] All unit tests pass
- [ ] Flutter analyze shows zero issues

---

## Next Steps (Future Work)

**Not included in this plan:**
- Update video upload service to use `getDimensionTag()` when publishing to Nostr
- Add aspect ratio display in draft preview
- Add aspect ratio filter in video feed (show only vertical, only square, etc.)

These can be separate tasks after this core functionality is validated.
