// ABOUTME: Immutable state model for video editor managing text overlays, sound, and export progress
// ABOUTME: Tracks editing state with export stages and computed properties for UI state

import 'package:flutter/widgets.dart';
import 'package:openvine/models/recording_clip.dart';
import 'package:openvine/models/video_metadata/video_metadata_expiration.dart';

/// Immutable state model for the video editor.
///
/// Manages the complete editing state including:
/// - Playback position and clip navigation
/// - UI interaction states (editing, reordering, playing)
/// - Audio settings
/// - Processing status
class VideoEditorProviderState {
  /// Creates a video editor state with optional initial values.
  VideoEditorProviderState({
    this.currentClipIndex = 0,
    this.currentPosition = .zero,
    this.splitPosition = .zero,
    this.isEditing = false,
    this.isReordering = false,
    this.isOverDeleteZone = false,
    this.isPlaying = false,
    this.isPlayerReady = false,
    this.hasPlayedOnce = false,
    this.isMuted = false,
    this.isProcessing = false,
    this.isSavingDraft = false,
    this.allowAudioReuse = false,
    this.title = '',
    this.description = '',
    this.tags = const {},
    this.expiration = .notExpire,
    this.metadataLimitReached = false,
    this.finalRenderedClip,
    GlobalKey? deleteButtonKey,
  }) : deleteButtonKey = deleteButtonKey ?? GlobalKey();

  /// Index of the currently active/selected clip (0-based).
  final int currentClipIndex;

  /// Current playback position within the video timeline.
  final Duration currentPosition;

  /// Position where a clip split operation will occur.
  final Duration splitPosition;

  /// Whether the editor is in editing mode (e.g., trimming, adjusting).
  final bool isEditing;

  /// Whether clips are being reordered by drag-and-drop.
  final bool isReordering;

  /// Whether a dragged clip is over the delete zone during reordering.
  final bool isOverDeleteZone;

  /// Whether video playback is currently active.
  final bool isPlaying;

  /// Whether the video player is initialized and ready for playback.
  final bool isPlayerReady;

  /// Whether the video has started playing at least once.
  /// Used to determine if thumbnail should be hidden.
  final bool hasPlayedOnce;

  /// Whether audio is muted during playback.
  final bool isMuted;

  /// Whether a long-running operation (e.g., export, processing) is in
  /// progress.
  final bool isProcessing;

  /// Whether a draft save operation is currently in progress.
  final bool isSavingDraft;

  /// GlobalKey for the delete button to enable hit testing.
  final GlobalKey deleteButtonKey;

  /// Video post title displayed in metadata screen.
  final String title;

  /// Video post description providing additional context.
  final String description;

  /// List of hashtags/tags associated with the video for discovery.
  final Set<String> tags;

  /// Whether the audio from the original video can be reused in other videos.
  final bool allowAudioReuse;

  /// Expiration setting determining when the video post expires.
  final VideoMetadataExpiration expiration;

  /// Whether the 64KB metadata limit was reached during the last update.
  final bool metadataLimitReached;

  /// The final rendered clip after all editing and processing operations are
  /// complete.
  /// This represents the video output ready for publishing.
  final RecordingClip? finalRenderedClip;

  /// Whether the video is valid and ready to be posted.
  ///
  /// Returns true if:
  /// - Metadata is within the 64KB limit
  /// - Final rendered clip is available
  bool get isValidToPost =>
      !metadataLimitReached && !isProcessing && finalRenderedClip != null;

  /// Creates a copy of this state with updated fields.
  ///
  /// All parameters are optional. Only provided fields will be updated,
  /// others retain their current values.
  VideoEditorProviderState copyWith({
    int? currentClipIndex,
    Duration? currentPosition,
    Duration? splitPosition,
    bool? isEditing,
    bool? isReordering,
    bool? isOverDeleteZone,
    bool? isPlaying,
    bool? isPlayerReady,
    bool? hasPlayedOnce,
    bool? isMuted,
    bool? isProcessing,
    bool? isSavingDraft,
    bool? allowAudioReuse,
    GlobalKey? deleteButtonKey,
    String? title,
    String? description,
    Set<String>? tags,
    VideoMetadataExpiration? expiration,
    bool? metadataLimitReached,
    RecordingClip? finalRenderedClip,
  }) {
    return VideoEditorProviderState(
      currentClipIndex: currentClipIndex ?? this.currentClipIndex,
      currentPosition: currentPosition ?? this.currentPosition,
      splitPosition: splitPosition ?? this.splitPosition,
      isEditing: isEditing ?? this.isEditing,
      isReordering: isReordering ?? this.isReordering,
      isOverDeleteZone: isOverDeleteZone ?? this.isOverDeleteZone,
      isPlaying: isPlaying ?? this.isPlaying,
      isPlayerReady: isPlayerReady ?? this.isPlayerReady,
      hasPlayedOnce: hasPlayedOnce ?? this.hasPlayedOnce,
      isMuted: isMuted ?? this.isMuted,
      isProcessing: isProcessing ?? this.isProcessing,
      isSavingDraft: isSavingDraft ?? this.isSavingDraft,
      allowAudioReuse: allowAudioReuse ?? this.allowAudioReuse,
      deleteButtonKey: deleteButtonKey ?? this.deleteButtonKey,
      title: title ?? this.title,
      description: description ?? this.description,
      tags: tags ?? this.tags,
      expiration: expiration ?? this.expiration,
      metadataLimitReached: metadataLimitReached ?? this.metadataLimitReached,
      finalRenderedClip: finalRenderedClip ?? this.finalRenderedClip,
    );
  }
}
