// ABOUTME: Upload & media Riverpod providers split from app_providers.dart
// ABOUTME: Blossom upload, media-auth chain, upload manager, API clients, audio playback

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/active_video_provider.dart';
import 'package:openvine/providers/app_foreground_provider.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/moderation_providers.dart';
import 'package:openvine/providers/overlay_visibility_provider.dart';
import 'package:openvine/providers/route_feed_providers.dart';
import 'package:openvine/providers/shell_obscured_provider.dart';
import 'package:openvine/services/api_service.dart';
import 'package:openvine/services/auth_service.dart' hide UserProfile;
import 'package:openvine/services/crosspost_api_client.dart';
import 'package:openvine/services/media_auth_interceptor.dart';
import 'package:openvine/services/media_viewer_auth_service.dart';
import 'package:openvine/services/performance_monitoring_service.dart';
import 'package:openvine/services/upload_manager.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sound_service/sound_service.dart';

part 'upload_media_providers.g.dart';

/// Adapts the app-level [AuthService] to the package-level
/// [BlossomAuthProvider] interface.
class _BlossomAuthAdapter implements BlossomAuthProvider {
  const _BlossomAuthAdapter(this._authService);

  final AuthService _authService;

  @override
  bool get isAuthenticated => _authService.isAuthenticated;

  @override
  Future<BlossomSignedEvent?> createAndSignEvent({
    required int kind,
    required String content,
    required List<List<String>> tags,
  }) async {
    final event = await _authService.createAndSignEvent(
      kind: kind,
      content: content,
      tags: tags,
    );
    if (event == null) return null;
    return BlossomSignedEvent(json: event.toJson());
  }
}

/// Adapts [PerformanceMonitoringService] to the package-level
/// [BlossomPerformanceMonitor] interface.
class _FirebasePerformanceAdapter implements BlossomPerformanceMonitor {
  @override
  Future<void> startTrace(String traceName) =>
      PerformanceMonitoringService.instance.startTrace(traceName);

  @override
  Future<void> stopTrace(String traceName) =>
      PerformanceMonitoringService.instance.stopTrace(traceName);

  @override
  void setMetric(String traceName, String metricName, int value) =>
      PerformanceMonitoringService.instance.setMetric(
        traceName,
        metricName,
        value,
      );
}

/// Blossom BUD-01 authentication service for age-restricted content
@riverpod
BlossomAuthService blossomAuthService(Ref ref) {
  final authService = ref.watch(authServiceProvider);
  return BlossomAuthService(authProvider: _BlossomAuthAdapter(authService));
}

/// Shared viewer auth service for media GET requests.
final mediaViewerAuthServiceProvider = Provider<MediaViewerAuthService>((ref) {
  final authService = ref.watch(authServiceProvider);
  final blossomAuthService = ref.watch(blossomAuthServiceProvider);
  final nip98AuthService = ref.watch(nip98AuthServiceProvider);
  return MediaViewerAuthService(
    authService: authService,
    blossomAuthService: blossomAuthService,
    nip98AuthService: nip98AuthService,
  );
});

/// Media authentication interceptor for handling 401 unauthorized responses
@riverpod
MediaAuthInterceptor mediaAuthInterceptor(Ref ref) {
  final ageVerificationService = ref.watch(ageVerificationServiceProvider);
  final contentFilterService = ref.watch(contentFilterServiceProvider);
  final mediaViewerAuthService = ref.watch(mediaViewerAuthServiceProvider);
  return MediaAuthInterceptor(
    ageVerificationService: ageVerificationService,
    contentFilterService: contentFilterService,
    mediaViewerAuthService: mediaViewerAuthService,
  );
}

/// How long to pause between upload chunks while the home feed is actively
/// streaming video, so the upload yields bandwidth to playback. Applied only
/// while foreground playback is visible.
const _feedStreamingUploadChunkPause = Duration(milliseconds: 750);

/// Whether a foreground video feed is visible enough that uploads should yield
/// bandwidth between chunks.
final uploadBackpressureActiveProvider = Provider<bool>((ref) {
  if (ref.watch(activeVideoIdProvider) != null) return true;

  final isHomeFeedActive =
      ref.watch(appForegroundProvider) &&
      ref.watch(activeBranchIndexProvider) == 0 &&
      !ref.watch(shellObscuredProvider) &&
      !ref.watch(overlayVisibilityProvider).hasVisibleOverlay;
  return isHomeFeedActive;
});

/// Blossom upload service (uses user-configured Blossom server)
@riverpod
BlossomUploadService blossomUploadService(Ref ref) {
  final authService = ref.watch(authServiceProvider);
  final env = ref.read(currentEnvironmentProvider);
  return BlossomUploadService(
    authProvider: _BlossomAuthAdapter(authService),
    performanceMonitor: _FirebasePerformanceAdapter(),
    defaultServerUrl: env.blossomUrl,
    // Backpressure: while a feed video is actively playing in the foreground,
    // pause briefly between chunks so the upload doesn't starve playback on a
    // congested connection. No pause when nothing is streaming.
    betweenChunks: () async {
      if (ref.read(uploadBackpressureActiveProvider)) {
        await Future<void>.delayed(_feedStreamingUploadChunkPause);
      }
    },
  );
}

/// Upload manager uses only Blossom upload service
@Riverpod(keepAlive: true)
UploadManager uploadManager(Ref ref) {
  final blossomService = ref.watch(blossomUploadServiceProvider);
  ref.watch(currentAuthStateProvider);
  final currentPubkey = ref.watch(authServiceProvider).currentPublicKeyHex;
  final env = ref.read(currentEnvironmentProvider);
  final manager = UploadManager(
    blossomService: blossomService,
    defaultBlossomUrl: env.blossomUrl,
    currentNostrPubkey: currentPubkey,
    scopeUploadsToCurrentUser: true,
  );
  ref.onDispose(manager.dispose);
  return manager;
}

/// API service depends on auth service
@riverpod
ApiService apiService(Ref ref) {
  final authService = ref.watch(nip98AuthServiceProvider);
  return ApiService(authService: authService);
}

/// Crosspost API client for Bluesky toggle settings
@riverpod
CrosspostApiClient crosspostApiClient(Ref ref) {
  final oauthClient = ref.watch(oauthClientProvider);
  final config = ref.watch(oauthConfigProvider);
  return CrosspostApiClient(
    oauthClient: oauthClient,
    serverUrl: config.serverUrl,
  );
}

/// Audio playback service for sound playback during recording and preview
///
/// Used by SoundsScreen to preview sounds and by camera screen
/// for lip-sync recording. Handles audio loading, play/pause, and cleanup.
/// Uses keepAlive to persist across the session (not auto-disposed).
@Riverpod(keepAlive: true)
AudioPlaybackService audioPlaybackService(Ref ref) {
  final service = AudioPlaybackService();

  ref.onDispose(() async {
    await service.dispose();
  });

  return service;
}
