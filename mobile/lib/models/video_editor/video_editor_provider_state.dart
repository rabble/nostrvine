// ABOUTME: Immutable state model for video editor managing text overlays, sound, and export progress
// ABOUTME: Tracks editing state with export stages and computed properties for UI state

import 'package:flutter/widgets.dart';
import 'package:models/models.dart' show AudioEvent, InspiredByInfo;
import 'package:openvine/models/content_label.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_metadata/video_metadata_expiration.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

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
    this.isProcessing = false,
    this.isSavingDraft = false,
    this.allowAudioReuse = true,
    this.title = '',
    this.description = '',
    this.tags = const {},
    this.expiration = .notExpire,
    this.metadataLimitReached = false,
    this.finalRenderedClip,
    this.editorStateHistory = const {},
    this.editorEditingParameters,
    this.collaboratorPubkeys = const {},
    this.pendingCollaboratorPubkeys = const {},
    this.inspiredByVideo,
    this.inspiredByNpub,
    this.selectedSound,
    this.originalAudioVolume = 1.0,
    this.customAudioVolume = 1.0,
    this.contentWarnings = const {},
    this.proofManifestJson,
    GlobalKey? deleteButtonKey,
  }) : deleteButtonKey = deleteButtonKey ?? GlobalKey();

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
  final DivineVideoClip? finalRenderedClip;

  /// Serialized state history from ProImageEditor for undo/redo restoration.
  final Map<String, dynamic> editorStateHistory;

  /// Serialized editing parameters (filters, drawings, etc.) from ProImageEditor.
  final CompleteParameters? editorEditingParameters;

  /// Pubkeys of collaborators to tag in the published video.
  final Set<String> collaboratorPubkeys;

  /// Pubkeys of collaborators awaiting mutual-follow verification.
  final Set<String> pendingCollaboratorPubkeys;

  /// Reference to a specific video that inspired this one (a-tag).
  final InspiredByInfo? inspiredByVideo;

  /// NIP-27 npub reference for general "Inspired By" a creator.
  final String? inspiredByNpub;

  /// Currently selected sound for the video.
  /// Contains the full AudioEvent data including URL, title, and start offset.
  /// This is persisted in drafts and used for audio playback during editing.
  final AudioEvent? selectedSound;

  /// Volume level for the original video audio track (0.0 to 1.0).
  final double originalAudioVolume;

  /// Volume level for the custom/added audio track (0.0 to 1.0).
  final double customAudioVolume;

  /// NIP-32 content warning labels for sensitive content self-labeling.
  final Set<ContentLabel> contentWarnings;

  /// ProofMode attestation manifest JSON for the final rendered clip.
  final String? proofManifestJson;

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
  ///
  /// Use [clearFinalRenderedClip] = true to explicitly set
  /// [finalRenderedClip] to null.
  /// Use [clearInspiredByVideo] = true to explicitly set
  /// [inspiredByVideo] to null.
  /// Use [clearInspiredByNpub] = true to explicitly set
  /// [inspiredByNpub] to null.
  /// Use [clearSelectedSound] = true to explicitly set
  /// [selectedSound] to null.
  VideoEditorProviderState copyWith({
    bool? isProcessing,
    bool? isSavingDraft,
    bool? allowAudioReuse,
    GlobalKey? deleteButtonKey,
    String? title,
    String? description,
    Set<String>? tags,
    VideoMetadataExpiration? expiration,
    bool? metadataLimitReached,
    DivineVideoClip? finalRenderedClip,
    bool clearFinalRenderedClip = false,
    String? proofManifestJson,
    bool clearProofManifestJson = false,
    Map<String, dynamic>? editorStateHistory,
    CompleteParameters? editorEditingParameters,
    Set<String>? collaboratorPubkeys,
    Set<String>? pendingCollaboratorPubkeys,
    InspiredByInfo? inspiredByVideo,
    bool clearInspiredByVideo = false,
    String? inspiredByNpub,
    bool clearInspiredByNpub = false,
    AudioEvent? selectedSound,
    bool clearSelectedSound = false,
    double? originalAudioVolume,
    double? customAudioVolume,
    Set<ContentLabel>? contentWarnings,
  }) {
    return VideoEditorProviderState(
      isProcessing: isProcessing ?? this.isProcessing,
      isSavingDraft: isSavingDraft ?? this.isSavingDraft,
      allowAudioReuse: allowAudioReuse ?? this.allowAudioReuse,
      deleteButtonKey: deleteButtonKey ?? this.deleteButtonKey,
      title: title ?? this.title,
      description: description ?? this.description,
      tags: tags ?? this.tags,
      expiration: expiration ?? this.expiration,
      metadataLimitReached: metadataLimitReached ?? this.metadataLimitReached,
      finalRenderedClip: clearFinalRenderedClip
          ? null
          : (finalRenderedClip ?? this.finalRenderedClip),
      editorStateHistory: editorStateHistory ?? this.editorStateHistory,
      editorEditingParameters:
          editorEditingParameters ?? this.editorEditingParameters,
      collaboratorPubkeys: collaboratorPubkeys ?? this.collaboratorPubkeys,
      pendingCollaboratorPubkeys:
          pendingCollaboratorPubkeys ?? this.pendingCollaboratorPubkeys,
      inspiredByVideo: clearInspiredByVideo
          ? null
          : (inspiredByVideo ?? this.inspiredByVideo),
      inspiredByNpub: clearInspiredByNpub
          ? null
          : (inspiredByNpub ?? this.inspiredByNpub),
      selectedSound: clearSelectedSound
          ? null
          : (selectedSound ?? this.selectedSound),
      originalAudioVolume: originalAudioVolume ?? this.originalAudioVolume,
      customAudioVolume: customAudioVolume ?? this.customAudioVolume,
      contentWarnings: contentWarnings ?? this.contentWarnings,
      proofManifestJson: clearProofManifestJson || clearFinalRenderedClip
          ? null
          : proofManifestJson ?? this.proofManifestJson,
    );
  }
}
