// ABOUTME: Intercepts 401 unauthorized media requests and handles viewer authentication
// ABOUTME: Coordinates age verification and signed auth header creation for age-restricted content

import 'package:flutter/material.dart';
import 'package:openvine/models/viewer_auth_result.dart';
import 'package:openvine/services/age_verification_service.dart';
import 'package:openvine/services/content_filter_service.dart';
import 'package:openvine/services/media_viewer_auth_service.dart';
import 'package:unified_logger/unified_logger.dart';

/// Service for intercepting unauthorized media requests and handling authentication flow
class MediaAuthInterceptor {
  MediaAuthInterceptor({
    required AgeVerificationService ageVerificationService,
    required ContentFilterService contentFilterService,
    required MediaViewerAuthService mediaViewerAuthService,
  }) : _ageVerificationService = ageVerificationService,
       _contentFilterService = contentFilterService,
       _mediaViewerAuthService = mediaViewerAuthService;

  final AgeVerificationService _ageVerificationService;
  final ContentFilterService _contentFilterService;
  final MediaViewerAuthService _mediaViewerAuthService;

  /// Whether an age-restricted media surface can retry with viewer auth without
  /// asking the user to verify again.
  ///
  /// `hide` remains a hard block. Verified users with `warn` or `show`
  /// preferences can reuse their existing verification for playback auth.
  bool get shouldAutoAuthorizeAgeRestrictedMedia =>
      _mediaViewerAuthService.canCreateHeaders &&
      _ageVerificationService.isAdultContentVerified &&
      _contentFilterService.adultPlaybackPreference !=
          ContentFilterPreference.hide;

  bool get canAutoAuthorizeAdultMedia => shouldAutoAuthorizeAgeRestrictedMedia;

  /// Creates viewer-auth headers only when the user's existing adult-content
  /// preferences allow automatic playback.
  ///
  /// Unlike [handleUnauthorizedMedia], this never shows an age-verification
  /// dialog. Callers use it for background retries where a surprise prompt would
  /// be worse than leaving the explicit Verify age button on screen.
  Future<ViewerAuthResult> createAutoAuthHeadersForAdultMedia({
    String? sha256Hash,
    String? url,
    String? serverUrl,
  }) async {
    try {
      if (!canAutoAuthorizeAdultMedia) {
        return const ViewerAuthUnavailable();
      }

      Log.debug(
        '✅ Auto-authorizing adult media playback',
        name: 'MediaAuthInterceptor',
        category: LogCategory.system,
      );
      return await _mediaViewerAuthService.createAuthHeaders(
        sha256Hash: sha256Hash,
        url: url,
        serverUrl: serverUrl,
      );
    } catch (e) {
      Log.error(
        'Failed to auto-authorize adult media: $e',
        name: 'MediaAuthInterceptor',
        category: LogCategory.system,
      );
      return const ViewerAuthUnavailable();
    }
  }

  /// Handle 401 unauthorized response from Blossom media server.
  ///
  /// Returns [ViewerAuthAuthorized] with request headers when the viewer can
  /// see adult content, [ViewerAuthSignerUnreachable] when a remote signer
  /// timed out, or [ViewerAuthUnavailable] when the viewer declined / is
  /// blocked by preference / no headers could be created.
  Future<ViewerAuthResult> handleUnauthorizedMedia({
    required BuildContext context,
    String? sha256Hash,
    String? url,
    String? serverUrl,
    String? category,
  }) async {
    try {
      Log.debug(
        '🔐 Handling unauthorized media request for category: ${category ?? "unknown"}',
        name: 'MediaAuthInterceptor',
        category: LogCategory.system,
      );

      final playbackPreference = _contentFilterService.adultPlaybackPreference;

      final isAdultContentVerified =
          _ageVerificationService.isAdultContentVerified;

      // Verified users with all adult categories set to hide should be
      // blocked immediately. Unverified users still go through the existing
      // verify-on-play path below.
      if (isAdultContentVerified &&
          playbackPreference == ContentFilterPreference.hide) {
        Log.debug(
          '🚫 User preference is to never show adult content',
          name: 'MediaAuthInterceptor',
          category: LogCategory.system,
        );
        return const ViewerAuthUnavailable();
      }

      // Once the viewer has completed adult-content age verification, keep that
      // verification durable for playback. `hide` remains a hard block above;
      // `warn` means the category can be surfaced with a warning elsewhere, not
      // that the user must re-verify for every media request.
      if (isAdultContentVerified) {
        Log.debug(
          '✅ Auto-authorizing age-restricted media for verified user',
          name: 'MediaAuthInterceptor',
          category: LogCategory.system,
        );
        return await _mediaViewerAuthService.createAuthHeaders(
          sha256Hash: sha256Hash,
          url: url,
          serverUrl: serverUrl,
        );
      }

      // Default: ask each time - show verification dialog
      Log.debug(
        '❓ Requesting adult content verification from user',
        name: 'MediaAuthInterceptor',
        category: LogCategory.system,
      );

      if (!context.mounted) {
        Log.warning(
          'Context not mounted, cannot show verification dialog',
          name: 'MediaAuthInterceptor',
          category: LogCategory.system,
        );
        return const ViewerAuthUnavailable();
      }

      final verified = await _ageVerificationService.verifyAdultContentAccess(
        context,
      );

      if (!verified) {
        Log.info(
          '❌ User declined adult content verification',
          name: 'MediaAuthInterceptor',
          category: LogCategory.system,
        );
        return const ViewerAuthUnavailable();
      }

      Log.info(
        '✅ User verified adult content access',
        name: 'MediaAuthInterceptor',
        category: LogCategory.system,
      );

      await _contentFilterService.unlockAdultCategories();

      // Create auth header after verification
      return await _mediaViewerAuthService.createAuthHeaders(
        sha256Hash: sha256Hash,
        url: url,
        serverUrl: serverUrl,
      );
    } catch (e) {
      Log.error(
        'Failed to handle unauthorized media: $e',
        name: 'MediaAuthInterceptor',
        category: LogCategory.system,
      );
      return const ViewerAuthUnavailable();
    }
  }

  /// Check if we can create auth headers (user is authenticated with Nostr)
  bool get canCreateAuthHeaders => _mediaViewerAuthService.canCreateHeaders;
}
