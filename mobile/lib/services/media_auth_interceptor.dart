// ABOUTME: Intercepts 401 unauthorized media requests and handles viewer authentication
// ABOUTME: Coordinates age verification and signed auth header creation for age-restricted content

import 'package:flutter/material.dart';
import 'package:openvine/services/age_verification_service.dart';
import 'package:openvine/services/media_viewer_auth_service.dart';
import 'package:unified_logger/unified_logger.dart';

/// Service for intercepting unauthorized media requests and handling authentication flow
class MediaAuthInterceptor {
  MediaAuthInterceptor({
    required AgeVerificationService ageVerificationService,
    required MediaViewerAuthService mediaViewerAuthService,
  }) : _ageVerificationService = ageVerificationService,
       _mediaViewerAuthService = mediaViewerAuthService;

  final AgeVerificationService _ageVerificationService;
  final MediaViewerAuthService _mediaViewerAuthService;

  /// Handle 401 unauthorized response from Blossom media server
  /// Returns request headers if user verifies adult content access, null otherwise
  Future<Map<String, String>?> handleUnauthorizedMedia({
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

      // Check if user has chosen to never show adult content
      if (_ageVerificationService.shouldHideAdultContent) {
        Log.debug(
          '🚫 User preference is to never show adult content',
          name: 'MediaAuthInterceptor',
          category: LogCategory.system,
        );
        return null;
      }

      // Check if user has chosen to always show (and is verified)
      if (_ageVerificationService.shouldAutoShowAdultContent) {
        Log.debug(
          '✅ Auto-showing adult content (user preference: always show)',
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
        return null;
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
        return null;
      }

      Log.info(
        '✅ User verified adult content access',
        name: 'MediaAuthInterceptor',
        category: LogCategory.system,
      );

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
      return null;
    }
  }

  /// Check if we can create auth headers (user is authenticated with Nostr)
  bool get canCreateAuthHeaders => _mediaViewerAuthService.canCreateHeaders;

  /// Returns true if adult content should be filtered from feeds entirely
  bool get shouldFilterContent =>
      _ageVerificationService.shouldHideAdultContent;
}
