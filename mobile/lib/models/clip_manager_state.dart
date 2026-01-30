// ABOUTME: UI state model for the Clip Manager screen
// ABOUTME: Tracks clips, selection state, and duration calculations

import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/recording_clip.dart';

/// State model for the Clip Manager.
///
/// Manages the complete state of recorded video clips including:
/// - List of recorded clips
/// - Selection and preview states
/// - UI states (reordering, processing)
/// - Audio settings
/// - Duration tracking and calculations
class ClipManagerState {
  ClipManagerState({
    this.clips = const [],
    this.selectedClipId,
    this.previewingClipId,
    this.isReordering = false,
    this.isProcessing = false,
    this.errorMessage,
    this.muteOriginalAudio = false,
    this.activeRecordingDuration = .zero,
  });

  /// List of all recorded clips in order.
  final List<RecordingClip> clips;

  /// ID of the currently selected clip for editing, or null if none selected.
  final String? selectedClipId;

  /// ID of the clip currently being previewed, or null if none previewing.
  final String? previewingClipId;

  /// Whether the user is actively reordering clips.
  final bool isReordering;

  /// Whether a long-running operation (e.g., processing, saving) is in progress.
  final bool isProcessing;

  /// Error message to display to the user, or null if no error.
  final String? errorMessage;

  /// Whether to mute the original audio from clips during playback.
  final bool muteOriginalAudio;

  /// Current duration of the active recording in progress.
  final Duration activeRecordingDuration;

  /// Total combined duration of all clips.
  Duration get totalDuration {
    return clips.fold(Duration.zero, (sum, clip) => sum + clip.duration);
  }

  /// Remaining recording time available before reaching max duration.
  ///
  /// Returns zero if max duration has been reached or exceeded.
  Duration get remainingDuration {
    final remaining = VideoEditorConstants.maxDuration - totalDuration;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Whether more recording time is available.
  bool get canRecordMore => remainingDuration > Duration.zero;

  /// Whether at least one clip has been recorded.
  bool get hasClips => clips.isNotEmpty;

  /// Total number of clips.
  int get clipCount => clips.length;

  /// The currently selected clip, or null if none selected or not found.
  RecordingClip? get selectedClip {
    if (selectedClipId == null) return null;
    try {
      return clips.firstWhere((c) => c.id == selectedClipId);
    } catch (_) {
      return null;
    }
  }

  /// The clip currently being previewed, or null if none previewing or not found.
  RecordingClip? get previewingClip {
    if (previewingClipId == null) return null;
    try {
      return clips.firstWhere((c) => c.id == previewingClipId);
    } catch (_) {
      return null;
    }
  }

  /// Creates a copy of this state with updated fields.
  ///
  /// Provides special flags to explicitly clear optional fields:
  /// - [clearSelection]: Sets selectedClipId to null
  /// - [clearPreview]: Sets previewingClipId to null
  /// - [clearError]: Sets errorMessage to null
  ClipManagerState copyWith({
    List<RecordingClip>? clips,
    String? selectedClipId,
    String? previewingClipId,
    bool? isReordering,
    bool? isProcessing,
    String? errorMessage,
    bool? muteOriginalAudio,
    bool clearSelection = false,
    bool clearPreview = false,
    bool clearError = false,
    Duration? activeRecordingDuration,
  }) {
    return ClipManagerState(
      clips: clips ?? this.clips,
      selectedClipId: clearSelection
          ? null
          : (selectedClipId ?? this.selectedClipId),
      previewingClipId: clearPreview
          ? null
          : (previewingClipId ?? this.previewingClipId),
      isReordering: isReordering ?? this.isReordering,
      isProcessing: isProcessing ?? this.isProcessing,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      muteOriginalAudio: muteOriginalAudio ?? this.muteOriginalAudio,
      activeRecordingDuration:
          activeRecordingDuration ?? this.activeRecordingDuration,
    );
  }
}
