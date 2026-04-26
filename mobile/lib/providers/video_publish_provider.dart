// ABOUTME: Riverpod provider for managing video publish screen state
// ABOUTME: Controls playback, mute state, and position tracking

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' show NativeProofData;
import 'package:openvine/blocs/background_publish/background_publish_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/models/video_publish/video_publish_provider_state.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/providers/video_recorder_provider.dart';
import 'package:openvine/router/navigator_keys.dart';
import 'package:openvine/screens/profile_screen_router.dart';
import 'package:openvine/services/cawg_verifier_client.dart';
import 'package:openvine/services/collaborator_invite_service.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:openvine/services/native_proofmode_service.dart';
import 'package:openvine/services/nostr_creator_binding_service.dart';
import 'package:openvine/services/video_editor/video_editor_render_service.dart';
import 'package:openvine/services/video_publish/video_publish_service.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:unified_logger/unified_logger.dart';

/// Provider for video publish screen state management.
final videoPublishProvider =
    NotifierProvider<VideoPublishNotifier, VideoPublishProviderState>(
      VideoPublishNotifier.new,
    );

/// Manages video publish screen state including playback and position.
class VideoPublishNotifier extends Notifier<VideoPublishProviderState> {
  DraftStorageService get _draftService =>
      ref.read(draftStorageServiceProvider);
  CawgVerifierClient get _cawgVerifierClient =>
      ref.read(cawgVerifierClientProvider);

  @override
  VideoPublishProviderState build() {
    return const VideoPublishProviderState();
  }

  /// Social verification remains optional. Prefer OAuth when supported, then
  /// fall back to public proof so publish never depends on a single method.
  @visibleForTesting
  List<VerifierRequiredMethod> preferredSocialVerificationMethods({
    required bool supportsOAuth,
  }) {
    if (supportsOAuth) {
      return const <VerifierRequiredMethod>[
        VerifierRequiredMethod.oauth,
        VerifierRequiredMethod.publicProof,
      ];
    }

    return const <VerifierRequiredMethod>[VerifierRequiredMethod.publicProof];
  }

  /// Fetches optional verifier-issued identity metadata without blocking
  /// creator-binding-only publish.
  Future<VerifierClaimBundle?> fetchOptionalVerifiedIdentity(
    VerifierClaimRequest request,
  ) async {
    final bundle = await _cawgVerifierClient.verifyClaims(request);
    if (bundle != null) {
      return bundle;
    }

    Log.info(
      'Identity verifier unavailable, continuing without CAWG overlay',
      name: 'VideoPublishNotifier',
      category: LogCategory.video,
    );
    return null;
  }

  @visibleForTesting
  bool shouldAttachCreatorIdentityProof(String? proofManifestJson) {
    if (proofManifestJson == null || proofManifestJson.isEmpty) {
      return true;
    }

    try {
      final decoded = jsonDecode(proofManifestJson);
      if (decoded is! Map<String, dynamic>) {
        return true;
      }

      final proofData = NativeProofData.fromJson(decoded);
      return !proofData.hasCreatorIdentityMetadata;
    } catch (_) {
      return true;
    }
  }

  /// Creates the publish service with callbacks wired to this notifier.
  Future<VideoPublishService> _createPublishService({
    required OnProgressChanged onProgressChanged,
  }) async {
    return VideoPublishService(
      uploadManager: ref.read(uploadManagerProvider),
      authService: ref.read(authServiceProvider),
      videoEventPublisher: ref.read(videoEventPublisherProvider),
      blossomService: ref.read(blossomUploadServiceProvider),
      draftService: _draftService,
      collaboratorInviteService: CollaboratorInviteService(
        dmRepository: ref.read(dmRepositoryProvider),
      ),
      languagePreferenceService: ref.read(languagePreferenceServiceProvider),
      onProgressChanged: ({required String draftId, required double progress}) {
        setUploadProgress(draftId: draftId, progress: progress);
        onProgressChanged(draftId: draftId, progress: progress);
      },
    );
  }

  /// Resets all video-related providers.
  ///
  /// Clears recorder, editor, clip manager, and publish state.
  Future<void> clearAll({bool keepAutosavedDraft = false}) async {
    Log.debug(
      '🧹 Clearing all video providers',
      name: 'VideoPublishNotifier',
      category: LogCategory.video,
    );
    try {
      ref.read(videoRecorderProvider.notifier).reset();
      reset();

      await Future.wait([
        ref
            .read(clipManagerProvider.notifier)
            .clearAll(keepAutosavedDraft: keepAutosavedDraft),
        ref
            .read(videoEditorProvider.notifier)
            .reset(keepAutosavedDraft: keepAutosavedDraft),
      ]);
    } catch (error, stackTrace) {
      Log.error(
        '❌ Failed to clear video providers: $error',
        name: 'VideoPublishNotifier',
        category: LogCategory.video,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Resumes any pending publish drafts that were interrupted.
  ///
  /// Called on app startup to query only drafts with `publishing` or `failed`
  /// status and surface them to the user via [BackgroundPublishFailed].
  Future<void> resumePendingPublishes(BuildContext context) async {
    final List<DivineVideoDraft> pendingDrafts;
    try {
      pendingDrafts = await _draftService.getDraftsByPublishStatuses(const {
        PublishStatus.publishing,
        PublishStatus.failed,
      });
    } catch (e) {
      Log.error(
        '❌ Failed to load drafts for pending publish resume: $e',
        name: 'VideoPublishNotifier',
        category: LogCategory.video,
      );
      return;
    }
    if (!context.mounted) return;

    if (pendingDrafts.isEmpty) {
      Log.debug(
        '✅ No pending publish drafts found',
        name: 'VideoPublishNotifier',
        category: LogCategory.video,
      );
      return;
    }

    Log.info(
      '🔄 Found ${pendingDrafts.length} pending publish draft(s), resuming...',
      name: 'VideoPublishNotifier',
      category: LogCategory.video,
    );

    final backgroundPublishBloc = context.read<BackgroundPublishBloc>();

    for (final draft in pendingDrafts) {
      // Check if video file still exists before attempting resume
      if (!kIsWeb && draft.clips.isNotEmpty) {
        try {
          final videoPath = await draft.clips.first.video.safeFilePath();
          final videoFile = File(videoPath);
          if (!videoFile.existsSync()) {
            Log.warning(
              '🗑️ Deleting draft ${draft.id} - video file no longer exists: $videoPath',
              name: 'VideoPublishNotifier',
              category: LogCategory.video,
            );
            await _draftService.deleteDraft(draft.id);
            continue;
          }
        } catch (e) {
          Log.warning(
            '⚠️ Could not verify video file for draft ${draft.id}: $e',
            name: 'VideoPublishNotifier',
            category: LogCategory.video,
          );
          // Delete draft if we can't verify the video
          await _draftService.deleteDraft(draft.id);
          continue;
        }
      }

      Log.info(
        '📤 Surfacing interrupted draft: ${draft.id}',
        name: 'VideoPublishNotifier',
        category: LogCategory.video,
      );

      // TODO(l10n): Replace with context.l10n when localization is added.
      backgroundPublishBloc.add(
        BackgroundPublishFailed(
          draft: draft,
          userMessage:
              draft.publishError ??
              'This upload was interrupted. Would you like to try again?',
        ),
      );
    }
  }

  /// Updates upload progress (0.0 to 1.0).
  void setUploadProgress({required String draftId, required double progress}) {
    state = state.copyWith(uploadProgress: progress);

    if (progress == 0.0 || progress == 1.0 || (progress * 100) % 10 == 0) {
      Log.info(
        '📊 Upload progress: ${(progress * 100).toStringAsFixed(0)}%',
        name: 'VideoPublishNotifier',
        category: .video,
      );
    }
  }

  /// Sets error state with user message.
  void setError(String userMessage) {
    state = state.copyWith(publishState: .error, errorMessage: userMessage);

    Log.error(
      '❌ Publish error: $userMessage',
      name: 'VideoPublishNotifier',
      category: .video,
    );
  }

  /// Clears any error state.
  void clearError() {
    state = state.copyWith(publishState: .idle, errorMessage: '');
  }

  @visibleForTesting
  String collaboratorInviteWarningMessage(int failedCount) {
    final noun = failedCount == 1
        ? '1 collaborator invite did'
        : '$failedCount collaborator invites did';
    return 'Video posted, but $noun not send.';
  }

  /// Publishes the video with ProofMode attestation and navigates to
  /// profile on success.
  Future<void> publishVideo(
    BuildContext context,
    DivineVideoDraft draft,
  ) async {
    // Only block if actively preparing/uploading
    if (state.publishState == .preparing || state.publishState == .uploading) {
      Log.warning(
        '⚠️ Publish already in progress, ignoring duplicate request',
        name: 'VideoPublishNotifier',
        category: .video,
      );
      return;
    }

    state = state.copyWith(publishState: .preparing);

    try {
      Log.info(
        '📝 Starting video publish process',
        name: 'VideoPublishNotifier',
        category: .video,
      );

      DivineVideoClip? finalRenderedClip = draft.finalRenderedClip;
      String? proofManifestJson = draft.proofManifestJson;

      if (finalRenderedClip == null) {
        if (draft.clips.length == 1) {
          finalRenderedClip = draft.clips.first;
        } else {
          // Multiple clips without rendered output - render now
          Log.info(
            '🎬 Rendering ${draft.clips.length} clips for publish',
            name: 'VideoPublishNotifier',
            category: LogCategory.video,
          );

          final parameters = draft.editorEditingParameters.isNotEmpty
              ? CompleteParameters.fromMap(draft.editorEditingParameters)
              : null;

          final result = await VideoEditorRenderService.renderVideoToClip(
            clips: draft.clips,
            parameters: parameters,
            aiTrainingOptOut: ref
                .read(aiTrainingPreferenceServiceProvider)
                .isOptOutEnabled,
            editorStateHistory: draft.editorStateHistory,
          );

          if (result == null) {
            setError('Video rendering failed');
            return;
          }

          final (clip, proofJson) = result;
          finalRenderedClip = clip;
          proofManifestJson = proofJson;

          Log.info(
            '✅ Video rendered successfully for publish',
            name: 'VideoPublishNotifier',
            category: LogCategory.video,
          );
        }
      }

      final aiTrainingOptOut = ref
          .read(aiTrainingPreferenceServiceProvider)
          .isOptOutEnabled;
      if (shouldAttachCreatorIdentityProof(proofManifestJson)) {
        proofManifestJson = await _refreshProofWithCreatorIdentity(
          clip: finalRenderedClip,
          aiTrainingOptOut: aiTrainingOptOut,
          existingProofManifestJson: proofManifestJson,
        );
      }

      final publishDraft = draft.copyWith(
        id:
            '${VideoEditorConstants.publishPrefixId}_'
            '${DateTime.now().microsecondsSinceEpoch}',
        finalRenderedClip: finalRenderedClip,
        proofManifestJson: proofManifestJson,
        publishStatus: PublishStatus.publishing,
        clearPublishError: true,
        publishAttempts: draft.publishAttempts + 1,
      );

      Log.debug(
        '💾 Saving publish draft: ${publishDraft.id}',
        name: 'VideoPublishNotifier',
        category: .video,
      );
      await _draftService.saveDraft(publishDraft);

      // Delete the original draft since we now have the publish draft
      if (!draft.id.startsWith(VideoEditorConstants.publishPrefixId)) {
        Log.debug(
          '🗑️ Deleting original draft: ${draft.id}',
          name: 'VideoPublishNotifier',
          category: .video,
        );
        await _draftService.deleteDraft(draft.id);
      }

      Log.info(
        '📤 Uploading video',
        name: 'VideoPublishNotifier',
        category: .video,
      );

      if (!context.mounted) return;

      final backgroundPublishBloc = context.read<BackgroundPublishBloc>();
      final publishService = await _createPublishService(
        onProgressChanged: ({required draftId, required progress}) {
          backgroundPublishBloc.add(
            BackgroundPublishProgressChanged(
              draftId: draftId,
              progress: progress,
            ),
          );
        },
      );

      final publishmentProcess = publishService.publishVideo(
        draft: publishDraft,
      );
      backgroundPublishBloc.add(
        BackgroundPublishRequested(
          draft: publishDraft,
          publishmentProcess: publishmentProcess,
        ),
      );

      // Navigate to current user's profile
      final authService = ref.read(authServiceProvider);
      final currentNpub = authService.currentNpub;
      if (currentNpub != null && context.mounted) {
        context.go(ProfileScreenRouter.pathForNpub(currentNpub));
        // Clear editor state after navigation animation completes (~350ms)
        // Draft is already saved for background upload
        Future.delayed(const Duration(milliseconds: 600), clearAll);
      }

      final result = await publishmentProcess;

      // Handle result
      switch (result) {
        case PublishSuccess():
          Log.info(
            '🎉 Video published successfully',
            name: 'VideoPublishNotifier',
            category: .video,
          );
          if (result.hasInviteWarnings) {
            _showCollaboratorInviteWarning(
              publishService: publishService,
              warnings: result.inviteWarnings,
            );
          }

        case PublishError(:final userMessage):
          setError(userMessage);
          Log.error(
            '❌ Publish failed: $userMessage',
            name: 'VideoPublishNotifier',
            category: .video,
          );
      }
    } catch (error, stackTrace) {
      Log.error(
        '❌ Failed to publish video: $error',
        name: 'VideoPublishNotifier',
        category: .video,
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      Log.info(
        '🏁 Publish process completed',
        name: 'VideoPublishNotifier',
        category: .video,
      );
    }
  }

  void _showCollaboratorInviteWarning({
    required VideoPublishService publishService,
    required List<CollaboratorInviteWarning> warnings,
  }) {
    final targetContext = NavigatorKeys.root.currentContext;
    if (targetContext == null || !targetContext.mounted) return;

    final messenger = ScaffoldMessenger.maybeOf(targetContext);
    if (messenger == null) return;

    messenger.showSnackBar(
      SnackBar(
        content: Text(collaboratorInviteWarningMessage(warnings.length)),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 8),
        action: SnackBarAction(
          label: 'Retry',
          onPressed: () {
            unawaited(
              _retryCollaboratorInvites(
                messenger: messenger,
                publishService: publishService,
                warnings: warnings,
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _retryCollaboratorInvites({
    required ScaffoldMessengerState messenger,
    required VideoPublishService publishService,
    required List<CollaboratorInviteWarning> warnings,
  }) async {
    final results = await Future.wait(
      warnings.map(publishService.retryCollaboratorInvite),
    );
    final failures = results.where((result) => !result.success).length;
    final message = failures == 0
        ? 'Collaborator invites sent.'
        : collaboratorInviteWarningMessage(failures);
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<String?> _refreshProofWithCreatorIdentity({
    required DivineVideoClip clip,
    required bool aiTrainingOptOut,
    String? existingProofManifestJson,
  }) async {
    final filePath = await clip.video.safeFilePath();

    Log.info(
      '🔐 Generating proof manifest for video',
      name: 'VideoPublishNotifier',
      category: LogCategory.video,
    );

    try {
      final creatorBindingAssertion = await _createCreatorBindingAssertion(
        filePath: filePath,
        aiTrainingOptOut: aiTrainingOptOut,
      );
      if (creatorBindingAssertion == null) {
        return existingProofManifestJson;
      }

      final profile = ref.read(authServiceProvider).currentProfile;
      final claimedNip05 = profile?.nip05;
      VerifierClaimBundle? verifierBundle;
      final verifierRequest = _buildVerifierClaimRequest(
        creatorBindingAssertion: creatorBindingAssertion,
        nip05: claimedNip05,
      );
      if (_hasOptionalVerifierClaims(verifierRequest)) {
        verifierBundle = await fetchOptionalVerifiedIdentity(verifierRequest);
      }

      final proofData = await NativeProofModeService.proofFile(
        File(filePath),
        aiTrainingOptOut: aiTrainingOptOut,
        creatorBindingAssertion: creatorBindingAssertion,
        cawgIdentityAssertion: verifierBundle?.identityAssertionPayload,
        verifiedIdentityBundle: verifierBundle?.toJson(),
      );

      final proofManifestJson = proofData != null
          ? jsonEncode(proofData)
          : null;
      if (proofManifestJson != null) {
        Log.info(
          '✅ Proof manifest generated successfully',
          name: 'VideoPublishNotifier',
          category: LogCategory.video,
        );
        return proofManifestJson;
      }

      Log.warning(
        '⚠️ Proof manifest generation returned null',
        name: 'VideoPublishNotifier',
        category: LogCategory.video,
      );
      return existingProofManifestJson;
    } catch (error, stackTrace) {
      Log.warning(
        'Failed to attach creator identity proof metadata: '
        '$error\n$stackTrace',
        name: 'VideoPublishNotifier',
        category: LogCategory.video,
      );
      return existingProofManifestJson;
    }
  }

  Future<NostrCreatorBindingAssertion?> _createCreatorBindingAssertion({
    required String filePath,
    required bool aiTrainingOptOut,
  }) async {
    try {
      final hardBindingValue =
          await NativeProofModeService.generateSha256FileHash(filePath);
      return await ref
          .read(nostrCreatorBindingServiceProvider)
          .createAssertion(
            claims: _buildCreatorBindingClaims(
              nip05: ref.read(authServiceProvider).currentProfile?.nip05,
            ),
            hardBinding: CreatorBindingHardBinding(
              alg: 'sha256',
              value: hardBindingValue,
            ),
            referencedAssertions: <String>[
              'c2pa.actions.v2',
              if (aiTrainingOptOut) 'cawg.training-mining',
            ],
          );
    } catch (error, stackTrace) {
      Log.warning(
        'Failed to create creator-binding assertion: $error\n$stackTrace',
        name: 'VideoPublishNotifier',
        category: LogCategory.video,
      );
      return null;
    }
  }

  CreatorBindingClaims _buildCreatorBindingClaims({
    String? nip05,
    String? website,
  }) {
    return CreatorBindingClaims(nip05: nip05, website: website);
  }

  VerifierClaimRequest _buildVerifierClaimRequest({
    required NostrCreatorBindingAssertion creatorBindingAssertion,
    String? nip05,
    String? website,
  }) {
    return VerifierClaimRequest(
      pubkey: creatorBindingAssertion.pubkey,
      nip05: nip05,
      website: website,
      creatorBindingAssertionLabel: creatorBindingAssertion.assertionLabel,
      creatorBindingPayloadJson: creatorBindingAssertion.payloadJson,
    );
  }

  bool _hasOptionalVerifierClaims(VerifierClaimRequest request) {
    return request.nip05 != null ||
        request.website != null ||
        request.socialHandles.isNotEmpty;
  }

  /// Resets state to initial values.
  void reset() {
    state = const VideoPublishProviderState();

    Log.info(
      '🔄 Video publish state reset',
      name: 'VideoPublishNotifier',
      category: .video,
    );
  }
}
