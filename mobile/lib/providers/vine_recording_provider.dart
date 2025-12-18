// ABOUTME: Riverpod state management for VineRecordingController
// ABOUTME: Provides reactive state updates for recording UI without ChangeNotifier

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:riverpod/riverpod.dart' show Ref;
import 'package:openvine/services/vine_recording_controller.dart'
    show
        VineRecordingController,
        VineRecordingState,
        RecordingSegment,
        MacOSCameraInterface,
        CameraPlatformInterface,
        MobileCameraInterface;
import 'package:openvine/models/vine_draft.dart';
import 'package:openvine/models/saved_clip.dart';
import 'package:models/models.dart' show NativeProofData;
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/clip_library_service.dart';
import 'package:openvine/services/video_thumbnail_service.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// Result returned from stopRecording containing video file and native proof
class RecordingResult {
  const RecordingResult({
    required this.videoFile,
    this.nativeProof,
  });

  final File? videoFile;
  final NativeProofData? nativeProof;
}

/// State class for VineRecording that captures all necessary UI state
class VineRecordingUIState {
  const VineRecordingUIState({
    required this.recordingState,
    required this.progress,
    required this.totalRecordedDuration,
    required this.remainingDuration,
    required this.canRecord,
    required this.segments,
    required this.hasSegments,
    required this.segmentCount,
    required this.isCameraInitialized,
    required this.canSwitchCamera,
    required this.aspectRatio,
    this.cameraSwitchCount = 0,
  });

  final VineRecordingState recordingState;
  final double progress;
  final Duration totalRecordedDuration;
  final Duration remainingDuration;
  final bool canRecord;
  final List<RecordingSegment> segments;
  final bool
  hasSegments; // From controller.hasSegments - includes virtual segments for macOS
  final int
  segmentCount; // From controller.segmentCount - includes virtual segments for macOS
  final bool isCameraInitialized;
  final bool canSwitchCamera;
  final model.AspectRatio aspectRatio;
  final int
  cameraSwitchCount; // Increments each time camera switches to force UI rebuild

  // Convenience getters used by UI
  bool get isRecording => recordingState == VineRecordingState.recording;
  bool get isInitialized =>
      isCameraInitialized &&
      recordingState != VineRecordingState.processing &&
      recordingState != VineRecordingState.error;
  bool get isError => recordingState == VineRecordingState.error;
  Duration get recordingDuration => totalRecordedDuration;
  String? get errorMessage => isError ? 'Recording error occurred' : null;

  VineRecordingUIState copyWith({
    VineRecordingState? recordingState,
    double? progress,
    Duration? totalRecordedDuration,
    Duration? remainingDuration,
    bool? canRecord,
    List<RecordingSegment>? segments,
    bool? hasSegments,
    int? segmentCount,
    bool? isCameraInitialized,
    bool? canSwitchCamera,
    model.AspectRatio? aspectRatio,
    int? cameraSwitchCount,
  }) {
    return VineRecordingUIState(
      recordingState: recordingState ?? this.recordingState,
      progress: progress ?? this.progress,
      totalRecordedDuration:
          totalRecordedDuration ?? this.totalRecordedDuration,
      remainingDuration: remainingDuration ?? this.remainingDuration,
      canRecord: canRecord ?? this.canRecord,
      segments: segments ?? this.segments,
      hasSegments: hasSegments ?? this.hasSegments,
      segmentCount: segmentCount ?? this.segmentCount,
      isCameraInitialized: isCameraInitialized ?? this.isCameraInitialized,
      canSwitchCamera: canSwitchCamera ?? this.canSwitchCamera,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      cameraSwitchCount: cameraSwitchCount ?? this.cameraSwitchCount,
    );
  }
}

/// StateNotifier that wraps VineRecordingController and provides reactive updates
class VineRecordingNotifier extends StateNotifier<VineRecordingUIState> {
  VineRecordingNotifier(this._controller, this._ref)
    : super(
        VineRecordingUIState(
          recordingState: _controller.state,
          progress: _controller.progress,
          totalRecordedDuration: _controller.totalRecordedDuration,
          remainingDuration: _controller.remainingDuration,
          canRecord: _controller.canRecord,
          segments: _controller.segments,
          hasSegments: _controller.hasSegments,
          segmentCount: _controller.segmentCount,
          isCameraInitialized: _controller.isCameraInitialized,
          canSwitchCamera: _controller.canSwitchCamera,
          aspectRatio: _controller.aspectRatio,
        ),
      ) {
    // Set up callback for recording progress updates
    _controller.setStateChangeCallback(updateState);
  }

  final VineRecordingController _controller;
  final Ref _ref;

  // Track whether video was successfully published to prevent auto-save
  bool _wasPublished = false;

  // Track the session ID for grouping clips from the same recording session
  String? _currentSessionId;

  /// Get the camera preview widget from the controller
  Widget get previewWidget => _controller.previewWidget;

  /// Get the underlying camera interface for advanced controls
  CameraPlatformInterface? get cameraInterface => _controller.cameraInterface;

  /// Get the actual camera preview aspect ratio to prevent distortion
  /// Returns the real camera sensor aspect ratio, or defaults to 3:4 if unavailable
  double get cameraPreviewAspectRatio {
    // Default fallback for macOS/web or uninitialized cameras
    return 3.0 / 4.0;
  }

  /// Update the state based on the current controller state
  void updateState() {
    state = VineRecordingUIState(
      recordingState: _controller.state,
      progress: _controller.progress,
      totalRecordedDuration: _controller.totalRecordedDuration,
      remainingDuration: _controller.remainingDuration,
      canRecord: _controller.canRecord,
      segments: _controller.segments,
      hasSegments: _controller
          .hasSegments, // CRITICAL: Use controller's hasSegments which includes virtual segments for macOS
      segmentCount: _controller
          .segmentCount, // CRITICAL: Use controller's segmentCount which includes virtual segments for macOS
      isCameraInitialized: _controller.isCameraInitialized,
      canSwitchCamera: _controller.canSwitchCamera,
      aspectRatio: _controller.aspectRatio,
      cameraSwitchCount:
          state.cameraSwitchCount, // CRITICAL: Preserve camera switch count
    );
  }

  // Delegate methods to the controller
  Future<void> initialize() async {
    await _controller.initialize();
    updateState();
  }

  Future<void> startRecording() async {
    // Generate session ID on first segment start
    if (_currentSessionId == null) {
      _currentSessionId = ClipLibraryService.generateSessionId();
      Log.info(
        '📹 New recording session: $_currentSessionId',
        name: 'VineRecordingProvider',
        category: LogCategory.video,
      );
    }

    await _controller.startRecording();
    updateState();
  }

  Future<RecordingResult> stopRecording() async {
    await _controller.stopRecording();
    final result = await _controller.finishRecording();
    updateState();

    Log.info(
      '🔍 PROOFMODE DEBUG: stopRecording() called',
      category: LogCategory.video,
    );
    Log.info(
      '🔍 Video file: ${result.$1?.path ?? "NULL"}',
      category: LogCategory.video,
    );
    Log.info(
      '🔍 Native proof: ${result.$2?.toString() ?? "NULL"}',
      category: LogCategory.video,
    );

    if (result.$2 != null) {
      Log.info(
        '🔍 Proof verification level: ${result.$2!.verificationLevel}',
        category: LogCategory.video,
      );
    } else {
      Log.warning(
        '⚠️ NO NATIVE PROOF DATA FROM RECORDING! ProofMode will not be published.',
        category: LogCategory.video,
      );
    }

    // Clips are saved per-segment in stopSegment(), no draft creation needed
    return RecordingResult(
      videoFile: result.$1,
      nativeProof: result.$2,
    );
  }

  /// Stop the current segment without finishing the recording.
  /// This allows the user to record multiple segments before finalizing.
  Future<void> stopSegment() async {
    await _controller.stopRecording();
    updateState();

    // Get the segment that was just recorded
    final segments = _controller.segments;
    if (segments.isNotEmpty) {
      final lastSegment = segments.last;
      if (lastSegment.filePath != null) {
        await _saveSegmentAsClip(lastSegment.filePath!, lastSegment.duration);
      }
    }

    Log.info(
      '📹 Segment stopped and saved, total segments: ${_controller.segments.length}',
      category: LogCategory.video,
    );
  }

  /// Save a recorded segment as a clip in the library
  Future<void> _saveSegmentAsClip(String videoPath, Duration duration) async {
    try {
      final clipService = await _ref.read(clipLibraryServiceProvider.future);

      // Copy to permanent location in clips directory
      final appDir = await getApplicationSupportDirectory();
      final clipsDir = Directory(path.join(appDir.path, 'clips'));
      if (!clipsDir.existsSync()) {
        clipsDir.createSync(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = path.extension(videoPath);
      final permanentPath = path.join(clipsDir.path, 'clip_$timestamp$extension');

      final sourceFile = File(videoPath);
      await sourceFile.copy(permanentPath);

      // Generate thumbnail
      String? thumbnailPath;
      try {
        thumbnailPath = await VideoThumbnailService.extractThumbnail(
          videoPath: permanentPath,
          timeMs: 100,
        );
      } catch (e) {
        Log.warning(
          '📹 Failed to generate thumbnail: $e',
          name: 'VineRecordingProvider',
          category: LogCategory.video,
        );
      }

      // Create and save the clip
      final clip = SavedClip(
        id: 'clip_$timestamp',
        filePath: permanentPath,
        thumbnailPath: thumbnailPath,
        duration: duration,
        createdAt: DateTime.now(),
        aspectRatio: _controller.aspectRatio.name,
        sessionId: _currentSessionId,
      );

      await clipService.saveClip(clip);

      Log.info(
        '✅ Segment saved as clip: ${clip.id} (session: $_currentSessionId)',
        name: 'VineRecordingProvider',
        category: LogCategory.video,
      );
    } catch (e) {
      Log.error(
        '❌ Failed to save segment as clip: $e',
        name: 'VineRecordingProvider',
        category: LogCategory.video,
      );
    }
  }

  Future<(File?, NativeProofData?)> finishRecording() async {
    final result = await _controller.finishRecording();
    updateState();
    return result;
  }

  /// Extract individual segment files without concatenating
  /// Returns a list of (File, Duration) pairs for each segment
  Future<List<(File, Duration)>> extractSegmentFiles() async {
    final result = await _controller.extractSegmentFiles();
    updateState();
    return result;
  }

  Future<void> switchCamera() async {
    await _controller.switchCamera();

    // Force state update to rebuild UI with new camera preview
    // Increment camera switch count to ensure state object changes and triggers UI rebuild
    state = state.copyWith(cameraSwitchCount: state.cameraSwitchCount + 1);
    updateState();
  }

  /// Set aspect ratio for recording
  void setAspectRatio(model.AspectRatio ratio) {
    _controller.setAspectRatio(ratio);
    updateState();
  }

  /// Set the duration of previously recorded clips from ClipManager
  /// Call this when returning to camera to record additional segments
  void setPreviouslyRecordedDuration(Duration duration) {
    _controller.setPreviouslyRecordedDuration(duration);
    updateState();
  }

  void reset() {
    _controller.reset();
    _wasPublished = false; // Reset publish flag for new recording
    _currentSessionId = null; // Clear session ID for new recording
    updateState();
  }

  /// Mark recording as published to prevent auto-save on dispose
  void markAsPublished() {
    _wasPublished = true;
    Log.info(
      'Recording marked as published - auto-save will be skipped',
      name: 'VineRecordingProvider',
      category: LogCategory.system,
    );
  }

  /// Clean up temp files and reset for new recording
  Future<void> cleanupAndReset() async {
    try {
      // Clean up temp files first
      _controller.cleanupFiles();
      // Then reset state
      _controller.reset();
      _wasPublished = false;
      _currentSessionId = null; // Clear session ID for new recording
      updateState();
      Log.info(
        'Cleaned up temp files and reset for new recording',
        name: 'VineRecordingProvider',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Error during cleanup and reset: $e',
        name: 'VineRecordingProvider',
        category: LogCategory.system,
      );
    }
  }

  @override
  void dispose() {
    // Auto-save as draft if recording completed but not published
    // Note: We can't await in dispose(), so we use unawaited future
    // The controller cleanup will be delayed until save completes via the future chain
    _autoSaveDraftBeforeDispose()
        .then((_) {
          // Clear callback to prevent memory leaks
          _controller.setStateChangeCallback(null);
          _controller.dispose();
        })
        .catchError((e) {
          Log.error(
            'Error during auto-save, proceeding with cleanup: $e',
            name: 'VineRecordingProvider',
            category: LogCategory.system,
          );
          // Ensure cleanup happens even if save fails
          _controller.setStateChangeCallback(null);
          _controller.dispose();
        })
        .whenComplete(() {
          super.dispose();
        });
  }

  /// Auto-save recording as draft if completed but not published
  Future<void> _autoSaveDraftBeforeDispose() async {
    // Clips are now saved per-segment in stopSegment()
    // No need to save draft on dispose
    if (_wasPublished) {
      Log.info(
        'Recording was published, no auto-save needed',
        name: 'VineRecordingProvider',
        category: LogCategory.system,
      );
      return;
    }

    // Clips were already saved during recording
    Log.info(
      'Clips saved during recording, no draft auto-save needed',
      name: 'VineRecordingProvider',
      category: LogCategory.system,
    );
  }

  // Getters that delegate to controller
  VineRecordingController get controller => _controller;
  CameraPlatformInterface? getCameraInterface() => _controller.cameraInterface;
}

/// Provider for VineRecordingController with reactive state management
final vineRecordingProvider =
    StateNotifierProvider<VineRecordingNotifier, VineRecordingUIState>((ref) {
      // Create recording controller (ProofMode handled by Guardian Project native library)
      final controller = VineRecordingController();
      final notifier = VineRecordingNotifier(controller, ref);

      ref.onDispose(() {
        notifier.dispose();
      });

      return notifier;
    });
