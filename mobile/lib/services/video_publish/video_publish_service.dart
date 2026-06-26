// ABOUTME: Service for publishing videos to Nostr with upload management
// ABOUTME: Handles video upload to Blossom servers, retry logic, and Nostr event creation

import 'dart:async';
import 'dart:io';

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';
import 'package:openvine/constants/nip71_migration.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/models/pending_upload.dart';
import 'package:openvine/models/video_publish/video_publish_state.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/collaborator_invite_service.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:openvine/services/language_preference_service.dart';
import 'package:openvine/services/mention_resolution_service.dart';
import 'package:openvine/services/upload_manager.dart';
import 'package:openvine/services/video_event_publisher.dart';
import 'package:openvine/services/video_publish/publish_error_kind.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/utils/public_identifier_normalizer.dart';
import 'package:unified_logger/unified_logger.dart';

/// Result of a publish operation.
sealed class PublishResult extends Equatable {
  const PublishResult();

  @override
  List<Object?> get props => [];
}

class PublishSuccess extends PublishResult {
  const PublishSuccess({this.inviteWarnings = const []});

  final List<CollaboratorInviteWarning> inviteWarnings;

  bool get hasInviteWarnings => inviteWarnings.isNotEmpty;

  @override
  List<Object?> get props => [inviteWarnings];
}

/// A failed publish, classified by [kind] so the UI can localize it.
///
/// [serverName] is the media-server host for the server-related kinds
/// ([PublishErrorKind.serverNotFound] / [PublishErrorKind.serverInternalError]
/// / [PublishErrorKind.serverDown]); null otherwise.
///
/// [rawFallback] carries an already-user-friendly upstream message (or a
/// legacy persisted string) that the UI should render verbatim instead of
/// mapping [kind] — used for the upload-manager passthrough and for drafts
/// persisted before this type existed.
class PublishError extends PublishResult {
  const PublishError(this.kind, {this.serverName, this.rawFallback});

  /// Decodes a value previously produced by [toPersistedString].
  ///
  /// Returns null only when [raw] is null/empty. A value written by an older
  /// build (a plain English sentence) decodes to a generic error carrying that
  /// sentence as [rawFallback], so historical drafts still render verbatim.
  static PublishError? fromPersistedString(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    const prefix = 'pek1:';
    if (raw.startsWith(prefix)) {
      final parts = raw.substring(prefix.length).split(':');
      final kind = _kindByName(parts.first);
      if (kind == null) {
        return PublishError(PublishErrorKind.generic, rawFallback: raw);
      }
      final serverName = parts.length > 1 ? parts.sublist(1).join(':') : null;
      return PublishError(kind, serverName: serverName);
    }
    // Legacy (pre-#4892) sentence string — show as-is.
    return PublishError(PublishErrorKind.generic, rawFallback: raw);
  }

  final PublishErrorKind kind;
  final String? serverName;
  final String? rawFallback;

  /// Encodes this error for persistence in the draft's `publishError` column.
  ///
  /// A [rawFallback] is persisted verbatim (it is already user-friendly text).
  /// Otherwise the stable [kind] (+ [serverName]) is encoded under a `pek1:`
  /// sentinel so it survives a locale change and re-localizes on resume.
  String? toPersistedString() {
    final fallback = rawFallback;
    if (fallback != null && fallback.isNotEmpty) return fallback;
    final base = 'pek1:${kind.name}';
    return serverName == null ? base : '$base:$serverName';
  }

  static PublishErrorKind? _kindByName(String name) {
    for (final kind in PublishErrorKind.values) {
      if (kind.name == name) return kind;
    }
    return null;
  }

  @override
  List<Object?> get props => [kind, serverName, rawFallback];
}

class CollaboratorInviteWarning extends Equatable {
  const CollaboratorInviteWarning({
    required this.collaboratorPubkey,
    required this.creatorPubkey,
    required this.videoAddress,
    this.title,
    this.thumbnailUrl,
    this.relayHint,
    this.error,
  });

  final String collaboratorPubkey;
  final String creatorPubkey;
  final String videoAddress;
  final String? title;
  final String? thumbnailUrl;
  final String? relayHint;
  final String? error;

  @override
  List<Object?> get props => [
    collaboratorPubkey,
    creatorPubkey,
    videoAddress,
    title,
    thumbnailUrl,
    relayHint,
    error,
  ];
}

/// Callbacks for VideoPublishService to communicate state changes.
/// This abstraction makes the service testable without Riverpod dependencies.
typedef OnStateChanged = void Function(VideoPublishState state);
typedef OnProgressChanged =
    void Function({required String draftId, required double progress});

class VideoPublishService {
  VideoPublishService({
    required this.uploadManager,
    required this.authService,
    required this.videoEventPublisher,
    required this.blossomService,
    required this.draftService,
    required this.onProgressChanged,
    this.collaboratorInviteService,
    this.languagePreferenceService,
    this.mentionResolutionService,
  });

  /// Manages background video uploads.
  final UploadManager uploadManager;

  /// Handles user authentication.
  final AuthService authService;

  /// Publishes video events to Nostr.
  final VideoEventPublisher videoEventPublisher;

  /// Handles Blossom server interactions.
  final BlossomUploadService blossomService;

  /// Manages video draft storage.
  final DraftStorageService draftService;

  /// Sends encrypted collaborator invites after a video publish succeeds.
  final CollaboratorInviteService? collaboratorInviteService;

  /// Callback when upload progress changes.
  final OnProgressChanged onProgressChanged;

  /// Language preference for NIP-32 tagging.
  final LanguagePreferenceService? languagePreferenceService;

  /// Resolves typed mentions before publishing Nostr video events.
  final MentionResolutionService? mentionResolutionService;

  /// Tracks the current background upload ID.
  String? _backgroundUploadId;

  /// Publishes a video draft.
  /// Returns [PublishSuccess] on success, [PublishError] on failure.
  Future<PublishResult> publishVideo({required DivineVideoDraft draft}) async {
    // Check if we have a background upload ID and its status
    if (_backgroundUploadId != null) {
      final error = await _handleActiveUpload(draft.id);
      if (error != null) return error;
    }

    try {
      final publishing = draft.copyWith(publishStatus: .publishing);
      await draftService.saveDraft(publishing);

      final videoPath = await draft.clips.first.video.safeFilePath();
      Log.info('📝 Publishing video: $videoPath', category: .video);

      // Verify user is fully authenticated
      if (!authService.isAuthenticated) {
        Log.warning(
          '⚠️ User not authenticated, cannot publish',
          category: .video,
        );
        _backgroundUploadId = null;
        return const PublishError(PublishErrorKind.notSignedIn);
      }
      final pubkey = authService.currentPublicKeyHex!;

      // Use existing upload if available, otherwise start new upload
      final pendingUpload = await _getOrCreateUpload(pubkey, draft);
      if (pendingUpload == null) {
        Log.error('❌ Upload creation failed', category: .video);
        final failedUpload = _backgroundUploadId != null
            ? uploadManager.getUpload(_backgroundUploadId!)
            : null;
        return await _handleUploadError(
          failedUpload?.errorMessage ?? 'Upload failed',
          StackTrace.current,
          draft,
        );
      }

      // Check if upload failed
      if (pendingUpload.status == .failed) {
        Log.error(
          '❌ Upload status is failed: ${pendingUpload.errorMessage}',
          category: .video,
        );
        return await _handleUploadError(
          pendingUpload.errorMessage ?? 'Upload failed',
          StackTrace.current,
          draft,
        );
      }

      if (_uploadedThumbnailUrl(pendingUpload) == null) {
        Log.error(
          '❌ Upload is missing required CDN thumbnail URL',
          category: .video,
        );
        return await _handleUploadError(
          Exception('Thumbnail upload failed'),
          StackTrace.current,
          draft,
        );
      }

      // Publish Nostr event
      Log.info('📝 Publishing Nostr event...', category: .video);

      final mentionedPubkeys = await _resolveMentionedPubkeys(
        draft,
        currentUserPubkey: pubkey,
      );

      final published = await videoEventPublisher.publishVideoEvent(
        upload: pendingUpload,
        title: draft.title,
        description: draft.description,
        hashtags: draft.hashtags.toList(),
        expirationTimestamp: draft.expireTime != null
            ? DateTime.now().millisecondsSinceEpoch ~/ 1000 +
                  draft.expireTime!.inSeconds
            : null,
        allowAudioReuse: draft.allowAudioReuse,
        collaboratorPubkeys: draft.collaboratorPubkeys.toList(),
        mentionedPubkeys: mentionedPubkeys,
        inspiredByAddressableId: draft.inspiredByVideo?.addressableId,
        inspiredByRelayUrl: draft.inspiredByVideo?.relayUrl,
        inspiredByNpub: draft.inspiredByNpub,
        selectedAudio: draft.selectedSound,
        selectedAudioEventId: draft.selectedSound?.id,
        selectedAudioRelay: draft.selectedSound?.sourceVideoRelay,
        language: languagePreferenceService?.contentLanguage,
        contentWarning: draft.contentWarning,
        thumbnailTimestamp: draft.thumbnailTimestamp,
        replyContext: draft.videoReplyContext,
        addReplyToFeed: draft.shareReplyToFeed,
      );

      if (!published) {
        Log.error('❌ Failed to publish Nostr event', category: .video);
        return await _handleUploadError(
          Exception('Failed to publish Nostr event'),
          StackTrace.current,
          draft,
        );
      }

      final inviteWarnings = await _sendCollaboratorInvites(
        draft: draft,
        upload: pendingUpload,
        creatorPubkey: pubkey,
      );

      // Success: delete draft
      await draftService.deleteDraft(draft.id);
      Log.debug('🗑️ Deleted publish draft: ${draft.id}', category: .video);

      Log.info('📝 Published successfully', category: .video);
      return PublishSuccess(inviteWarnings: inviteWarnings);
    } catch (e, stackTrace) {
      return _handleUploadError(e, stackTrace, draft);
    }
  }

  Future<List<String>> _resolveMentionedPubkeys(
    DivineVideoDraft draft, {
    required String currentUserPubkey,
  }) async {
    final resolver = mentionResolutionService;
    if (resolver == null) return const [];

    final rawText = _videoPublishMentionResolutionText(draft);
    if (!rawText.contains('@')) return const [];

    try {
      final result = await resolver.resolveTextMentions(
        rawText: rawText,
        currentUserPubkey: currentUserPubkey,
      );
      return _excludeCollaboratorPubkeys(
        result.resolvedPubkeys,
        draft.collaboratorPubkeys,
      );
    } catch (error) {
      Log.warning(
        'Mention resolution failed during video publish; continuing without mention tags: $error',
        category: .video,
      );
      return const [];
    }
  }

  Future<List<CollaboratorInviteWarning>> _sendCollaboratorInvites({
    required DivineVideoDraft draft,
    required PendingUpload upload,
    required String creatorPubkey,
  }) async {
    final inviteService = collaboratorInviteService;
    final videoId = upload.videoId;
    if (inviteService == null ||
        draft.collaboratorPubkeys.isEmpty ||
        videoId == null ||
        videoId.isEmpty) {
      return const [];
    }

    final videoKind = NIP71VideoKinds.getPreferredAddressableKind();
    final videoAddress = '$videoKind:$creatorPubkey:$videoId';
    final thumbnailUrl = _uploadedThumbnailUrl(upload);
    const relayHint = 'wss://relay.divine.video';

    try {
      final result = await inviteService.sendInvites(
        collaboratorPubkeys: draft.collaboratorPubkeys,
        creatorPubkey: creatorPubkey,
        videoAddress: videoAddress,
        title: draft.title,
        thumbnailUrl: thumbnailUrl,
        relayHint: relayHint,
      );
      if (result.hasFailures) {
        final failures = result.results.entries
            .where((entry) => !entry.value.success)
            .map((entry) => '${entry.key}:${entry.value.error ?? "unknown"}')
            .join(', ');
        Log.error(
          'Some collaborator invites failed to send for '
          '$videoAddress (creator=$creatorPubkey): $failures',
          category: .video,
        );
      }
      return result.results.entries
          .where((entry) => !entry.value.success)
          .map(
            (entry) => CollaboratorInviteWarning(
              collaboratorPubkey: entry.key,
              creatorPubkey: creatorPubkey,
              videoAddress: videoAddress,
              title: draft.title,
              thumbnailUrl: thumbnailUrl,
              relayHint: relayHint,
              error: entry.value.error,
            ),
          )
          .toList(growable: false);
    } on Object catch (e, stackTrace) {
      Log.error(
        'Failed to send collaborator invites for $videoAddress '
        '(creator=$creatorPubkey): $e\n$stackTrace',
        category: .video,
      );
      return draft.collaboratorPubkeys
          .map(
            (pubkey) => CollaboratorInviteWarning(
              collaboratorPubkey: pubkey,
              creatorPubkey: creatorPubkey,
              videoAddress: videoAddress,
              title: draft.title,
              thumbnailUrl: thumbnailUrl,
              relayHint: relayHint,
              error: e.toString(),
            ),
          )
          .toList(growable: false);
    }
  }

  String? _uploadedThumbnailUrl(PendingUpload upload) {
    final value = upload.thumbnailPath?.trim();
    if (value == null || value.isEmpty) return null;
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
    if (uri.scheme != 'https' && uri.scheme != 'http') return null;
    return value;
  }

  /// Gets existing upload from background ID, reuses a matching upload
  /// found by video path, or creates a new one.
  /// Returns null if upload creation fails.
  Future<PendingUpload?> _getOrCreateUpload(
    String pubkey,
    DivineVideoDraft draft,
  ) async {
    // 1. Check in-memory ID (covers same-session retry)
    if (_backgroundUploadId != null) {
      final existingUpload = uploadManager.getUpload(_backgroundUploadId!);
      if (existingUpload != null && existingUpload.status == .readyToPublish) {
        Log.info(
          '📝 Using existing upload: ${existingUpload.id}',
          category: .video,
        );
        return existingUpload;
      }
    }

    // 2. Search for reusable upload by video path (covers app restart)
    final videoPath = await _resolveVideoPath(draft);
    if (videoPath != null) {
      final reusable = uploadManager.findReusableUpload(videoPath);
      if (reusable != null) {
        Log.info(
          '📝 Reusing existing upload ${reusable.id} '
          '(status: ${reusable.status})',
          category: .video,
        );
        _backgroundUploadId = reusable.id;
        return _handleReusableUpload(reusable, draft);
      }
    }

    // 3. Nothing reusable — start fresh
    return _startNewUpload(pubkey, draft);
  }

  /// Resolves the video file path from a draft, mirroring the logic
  /// in [UploadManager.startUploadFromDraft].
  ///
  /// Note: when `finalRenderedClip` is absent and the draft has multiple
  /// clips, this returns the first source clip path. However,
  /// [UploadManager.startUploadFromDraft] merges multiple clips into a
  /// temp file at a different path, so [findReusableUpload] will not
  /// match in that case. The caller falls through to a new upload, which
  /// is the correct behavior since the merged file is ephemeral.
  Future<String?> _resolveVideoPath(DivineVideoDraft draft) async {
    try {
      final rendered = draft.finalRenderedClip;
      if (rendered != null) {
        final path = await rendered.video.safeFilePath();
        if (File(path).existsSync()) return path;
      }
      if (draft.clips.isNotEmpty) {
        return draft.clips.first.video.safeFilePath();
      }
    } catch (e) {
      Log.warning('⚠️ Could not resolve video path: $e', category: .video);
    }
    return null;
  }

  /// Handles a reusable upload found by video path.
  ///
  /// Depending on the upload's current status, either returns it directly
  /// (readyToPublish), kicks it off and polls (uploading/retrying), or
  /// retries it (failed with resumable session).
  Future<PendingUpload?> _handleReusableUpload(
    PendingUpload upload,
    DivineVideoDraft draft,
  ) async {
    switch (upload.status) {
      case UploadStatus.readyToPublish:
        return upload;
      case UploadStatus.uploading:
      case UploadStatus.retrying:
        uploadManager.resumeInterruptedUpload(upload.id);
        final ok = await _pollUploadProgress(draft.id, upload.id);
        return ok ? uploadManager.getUpload(upload.id) : null;
      case UploadStatus.processing:
        final ok = await _pollUploadProgress(draft.id, upload.id);
        return ok ? uploadManager.getUpload(upload.id) : null;
      case UploadStatus.failed:
        // findReusableUpload guarantees a resumable session exists.
        // Don't await — let the retry run in the background so
        // _pollUploadProgress can report progress to the UI.
        unawaited(uploadManager.retryUpload(upload.id));
        final ok = await _pollUploadProgress(draft.id, upload.id);
        return ok ? uploadManager.getUpload(upload.id) : null;
      case UploadStatus.pending:
      case UploadStatus.paused:
      case UploadStatus.published:
        return null;
    }
  }

  /// Handles an active background upload.
  /// Returns [PublishError] if there was an error, null to continue.
  Future<PublishError?> _handleActiveUpload(String draftId) async {
    final upload = uploadManager.getUpload(_backgroundUploadId!);
    if (upload == null) return null;

    Log.debug(
      '📤 Checking active upload: ${upload.id}, status: ${upload.status}',
      category: .video,
    );

    // If already ready, continue
    if (upload.status == .readyToPublish) return null;

    // If failed, return error
    if (upload.status == .failed) {
      _backgroundUploadId = null; // Clear failed upload ID
      return _publishErrorFor(upload.errorMessage ?? 'Upload failed');
    }

    // Wait for upload to complete
    if (upload.status == .uploading || upload.status == .processing) {
      final result = await _pollUploadProgress(draftId, _backgroundUploadId!);
      if (!result) {
        final failedUpload = uploadManager.getUpload(_backgroundUploadId!);
        _backgroundUploadId = null; // Clear failed upload ID
        return _publishErrorFor(failedUpload?.errorMessage ?? 'Upload failed');
      }
    }

    return null;
  }

  /// Polls upload progress until complete or failed.
  /// Returns true if upload succeeded, false if failed.
  Future<bool> _pollUploadProgress(String draftId, String uploadId) async {
    final upload = uploadManager.getUpload(uploadId);
    if (upload == null) return false;

    onProgressChanged(draftId: draftId, progress: upload.uploadProgress ?? 0.0);

    switch (upload.status) {
      case .readyToPublish:
      case .published:
        return true;
      case .failed:
        return false;
      case .uploading:
      case .processing:
      case .pending:
      case .retrying:
      case .paused:
        await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    return _pollUploadProgress(draftId, uploadId);
  }

  /// Starts a new upload and polls for progress until completion.
  /// Returns the upload if successful, null if failed.
  Future<PendingUpload?> _startNewUpload(
    String pubkey,
    DivineVideoDraft draft,
  ) async {
    // Ensure upload manager is initialized
    if (!uploadManager.isInitialized) {
      Log.info('📝 Initializing upload manager...', category: .video);
      await uploadManager.initialize();
    }

    Log.info('📝 Starting upload to Blossom...', category: .video);
    _logProofModeStatus(draft);

    final pendingUpload = await uploadManager.startUploadFromDraft(
      draft: draft,
      nostrPubkey: pubkey,
      onProgress: (value) =>
          onProgressChanged(draftId: draft.id, progress: value),
    );
    _backgroundUploadId = pendingUpload.id;

    // Poll for progress
    final success = await _pollUploadProgress(draft.id, pendingUpload.id);
    if (!success) return null;

    return uploadManager.getUpload(pendingUpload.id);
  }

  /// Logs ProofMode attestation status for debugging.
  void _logProofModeStatus(DivineVideoDraft draft) {
    final hasProofMode = draft.hasProofMode;
    final nativeProof = draft.nativeProof;

    Log.info(
      '📜 ProofMode: $hasProofMode, '
      'nativeProof: ${nativeProof != null ? "present" : "null"}',
      category: .video,
    );

    if (hasProofMode && nativeProof == null) {
      Log.error('📜 ProofMode deserialization failed!', category: .video);
    }
  }

  /// Retry a failed upload and continue publishing.
  Future<PublishResult> retryUpload(DivineVideoDraft draft) async {
    if (_backgroundUploadId == null) {
      Log.warning('⚠️ No background upload to retry', category: .video);

      _backgroundUploadId = null; // Clear any stale upload ID
      return const PublishError(PublishErrorKind.noRetry);
    }

    Log.info('🔄 Retrying upload: $_backgroundUploadId', category: .video);
    try {
      await uploadManager.retryUpload(_backgroundUploadId!);
      final success = await _pollUploadProgress(draft.id, _backgroundUploadId!);

      if (!success) {
        final upload = uploadManager.getUpload(_backgroundUploadId!);
        _backgroundUploadId = null;
        return await _handleUploadError(
          upload?.errorMessage ?? 'Retry failed',
          StackTrace.current,
          draft,
        );
      }

      // Continue with publishing
      return await publishVideo(draft: draft);
    } catch (e, stackTrace) {
      Log.error('📝 Failed to retry: $e', category: LogCategory.video);
      return _handleUploadError(e, stackTrace, draft);
    }
  }

  /// Handles upload errors by logging, updating draft status, and returning
  /// a user-friendly message.
  Future<PublishError> _handleUploadError(
    Object? e,
    StackTrace stackTrace,
    DivineVideoDraft draft,
  ) async {
    _backgroundUploadId = null;
    Log.error('📝 Publish failed: $e\n$stackTrace', category: .video);

    final publishError = await _publishErrorFor(e);

    // Save failed state to draft. Persist the classified kind (not the raw
    // exception string) so an interrupted-draft resume re-localizes correctly
    // and never surfaces a raw exception dump to the user.
    try {
      final failedDraft = draft.copyWith(
        publishStatus: .failed,
        publishError: publishError.toPersistedString(),
        publishAttempts: draft.publishAttempts + 1,
      );
      await draftService.saveDraft(failedDraft);
    } catch (saveError) {
      Log.error('📝 Failed to save error state: $saveError', category: .video);
    }

    return publishError;
  }

  /// Classifies [e] and builds the corresponding [PublishError].
  Future<PublishError> _publishErrorFor(Object? e) async {
    final classified = await _classifyError(e);
    return PublishError(
      classified.kind,
      serverName: classified.serverName,
      rawFallback: classified.rawFallback,
    );
  }

  /// Classifies a technical error into a stable [PublishErrorKind] (plus a
  /// `serverName` for the server-related kinds) so the UI can localize it.
  ///
  /// Known categories — including the upload manager's already-rendered
  /// English sentences — are mapped to a kind first, so a persisted failure
  /// re-localizes in the reader's locale on resume. `rawFallback` is reserved
  /// for genuinely unknown/legacy upstream text (a user-friendly sentence we
  /// don't recognize), which the UI renders verbatim.
  Future<({PublishErrorKind kind, String? serverName, String? rawFallback})>
  _classifyError(Object? e) async {
    final raw = e.toString();

    final matched = classifyPublishErrorMessage(raw);
    if (matched != null) {
      final serverName = _serverNameKinds.contains(matched)
          ? await _resolveServerName()
          : null;
      return (kind: matched, serverName: serverName, rawFallback: null);
    }

    // No known category matched. Reserve `rawFallback` for genuinely
    // user-friendly upstream text (a sentence, not a class/stack dump) so an
    // unrecognized message still renders verbatim instead of a generic line.
    final stripped = raw.replaceFirst(RegExp(r'^Exception:\s*'), '');
    if (stripped != raw || e is String) {
      final clean = (e is String ? raw : stripped).trim();
      if (clean.isNotEmpty &&
          clean.contains('.') &&
          !clean.contains('Exception') &&
          !clean.contains('#0 ')) {
        return (
          kind: PublishErrorKind.generic,
          serverName: null,
          rawFallback: clean,
        );
      }
    }

    return (
      kind: PublishErrorKind.generic,
      serverName: null,
      rawFallback: null,
    );
  }

  /// Kinds that interpolate the media-server host into their localized copy.
  static const Set<PublishErrorKind> _serverNameKinds = {
    PublishErrorKind.serverNotFound,
    PublishErrorKind.serverInternalError,
    PublishErrorKind.serverDown,
  };

  /// Resolves the current media-server host for the server-related kinds.
  Future<String?> _resolveServerName() async {
    try {
      final serverUrl = await blossomService.getBlossomServer();
      if (serverUrl != null && serverUrl.isNotEmpty) {
        return Uri.tryParse(serverUrl)?.host ?? serverUrl;
      }
    } catch (_) {}
    return null;
  }

  /// Maps a technical error string to a stable [PublishErrorKind], or null
  /// when no known category matches.
  ///
  /// Handles both raw exception text and the upload manager's already-rendered
  /// user-friendly sentences (e.g. "No internet connection. …"), so a failure
  /// surfaced through [UploadManager] re-localizes instead of being passed
  /// through as English `rawFallback`.
  ///
  /// The upload-manager sentence substrings must stay in sync with
  /// [UploadManager.getUserFriendlyErrorMessage]; the drift guard in
  /// `video_publish_service_test.dart` fails loudly if that copy changes.
  @visibleForTesting
  static PublishErrorKind? classifyPublishErrorMessage(String error) {
    final errorString = error.toLowerCase();

    // Network / connectivity
    if (errorString.contains('socketexception') ||
        errorString.contains('network is unreachable') ||
        errorString.contains('no address associated') ||
        errorString.contains('failed host lookup') ||
        errorString.contains('no internet connection')) {
      return PublishErrorKind.noInternet;
    }
    if (errorString.contains('connection refused') ||
        errorString.contains('connection reset') ||
        errorString.contains('connection closed') ||
        errorString.contains('network error') ||
        errorString.contains('could not reach')) {
      return PublishErrorKind.serverUnreachable;
    }
    if (errorString.contains('session expired') ||
        errorString.contains('session is no longer available')) {
      return PublishErrorKind.uploadSessionExpired;
    }
    if (errorString.contains('timeout') || errorString.contains('timed out')) {
      return PublishErrorKind.timeout;
    }

    // TLS / certificate
    if (errorString.contains('certificate') ||
        errorString.contains('handshake') ||
        errorString.contains('ssl') ||
        errorString.contains('tls')) {
      return PublishErrorKind.tls;
    }

    // Server errors
    if (errorString.contains('404') || errorString.contains('not_found')) {
      return PublishErrorKind.serverNotFound;
    }
    if (errorString.contains('413') ||
        errorString.contains('payload too large') ||
        errorString.contains('too large')) {
      return PublishErrorKind.fileTooLarge;
    }
    if (errorString.contains('429') ||
        errorString.contains('too many uploads') ||
        errorString.contains('rate limit')) {
      return PublishErrorKind.rateLimited;
    }
    if (errorString.contains('500') ||
        errorString.contains('internal server error') ||
        errorString.contains('server encountered an error')) {
      return PublishErrorKind.serverInternalError;
    }
    if (errorString.contains('502') ||
        errorString.contains('503') ||
        errorString.contains('bad gateway') ||
        errorString.contains('service unavailable') ||
        errorString.contains('temporarily unavailable')) {
      return PublishErrorKind.serverDown;
    }

    // Auth / permissions
    if (errorString.contains('not authenticated') ||
        errorString.contains('unauthorized') ||
        errorString.contains('authentication failed') ||
        errorString.contains('401')) {
      return PublishErrorKind.notSignedIn;
    }
    if (errorString.contains('403') || errorString.contains('forbidden')) {
      return PublishErrorKind.forbidden;
    }
    if (errorString.contains('permission denied') ||
        errorString.contains('permission_denied')) {
      return PublishErrorKind.permissionDenied;
    }

    // Local file / device resources
    if (errorString.contains('no such file') ||
        errorString.contains('file not found') ||
        errorString.contains('pathnotfoundexception')) {
      return PublishErrorKind.fileNotFound;
    }
    if (errorString.contains('storage') ||
        errorString.contains('no space') ||
        errorString.contains('disk full')) {
      return PublishErrorKind.lowStorage;
    }
    if (errorString.contains('not enough memory') ||
        errorString.contains('out of memory') ||
        errorString.contains('outofmemory')) {
      return PublishErrorKind.outOfMemory;
    }

    if (errorString.contains('thumbnail upload failed')) {
      return PublishErrorKind.thumbnailFailed;
    }

    // Nostr event publish
    if (errorString.contains('failed to publish nostr event') ||
        errorString.contains('relay')) {
      return PublishErrorKind.nostrPublishFailed;
    }

    // Upload-manager generic fallbacks (CLIENT_ERROR / default UNKNOWN) —
    // localize as generic rather than passing the English sentence through.
    if (errorString.contains('upload request failed') ||
        errorString.contains('upload failed. please check')) {
      return PublishErrorKind.generic;
    }

    return null;
  }
}

String _videoPublishMentionResolutionText(DivineVideoDraft draft) {
  return [
    draft.description,
    ..._extractVideoPublishTextOverlayStrings(draft.editorStateHistory),
  ].where((text) => text.trim().isNotEmpty).join('\n');
}

List<String> _extractVideoPublishTextOverlayStrings(
  Map<String, dynamic> editorStateHistory,
) {
  final overlays = <String>{};
  if (editorStateHistory.isEmpty) return const [];

  final references = _mapReferences(editorStateHistory['references']);
  final history = editorStateHistory['history'];
  if (history is! Iterable) return const [];

  final historyItems = history.toList();
  final position = editorStateHistory['position'];
  if (position == -1) return const [];

  final currentIndex =
      position is int && position >= 0 && position < historyItems.length
      ? position
      : historyItems.length - 1;
  if (currentIndex < 0) return const [];

  final currentHistoryItem = historyItems[currentIndex];
  if (currentHistoryItem is! Map) return const [];

  final layers = currentHistoryItem['layers'];
  if (layers is! Iterable) return const [];

  for (final rawLayer in layers) {
    if (rawLayer is! Map) continue;
    final layer = Map<String, dynamic>.from(rawLayer);
    final id = layer['id'];
    final mergedLayer = id is String
        ? <String, dynamic>{...?references[id], ...layer}
        : layer;

    final type = mergedLayer['type'];
    final text = mergedLayer['text'];
    if ((type == null || type == 'text') &&
        text is String &&
        text.trim().isNotEmpty) {
      overlays.add(text);
    }
  }

  return overlays.toList();
}

Map<String, Map<String, dynamic>> _mapReferences(Object? rawReferences) {
  if (rawReferences is! Map) return const {};

  final references = <String, Map<String, dynamic>>{};
  for (final entry in rawReferences.entries) {
    final key = entry.key;
    final value = entry.value;
    if (key is String && value is Map) {
      references[key] = Map<String, dynamic>.from(value);
    }
  }
  return references;
}

List<String> _excludeCollaboratorPubkeys(
  Iterable<String> pubkeys,
  Iterable<String> collaboratorPubkeys,
) {
  final collaborators = collaboratorPubkeys
      .map(normalizeToHex)
      .whereType<String>()
      .where(NostrKeyUtils.isValidKey)
      .toSet();
  final seen = <String>{};
  final result = <String>[];

  for (final pubkey in pubkeys) {
    final hex = normalizeToHex(pubkey);
    if (hex == null || !NostrKeyUtils.isValidKey(hex)) continue;
    if (collaborators.contains(hex) || !seen.add(hex)) continue;
    result.add(hex);
  }

  return result;
}
