import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/pending_upload.dart';
import 'package:openvine/models/video_publish/video_publish_state.dart';
import 'package:openvine/models/vine_draft.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/sounds_providers.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/providers/video_publish_provider.dart';
import 'package:openvine/providers/video_recorder_provider.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:openvine/services/upload_manager.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/upload_progress_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VideoPublishService {
  VideoPublishService();

  Ref? ref;
  BuildContext? context;

  String? _backgroundUploadId = '';

  Future<void> publishVideo({
    required Ref ref,
    required BuildContext context,
    required VineDraft draft,
  }) async {
    this.ref = ref;
    this.context = context;

    final uploadManager = ref.read(uploadManagerProvider);

    // Check if we have a background upload ID and its status
    if (_backgroundUploadId != null) {
      await _handleActiveUpload(ref: ref, context: context, draft: draft);
    }

    // Original publishing logic continues here...
    _setPublishState(.preparing);

    try {
      // Update draft status to "publishing"
      final prefs = await SharedPreferences.getInstance();
      final draftService = DraftStorageService(prefs);

      final publishing = draft.copyWith(publishStatus: .publishing);
      await draftService.saveDraft(publishing);

      final videoPath = await draft.clips.first.video.safeFilePath();

      Log.info(
        '📝 VideoPublishService: Publishing video: ${videoPath}',
        category: LogCategory.video,
      );

      // Verify user is fully authenticated (not just has keys)
      final authService = ref.read(authServiceProvider);
      if (!authService.isAuthenticated) {
        _setPublishState(.error);
        throw Exception(
          'Not authenticated (state: ${authService.authState.name}) - cannot publish video',
        );
      }
      final pubkey = authService.currentPublicKeyHex!;

      // Get video event publisher
      final videoEventPublisher = ref.read(videoEventPublisherProvider);

      // Use existing upload if available, otherwise start new upload
      PendingUpload pendingUpload;
      if (_backgroundUploadId != null) {
        final existingUpload = uploadManager.getUpload(_backgroundUploadId!);
        if (existingUpload != null &&
            existingUpload.status == UploadStatus.readyToPublish) {
          pendingUpload = existingUpload;
          Log.info(
            '📝 Using existing background upload: ${pendingUpload.id}',
            category: LogCategory.video,
          );
        } else {
          // Background upload not ready, start new upload
          pendingUpload = await _startNewUpload(uploadManager, pubkey, draft);
        }
      } else {
        // No background upload, start new upload
        pendingUpload = await _startNewUpload(uploadManager, pubkey, draft);
      }

      // Publish Nostr event
      Log.info('📝 Publishing Nostr event...', category: LogCategory.video);

      _setPublishState(.publishToNostr);

      final published = await videoEventPublisher.publishVideoEvent(
        upload: pendingUpload,
        title: draft.title,
        description: draft.description,
        hashtags: draft.hashtags,
        expirationTimestamp: draft.expireTime != null
            ? DateTime.now().millisecondsSinceEpoch ~/ 1000 +
                  draft.expireTime!.inSeconds
            : null,
        allowAudioReuse: draft.allowAudioReuse,
      );

      if (!published) {
        throw Exception('Failed to publish Nostr event');
      }

      Log.info(
        '📝 Video publishing complete, deleting draft and returning to main screen',
        category: LogCategory.video,
      );

      // Success: delete draft
      await draftService.deleteDraft(draft.id);

      // Clean up temporary provider data
      ref.read(videoRecorderProvider.notifier).reset();
      ref.read(videoEditorProvider.notifier).reset();
      ref.read(clipManagerProvider.notifier).clearAll();
      ref.read(selectedSoundProvider.notifier).clear();

      Log.info(
        '📝 Published successfully, returned to main screen',
        category: LogCategory.video,
      );
    } catch (e, stackTrace) {
      _setPublishState(.error);
      await _handleUploadError(e, stackTrace, draft);
    }
  }

  void _setPublishState(VideoPublishState state) {
    ref?.read(videoPublishProvider.notifier).setPublishState(state);
  }

  Future<void> _handleActiveUpload({
    required Ref ref,
    required BuildContext context,
    required VineDraft draft,
  }) async {
    final uploadManager = ref.read(uploadManagerProvider);
    final upload = uploadManager.getUpload(_backgroundUploadId!);

    if (upload != null) {
      // Handle different upload states
      if (upload.status == .uploading || upload.status == .processing) {
        // Show blocking progress dialog and wait for upload to complete
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => UploadProgressDialog(
            uploadId: _backgroundUploadId!,
            uploadManager: uploadManager,
          ),
        );

        // After dialog closes, check if upload succeeded
        final completedUpload = uploadManager.getUpload(_backgroundUploadId!);
        if (completedUpload == null || completedUpload.status == .failed) {
          // Upload failed during progress dialog
          await _showUploadErrorDialog();
          return;
        }
      } else if (upload.status == UploadStatus.failed) {
        // Show error dialog with retry
        final shouldRetry = await _showUploadErrorDialog();
        if (shouldRetry && ref.mounted) {
          await _retryUpload();
          // Recursively call _publishVideo after retry to check status again
          return publishVideo(draft: draft, ref: ref, context: context);
        } else {
          return; // User cancelled
        }
      }
      // If status is readyToPublish, proceed with Nostr event
    }
  }

  /// Start a new upload and poll for progress
  Future<PendingUpload> _startNewUpload(
    UploadManager uploadManager,
    String pubkey,
    VineDraft draft,
  ) async {
    // Ensure upload manager is initialized
    if (!uploadManager.isInitialized) {
      Log.info(
        '📝 Initializing upload manager...',
        category: LogCategory.video,
      );
      _setPublishState(.initialize);

      await uploadManager.initialize();
    }

    // Start upload to Blossom
    Log.info(
      '📝 Starting upload to Blossom server...',
      category: LogCategory.video,
    );

    // Debug: Check if draft has ProofMode data
    final hasProofMode = draft.hasProofMode;
    final nativeProof = draft.nativeProof;
    Log.info(
      '📜 Draft hasProofMode: $hasProofMode, nativeProof: ${nativeProof != null ? "present" : "null"}',
      category: LogCategory.video,
    );
    if (hasProofMode && nativeProof == null) {
      Log.error(
        '📜 WARNING: Draft has proofManifestJson but nativeProof getter returned null - deserialization failed!',
        category: LogCategory.video,
      );
    }
    if (nativeProof != null) {
      Log.info(
        '📜 NativeProof videoHash: ${nativeProof.videoHash}, deviceAttestation: ${nativeProof.deviceAttestation != null}, pgpSignature: ${nativeProof.pgpSignature != null}',
        category: LogCategory.video,
      );
    }

    _setPublishState(.uploading);

    // Get video duration with fallback
    final pendingUpload = await uploadManager.startUploadFromDraft(
      draft: draft,
      nostrPubkey: pubkey,
    );
    _backgroundUploadId = pendingUpload.id;

    // Poll for upload progress
    while (ref != null && ref!.mounted) {
      final upload = uploadManager.getUpload(pendingUpload.id);
      if (upload == null) break;

      final progress = upload.uploadProgress ?? 0.0;
      if (ref != null && ref!.mounted) {
        ref?.read(videoPublishProvider.notifier).setUploadProgress(progress);
      }

      // If upload is complete or failed, stop polling
      if (upload.status == .readyToPublish ||
          upload.status == .failed ||
          upload.status == .processing) {
        break;
      }

      await Future.delayed(const Duration(milliseconds: 100));
    }

    return pendingUpload;
  }

  /// Retry a failed upload
  Future<void> _retryUpload() async {
    if (_backgroundUploadId == null || ref == null) return;

    final uploadManager = ref!.read(uploadManagerProvider);

    _setPublishState(.retryUpload);

    try {
      await uploadManager.retryUpload(_backgroundUploadId!);

      // Show progress dialog while retrying
      if (context != null && context!.mounted) {
        await showDialog(
          context: context!,
          barrierDismissible: false,
          builder: (_) => UploadProgressDialog(
            uploadId: _backgroundUploadId!,
            uploadManager: uploadManager,
          ),
        );
      }
    } catch (e) {
      Log.error('📝 Failed to retry upload: $e', category: LogCategory.video);

      rethrow;
    } finally {
      _setPublishState(.idle);
    }
  }

  /// Show error dialog when upload has failed
  /// Returns true if user wants to retry, false if cancelled
  Future<bool> _showUploadErrorDialog() async {
    if (ref == null) return false;
    final uploadManager = ref!.read(uploadManagerProvider);
    final upload = _backgroundUploadId != null
        ? uploadManager.getUpload(_backgroundUploadId!)
        : null;

    final errorMessage = upload?.errorMessage ?? 'Unknown error';
    if (context == null || !context!.mounted) return false;

    final result = await showDialog<bool>(
      context: context!,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Upload Failed',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        content: Text(
          'Upload failed: $errorMessage\n\nWould you like to retry?',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(backgroundColor: VineTheme.vineGreen),
            child: const Text('Retry', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  Future<void> _handleUploadError(
    Object? e,
    StackTrace stackTrace,
    VineDraft draft,
  ) async {
    Log.error(
      '📝 VideoPublishService: Failed to publish video: $e',
      category: LogCategory.video,
    );

    // Failed: update draft with error
    try {
      final prefs = await SharedPreferences.getInstance();
      final draftService = DraftStorageService(prefs);

      final failed = draft.copyWith(
        publishStatus: PublishStatus.failed,
        publishError: e.toString(),
        publishAttempts: draft.publishAttempts + 1,
      );
      await draftService.saveDraft(failed);
    } catch (saveError) {
      Log.error(
        '📝 Failed to save error state: $saveError',
        category: LogCategory.video,
      );
    }

    if (context == null || ref == null || !context!.mounted) return;
    // Get the current Blossom server for error message
    final blossomService = ref!.read(blossomUploadServiceProvider);
    String serverName = 'Unknown server';
    try {
      final serverUrl = await blossomService.getBlossomServer();
      if (serverUrl != null && serverUrl.isNotEmpty) {
        // Extract domain from URL for display
        final uri = Uri.tryParse(serverUrl);
        serverName = uri?.host ?? serverUrl;
      }
    } catch (_) {
      // If we can't get the server name, just use the generic message
    }

    // Convert technical error to user-friendly message
    String userMessage;
    if (e.toString().contains('404') || e.toString().contains('not_found')) {
      userMessage =
          'The Blossom media server ($serverName) is not working. You can choose another in your settings.';
    } else if (e.toString().contains('500')) {
      userMessage =
          'The Blossom media server ($serverName) encountered an error. You can choose another in your settings.';
    } else if (e.toString().contains('network') ||
        e.toString().contains('connection')) {
      userMessage =
          'Network error. Please check your connection and try again.';
    } else if (e.toString().contains('Not authenticated')) {
      userMessage = 'Please sign in to publish videos.';
    } else {
      userMessage = 'Failed to publish video. Please try again.';
    }
    if (context == null || !context!.mounted) return;

    ScaffoldMessenger.of(context!).showSnackBar(
      SnackBar(
        content: Text(userMessage),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Details',
          textColor: Colors.white,
          onPressed: () => _showErrorDetails(e, stackTrace, draft),
        ),
      ),
    );
  }

  Future<void> _showErrorDetails(
    Object? e,
    StackTrace stackTrace,
    VineDraft draft,
  ) async {
    // Show technical details in a dialog
    final videoPath = await draft.clips.first.video.safeFilePath();

    final errorDetails =
        '''
Error: ${e.toString()}

Stack Trace:
${stackTrace.toString()}

Operation: Video Upload
Time: ${DateTime.now().toIso8601String()}
Video: ${videoPath}
''';
    if (context == null || !context!.mounted) return;

    await showDialog(
      context: context!,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Row(
          children: [
            const Icon(Icons.bug_report, color: Colors.red),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Error Details',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Please share these details with support:',
                style: TextStyle(
                  color: VineTheme.vineGreen,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[700]!),
                ),
                child: SelectableText(
                  errorDetails,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: errorDetails));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Error details copied to clipboard'),
                    backgroundColor: VineTheme.vineGreen,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            icon: const Icon(Icons.copy, color: VineTheme.vineGreen),
            label: const Text(
              'Copy',
              style: TextStyle(color: VineTheme.vineGreen),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }
}
