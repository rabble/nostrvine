// ABOUTME: Individual video controller providers using proper Riverpod Family pattern
// ABOUTME: Each video gets its own controller with automatic lifecycle management via autoDispose

import 'dart:async';
import 'dart:io' show Platform;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart' show ChangeNotifier, kIsWeb;
import 'package:flutter_riverpod/legacy.dart';
import 'package:video_player/video_player.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:media_cache/media_cache.dart';
import 'package:openvine/services/openvine_media_cache.dart';
import 'package:openvine/services/broken_video_tracker.dart'
    show BrokenVideoTracker;
import 'package:openvine/services/bandwidth_tracker_service.dart';
import 'package:openvine/extensions/video_event_extensions.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:models/models.dart' show VideoEvent;

part 'individual_video_providers.g.dart';

/// Maximum playback duration before looping (6.3 seconds)
/// Videos longer than this will loop back to beginning at this mark
const maxPlaybackDuration = Duration(milliseconds: 6300);

/// Interval for checking playback position (200ms = 5 checks/sec)
/// Balances responsiveness with performance (vs 60 checks/sec for per-frame)
const loopCheckInterval = Duration(milliseconds: 200);

/// Cache for pre-generated auth headers by video ID
/// This allows synchronous header lookup during controller creation
final authHeadersCacheProvider =
    StateProvider<Map<String, Map<String, String>>>((ref) => {});

/// Tracks videos that are retrying after age verification
/// Key: videoId, Value: true if actively retrying
/// Used to:
/// 1. Skip cache on retry (ensure fresh fetch with auth headers)
/// 2. Show loading UI during retry
/// 3. Trigger auto-play after successful retry
final ageVerificationRetryProvider = StateProvider<Map<String, bool>>(
  (ref) => {},
);

/// Cache for fallback video URLs by video ID
/// When a video fails to load from cdn/stream.divine.video, we store a fallback URL
/// to media.divine.video which is tried on the next retry
final fallbackUrlCacheProvider = StateProvider<Map<String, String>>(
  (ref) => {},
);

/// Blossom fallback server URL
const _blossomFallbackServer = 'https://media.divine.video';

/// Tracks controllers that have been scheduled for disposal.
///
/// This is a ChangeNotifier-based tracker that can be updated synchronously
/// from Riverpod lifecycle callbacks (onDispose) without using ref.read(),
/// which is forbidden inside lifecycle methods.
///
/// The tracker is marked synchronously in `ref.onDispose` (before the deferred
/// `controller.dispose()` microtask) so that widgets can check whether the
/// native player is still alive before building [VideoPlayer].
class DisposedControllersTracker extends ChangeNotifier {
  final _ids = <String>{};

  /// Get a copy of the current disposed IDs.
  Set<String> get ids => Set.unmodifiable(_ids);

  /// Mark a controller as disposed. Safe to call from onDispose.
  ///
  /// The ID is added synchronously so [contains] returns true immediately,
  /// but [notifyListeners] is deferred to a microtask to avoid triggering
  /// ChangeNotifierProvider's listener inside a Riverpod lifecycle callback
  /// (which would cause "Cannot use Ref inside life-cycles" assertion).
  void markDisposed(String videoId) {
    if (_ids.add(videoId)) {
      Future.microtask(notifyListeners);
    }
  }

  /// Clear the disposed flag for a video (when creating a fresh controller).
  void clearDisposed(String videoId) {
    if (_ids.remove(videoId)) {
      notifyListeners();
    }
  }

  /// Check if a video controller is disposed.
  bool contains(String videoId) => _ids.contains(videoId);
}

/// Global tracker instance - not a Riverpod provider, so it can be updated
/// synchronously from onDispose callbacks without ref.read().
final disposedControllersTracker = DisposedControllersTracker();

/// Provider for widgets to watch disposed controllers reactively.
/// Wraps the global tracker so widgets can use ref.watch() with select().
final disposedControllersProvider =
    ChangeNotifierProvider<DisposedControllersTracker>(
      (ref) => disposedControllersTracker,
    );

/// Check if a video controller has been scheduled for disposal.
/// Use this before any controller operation to prevent "No active player" crashes.
/// Note: This function is available for widgets but the safe* helpers below
/// are the preferred approach for most use cases.
bool isControllerDisposed(Ref ref, String videoId) {
  return ref.read(disposedControllersProvider).contains(videoId);
}

/// Safe wrapper for async controller operations that may fail after disposal.
/// Returns true if operation succeeded, false if controller was disposed or errored.
Future<bool> safeControllerOperation(
  VideoPlayerController controller,
  String videoId,
  Future<void> Function() operation, {
  String? operationName,
}) async {
  try {
    // Quick sanity check - if not initialized, likely disposed or errored
    if (!controller.value.isInitialized) {
      Log.debug(
        '⏭️ Skipping ${operationName ?? 'operation'} for $videoId - controller not initialized',
        name: 'SafeController',
        category: LogCategory.video,
      );
      return false;
    }
    await operation();
    return true;
  } catch (e) {
    // Catch "No active player with ID" and similar disposal-related errors
    if (_isDisposalError(e)) {
      Log.debug(
        '⏭️ Controller already disposed for $videoId during ${operationName ?? 'operation'}: $e',
        name: 'SafeController',
        category: LogCategory.video,
      );
      return false;
    }
    // Rethrow unexpected errors
    rethrow;
  }
}

/// Safe wrapper for sync controller operations (play/pause/seekTo).
/// These methods return Futures but are often called without await.
/// This helper catches disposal errors gracefully.
Future<bool> safePlay(VideoPlayerController controller, String videoId) {
  return safeControllerOperation(
    controller,
    videoId,
    () => controller.play(),
    operationName: 'play',
  );
}

Future<bool> safePause(VideoPlayerController controller, String videoId) {
  return safeControllerOperation(
    controller,
    videoId,
    () => controller.pause(),
    operationName: 'pause',
  );
}

Future<bool> safeSeekTo(
  VideoPlayerController controller,
  String videoId,
  Duration position,
) {
  return safeControllerOperation(
    controller,
    videoId,
    () => controller.seekTo(position),
    operationName: 'seekTo',
  );
}

/// Check if an error indicates the controller/player has been disposed.
bool _isDisposalError(dynamic e) {
  final errorStr = e.toString().toLowerCase();
  return errorStr.contains('no active player') ||
      errorStr.contains('bad state') ||
      errorStr.contains('disposed') ||
      errorStr.contains('player with id');
}

/// Parameters for video controller creation
class VideoControllerParams {
  const VideoControllerParams({
    required this.videoId,
    required this.videoUrl,
    this.cacheUrl,
    this.videoEvent,
  });

  final String videoId;

  /// URL for playback (may be HLS on Android for codec compatibility)
  final String videoUrl;

  /// URL for caching (original MP4 - HLS can't be cached as single file)
  /// If null, uses videoUrl for caching.
  final String? cacheUrl;

  final dynamic videoEvent; // VideoEvent for enhanced error reporting

  /// Get the URL to use for caching (prefers cacheUrl, falls back to videoUrl)
  String get effectiveCacheUrl => cacheUrl ?? videoUrl;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VideoControllerParams &&
          runtimeType == other.runtimeType &&
          videoId == other.videoId &&
          videoUrl == other.videoUrl;

  @override
  int get hashCode => videoId.hashCode ^ videoUrl.hashCode;

  @override
  String toString() =>
      'VideoControllerParams(videoId: $videoId, videoUrl: $videoUrl, cacheUrl: $cacheUrl, hasEvent: ${videoEvent != null})';
}

/// Loading state for individual videos
class VideoLoadingState {
  const VideoLoadingState({
    required this.videoId,
    required this.isLoading,
    required this.isInitialized,
    required this.hasError,
    this.errorMessage,
  });

  final String videoId;
  final bool isLoading;
  final bool isInitialized;
  final bool hasError;
  final String? errorMessage;

  VideoLoadingState copyWith({
    String? videoId,
    bool? isLoading,
    bool? isInitialized,
    bool? hasError,
    String? errorMessage,
  }) {
    return VideoLoadingState(
      videoId: videoId ?? this.videoId,
      isLoading: isLoading ?? this.isLoading,
      isInitialized: isInitialized ?? this.isInitialized,
      hasError: hasError ?? this.hasError,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VideoLoadingState &&
          runtimeType == other.runtimeType &&
          videoId == other.videoId &&
          isLoading == other.isLoading &&
          isInitialized == other.isInitialized &&
          hasError == other.hasError &&
          errorMessage == other.errorMessage;

  @override
  int get hashCode =>
      Object.hash(videoId, isLoading, isInitialized, hasError, errorMessage);

  @override
  String toString() =>
      'VideoLoadingState(videoId: $videoId, isLoading: $isLoading, isInitialized: $isInitialized, hasError: $hasError, errorMessage: $errorMessage)';
}

/// Provider for individual video controllers with autoDispose
/// Each video gets its own controller instance
@riverpod
VideoPlayerController individualVideoController(
  Ref ref,
  VideoControllerParams params,
) {
  // Riverpod-native lifecycle: keep controller alive with short cache timeout
  // This prevents excessive codec churn during scrolling (creating/disposing controllers rapidly)
  // 15 seconds balances smooth scroll-back with memory safety for 4K videos
  final link = ref.keepAlive();
  Timer? cacheTimer;
  Timer? loopEnforcementTimer;

  // Riverpod lifecycle hooks for idiomatic cache behavior
  ref.onCancel(() {
    // Last listener removed - start cache timeout before disposal
    // Android uses shorter timeout (3s) to prevent MediaCodec accumulation crash
    // iOS/desktop use longer timeout (15s) for smoother scroll-back experience
    // Short timeout prevents OOM with high-resolution videos (4K = ~25MB/frame)
    final timeout = !kIsWeb && Platform.isAndroid
        ? const Duration(seconds: 3)
        : const Duration(seconds: 15);
    cacheTimer = Timer(timeout, () {
      link.close(); // Allow autoDispose after timeout
    });
  });

  ref.onResume(() {
    // New listener added - cancel the disposal timer
    cacheTimer?.cancel();
  });

  // Clear the disposed flag for this video since we are creating a fresh
  // controller (handles retries and scroll-back scenarios).
  // Uses global tracker directly - safe and avoids ref.read() issues.
  disposedControllersTracker.clearDisposed(params.videoId);

  Log.info(
    '🎬 Creating VideoPlayerController for video ${params.videoId.length > 8 ? params.videoId : params.videoId}...',
    name: 'IndividualVideoController',
    category: LogCategory.system,
  );

  // Check for fallback URL (set when previous attempt failed with 404/network error)
  final fallbackCache = ref.read(fallbackUrlCacheProvider);
  String videoUrl = fallbackCache[params.videoId] ?? params.videoUrl;

  if (fallbackCache.containsKey(params.videoId)) {
    Log.info(
      '🔄 Using fallback URL for video ${params.videoId}: $videoUrl',
      name: 'IndividualVideoController',
      category: LogCategory.video,
    );
  }

  // Normalize .bin URLs by replacing extension based on MIME type from event metadata
  // CDN serves files based on hash, not extension, so we can safely rewrite for player compatibility
  if (videoUrl.toLowerCase().endsWith('.bin') && params.videoEvent != null) {
    final videoEvent = params.videoEvent as dynamic;
    final mimeType = videoEvent.mimeType as String?;

    if (mimeType != null) {
      String? newExtension;
      if (mimeType.contains('webm')) {
        newExtension = '.webm';
      } else if (mimeType.contains('mp4')) {
        newExtension = '.mp4';
      }

      if (newExtension != null) {
        videoUrl = videoUrl.substring(0, videoUrl.length - 4) + newExtension;
        Log.debug(
          '🔧 Normalized .bin URL based on MIME type $mimeType: $newExtension',
          name: 'IndividualVideoController',
          category: LogCategory.video,
        );
      }
    }
  }

  final VideoPlayerController controller;

  final isAgeVerificationRetry =
      ref.read(ageVerificationRetryProvider)[params.videoId] ?? false;
  if (isAgeVerificationRetry) {
    Log.info(
      '🔐 [AGE-RETRY] Detected age verification retry for video ${params.videoId} - will skip cache',
      name: 'IndividualVideoController',
      category: LogCategory.video,
    );
  }

  // On web, skip file caching entirely and always use network URL
  if (kIsWeb) {
    Log.debug(
      '🌐 Web platform - using NETWORK URL for video ${params.videoId.length > 8 ? params.videoId : params.videoId}...',
      name: 'IndividualVideoController',
      category: LogCategory.video,
    );

    // Compute auth headers synchronously if possible
    final authHeaders = _computeAuthHeadersSync(ref, params);

    controller = VideoPlayerController.networkUrl(
      Uri.parse(videoUrl),
      httpHeaders: authHeaders ?? {},
    );
  } else {
    // On native platforms, use file caching
    final videoCache = ref.read(mediaCacheProvider);

    // Synchronous cache check - use getCachedFileSync() which checks file existence without async
    final cachedFile = isAgeVerificationRetry
        ? null
        : videoCache.getCachedFileSync(params.videoId);

    if (cachedFile != null && cachedFile.existsSync()) {
      // Use cached file!
      Log.info(
        '✅ Using CACHED FILE for video ${params.videoId.length > 8 ? params.videoId : params.videoId}...: ${cachedFile.path}',
        name: 'IndividualVideoController',
        category: LogCategory.video,
      );
      controller = VideoPlayerController.file(cachedFile);
    } else {
      // Use network URL and start caching
      Log.debug(
        '📡 Using NETWORK URL for video ${params.videoId.length > 8 ? params.videoId : params.videoId}...',
        name: 'IndividualVideoController',
        category: LogCategory.video,
      );

      // Compute auth headers synchronously if possible
      final authHeaders = _computeAuthHeadersSync(ref, params);

      controller = VideoPlayerController.networkUrl(
        Uri.parse(videoUrl),
        httpHeaders: authHeaders ?? {},
      );

      // Start caching in background for future use
      unawaited(
        _cacheVideoWithAuth(ref, videoCache, params).catchError((error) {
          Log.warning(
            '⚠️ Background video caching failed: $error',
            name: 'IndividualVideoController',
            category: LogCategory.video,
          );
          return null;
        }),
      );
    }
  }

  // Initialize the controller (async in background)
  // Timeout depends on video format:
  // - HLS (.m3u8): 60 seconds - needs to download manifest + buffer segments
  // - Direct MP4: 30 seconds - single file download
  // Previous 15-second timeout was too aggressive for cellular/slow networks
  final isHls =
      params.videoUrl.toLowerCase().contains('.m3u8') ||
      params.videoUrl.toLowerCase().contains('hls');
  final timeoutDuration = isHls
      ? const Duration(seconds: 60)
      : const Duration(seconds: 30);
  final formatType = isHls ? 'HLS' : 'MP4';

  // Track significant video state changes only (initialization, errors, buffering)
  // Previous state tracking to avoid logging every frame update
  bool? _lastIsInitialized;
  bool? _lastIsBuffering;
  bool? _lastHasError;

  void stateChangeListener() {
    // Guard against platform callbacks firing after player disposal.
    // AVFoundation/ExoPlayer may fire async callbacks after the Dart-side
    // controller is invalidated via Riverpod, causing "No active player" errors.
    final VideoPlayerValue value;
    try {
      value = controller.value;
    } catch (e) {
      if (_isDisposalError(e)) return;
      rethrow;
    }

    // Only log significant state changes, not every position update
    final isInitialized = value.isInitialized;
    final isBuffering = value.isBuffering;
    final hasError = value.hasError;

    // Log only when significant state changes occur
    if (isInitialized != _lastIsInitialized ||
        isBuffering != _lastIsBuffering ||
        hasError != _lastHasError) {
      final position = value.position;
      final duration = value.duration;
      final buffered = value.buffered.isNotEmpty
          ? value.buffered.last.end
          : Duration.zero;

      Log.debug(
        '🎬 VIDEO STATE CHANGE [${params.videoId}]:\n'
        '   • Position: ${position.inMilliseconds}ms / ${duration.inMilliseconds}ms\n'
        '   • Buffered: ${buffered.inMilliseconds}ms\n'
        '   • Initialized: $isInitialized\n'
        '   • Playing: ${value.isPlaying}\n'
        '   • Buffering: $isBuffering\n'
        '   • Size: ${value.size.width.toInt()}x${value.size.height.toInt()}\n'
        '   • HasError: $hasError',
        name: 'IndividualVideoController',
        category: LogCategory.video,
      );

      _lastIsInitialized = isInitialized;
      _lastIsBuffering = isBuffering;
      _lastHasError = hasError;
    }
  }

  controller.addListener(stateChangeListener);

  // Initialize with automatic retry for transient failures (CoreMedia errors, byte range issues)
  // Retry up to 2 times (3 attempts total) with 500ms delay between attempts
  Future<void> initializeWithRetry() async {
    const maxAttempts = 3;
    const retryDelay = Duration(milliseconds: 500);

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        await controller.initialize().timeout(
          timeoutDuration,
          onTimeout: () => throw TimeoutException(
            'Video initialization timed out after ${timeoutDuration.inSeconds} seconds ($formatType format)',
          ),
        );
        // Success! Exit retry loop
        if (attempt > 1) {
          Log.info(
            '✅ Video ${params.videoId} initialized successfully on attempt $attempt',
            name: 'IndividualVideoController',
            category: LogCategory.video,
          );
        }
        return;
      } catch (error) {
        final errorStr = error.toString().toLowerCase();
        final isRetryable =
            errorStr.contains('byte range') ||
            errorStr.contains('coremediaerrordomain') ||
            errorStr.contains('network') ||
            errorStr.contains('connection');

        if (isRetryable && attempt < maxAttempts) {
          Log.warning(
            '⚠️ Video ${params.videoId} initialization attempt $attempt failed (retryable): $error',
            name: 'IndividualVideoController',
            category: LogCategory.video,
          );
          await Future.delayed(retryDelay);
          // Continue to next attempt
        } else {
          // Non-retryable error or max attempts reached - rethrow
          if (attempt == maxAttempts) {
            Log.error(
              '❌ Video ${params.videoId} initialization failed after $maxAttempts attempts',
              name: 'IndividualVideoController',
              category: LogCategory.video,
            );
          }
          rethrow;
        }
      }
    }
  }

  // Track time-to-first-frame for bandwidth-based quality selection
  final initStartTime = DateTime.now();

  final initFuture = initializeWithRetry();

  initFuture
      .then((_) {
        // Record time-to-first-frame for bandwidth tracking
        // This helps select appropriate quality (720p vs 480p) for future videos
        final ttffMs = DateTime.now().difference(initStartTime).inMilliseconds;
        if (ttffMs > 0) {
          bandwidthTracker.recordTimeToFirstFrame(ttffMs);
          Log.debug(
            '📊 Recorded TTFF: ${ttffMs}ms for bandwidth tracking',
            name: 'IndividualVideoController',
            category: LogCategory.video,
          );
        }

        final initialPosition = controller.value.position;
        final initialSize = controller.value.size;

        Log.info(
          '✅ VideoPlayerController initialized for video ${params.videoId.length > 8 ? params.videoId : params.videoId}...\n'
          '   • Initial position: ${initialPosition.inMilliseconds}ms\n'
          '   • Duration: ${controller.value.duration.inMilliseconds}ms\n'
          '   • Size: ${initialSize.width.toInt()}x${initialSize.height.toInt()}\n'
          '   • Buffered: ${controller.value.buffered.isNotEmpty ? controller.value.buffered.last.end.inMilliseconds : 0}ms',
          name: 'IndividualVideoController',
          category: LogCategory.system,
        );

        if (isAgeVerificationRetry) {
          Log.info(
            '🔐 [AGE-RETRY] ✅ Age verification retry successful for video ${params.videoId}',
            name: 'IndividualVideoController',
            category: LogCategory.video,
          );
          // Wrap in try-catch to avoid "Cannot use Ref inside life-cycles" crashes
          // when this callback runs during provider disposal from keepAlive timer
          try {
            ref.read(ageVerificationRetryProvider.notifier).update((state) {
              final newState = {...state};
              newState.remove(params.videoId);
              return newState;
            });
          } catch (e) {
            Log.debug(
              '⚠️ Could not clear age verification retry flag: $e',
              name: 'IndividualVideoController',
              category: LogCategory.video,
            );
          }
        }

        // Set looping for Vine-like behavior
        controller.setLooping(true);

        // Start loop enforcement timer for videos longer than 6.3s
        // Short videos use native looping; long videos get enforced loop at 6.3s
        final videoDuration = controller.value.duration;
        if (videoDuration > maxPlaybackDuration) {
          loopEnforcementTimer = Timer.periodic(loopCheckInterval, (timer) {
            // Skip check if video is paused
            if (!controller.value.isPlaying) return;

            // Enforce loop at 6.3s mark
            if (controller.value.position >= maxPlaybackDuration) {
              safeSeekTo(controller, params.videoId, Duration.zero);
            }
          });
          Log.info(
            '⏱️ Started loop enforcement timer for ${params.videoId} (duration: ${videoDuration.inMilliseconds}ms > ${maxPlaybackDuration.inMilliseconds}ms)',
            name: 'LoopEnforcement',
            category: LogCategory.video,
          );
        }

        // CRITICAL DEBUG: Check if video is starting at position 0
        if (initialPosition.inMilliseconds > 0) {
          Log.warning(
            '⚠️ VIDEO NOT AT START! Video ${params.videoId} initialized at ${initialPosition.inMilliseconds}ms instead of 0ms',
            name: 'IndividualVideoController',
            category: LogCategory.video,
          );

          // Try to seek to beginning
          controller
              .seekTo(Duration.zero)
              .then((_) {
                Log.info(
                  '🔄 Seeked video ${params.videoId} back to start (was at ${initialPosition.inMilliseconds}ms)',
                  name: 'IndividualVideoController',
                  category: LogCategory.video,
                );
              })
              .catchError((e) {
                Log.error(
                  '❌ Failed to seek video ${params.videoId} to start: $e',
                  name: 'IndividualVideoController',
                  category: LogCategory.video,
                );
              });
        }

        // Controller is initialized and paused - widget will control playback
        Log.debug(
          '⏸️ Video ${params.videoId.length > 8 ? params.videoId : params.videoId}... initialized and paused (widget controls playback)',
          name: 'IndividualVideoController',
          category: LogCategory.system,
        );
      })
      .catchError((error) {
        final videoIdDisplay = params.videoId.length > 8
            ? params.videoId
            : params.videoId;

        if (isAgeVerificationRetry) {
          Log.warning(
            '🔐 [AGE-RETRY] ❌ Age verification retry failed for video ${params.videoId}',
            name: 'IndividualVideoController',
            category: LogCategory.video,
          );
          // Wrap in try-catch to avoid "Cannot use Ref inside life-cycles" crashes
          // when this callback runs during provider disposal from keepAlive timer
          try {
            ref.read(ageVerificationRetryProvider.notifier).update((state) {
              final newState = {...state};
              newState.remove(params.videoId);
              return newState;
            });
          } catch (e) {
            Log.debug(
              '⚠️ Could not clear age verification retry flag: $e',
              name: 'IndividualVideoController',
              category: LogCategory.video,
            );
          }
        }

        // Check if this was a quality variant URL (720p/480p) that failed
        // If so, fall back to original MP4 (params.cacheUrl is always the original)
        final isQualityVariant =
            videoUrl.contains('/720p') || videoUrl.contains('/480p');
        if (isQualityVariant && params.cacheUrl != null) {
          Log.info(
            '📱 Quality variant failed for ${params.videoId} ($videoUrl) - '
            'falling back to original MP4: ${params.cacheUrl}',
            name: 'IndividualVideoController',
            category: LogCategory.video,
          );
          try {
            final currentFallbackCache = ref.read(fallbackUrlCacheProvider);
            if (!currentFallbackCache.containsKey(params.videoId)) {
              final newCache = {...currentFallbackCache};
              newCache[params.videoId] = params.cacheUrl!;
              ref.read(fallbackUrlCacheProvider.notifier).state = newCache;
            }
          } catch (e) {
            Log.debug(
              '⚠️ Could not store quality fallback URL: $e',
              name: 'IndividualVideoController',
              category: LogCategory.video,
            );
          }
          loopEnforcementTimer?.cancel();
          return;
        }

        // Enhanced error logging with full Nostr event details
        final errorMessage = error.toString();
        var logMessage =
            '❌ VideoPlayerController initialization failed for video $videoIdDisplay...: $errorMessage';

        if (params.videoEvent != null) {
          final event = params.videoEvent as dynamic;
          logMessage += '\n📋 Full Nostr Event Details:';
          logMessage += '\n   • Event ID: ${event.id}';
          logMessage += '\n   • Pubkey: ${event.pubkey}';
          logMessage += '\n   • Content: ${event.content}';
          logMessage += '\n   • Video URL: ${event.videoUrl}';
          logMessage += '\n   • Title: ${event.title ?? 'null'}';
          logMessage += '\n   • Duration: ${event.duration ?? 'null'}';
          logMessage += '\n   • Dimensions: ${event.dimensions ?? 'null'}';
          logMessage += '\n   • MIME Type: ${event.mimeType ?? 'null'}';
          logMessage += '\n   • File Size: ${event.fileSize ?? 'null'}';
          logMessage += '\n   • SHA256: ${event.sha256 ?? 'null'}';
          logMessage += '\n   • Thumbnail URL: ${event.thumbnailUrl ?? 'null'}';
          logMessage += '\n   • Hashtags: ${event.hashtags ?? []}';
          logMessage +=
              '\n   • Created At: ${DateTime.fromMillisecondsSinceEpoch(event.createdAt * 1000)}';
          if (event.rawTags != null && event.rawTags.isNotEmpty) {
            logMessage += '\n   • Raw Tags: ${event.rawTags}';
          }
        } else {
          logMessage +=
              '\n⚠️  No Nostr event details available (consider passing videoEvent to VideoControllerParams)';
        }

        // Add Android device info for codec-related errors
        // This helps diagnose hardware decoder issues on specific devices
        if (!kIsWeb && Platform.isAndroid && _isCodecError(errorMessage)) {
          logMessage += '\n📱 Android Device Info (codec error detected):';
          // Device info is async, so we log it separately
          _logAndroidDeviceInfo(params.videoId, errorMessage);
        }

        Log.error(
          logMessage,
          name: 'IndividualVideoController',
          category: LogCategory.system,
        );

        // Check for 401 Unauthorized - likely NSFW content requiring age verification
        if (_is401Error(errorMessage)) {
          Log.warning(
            '🔐 Detected 401 Unauthorized for video $videoIdDisplay... - age verification may be required',
            name: 'IndividualVideoController',
            category: LogCategory.video,
          );

          // Check if user has NOT verified adult content yet
          // Wrap in try-catch because provider may be disposed by the time this error handler runs
          try {
            final ageVerificationService = ref.read(
              ageVerificationServiceProvider,
            );
            if (!ageVerificationService.isAdultContentVerified) {
              Log.info(
                '🔐 User has not verified adult content - need to show verification dialog',
                name: 'IndividualVideoController',
                category: LogCategory.video,
              );
              // Store this video ID in a provider so the widget can show the dialog
              // For now, just log - we'll handle UI in the widget layer
            } else {
              Log.warning(
                '🔐 User has verified but still getting 401 - may be auth header issue',
                name: 'IndividualVideoController',
                category: LogCategory.video,
              );
            }
          } catch (_) {
            // Provider already disposed - ignore since this is just diagnostic logging
          }
        }

        // Check for corrupted cache file (OSStatus error -12848 or "media may be damaged")
        if (_isCacheCorruption(errorMessage) && !kIsWeb) {
          Log.warning(
            '🗑️ Detected corrupted cache for video $videoIdDisplay... - removing and will retry',
            name: 'IndividualVideoController',
            category: LogCategory.video,
          );

          // Cancel loop enforcement timer before invalidating to prevent race condition
          loopEnforcementTimer?.cancel();

          // Remove corrupted cache file - DON'T invalidate from async callback
          // The invalidateSelf() was causing "Cannot use Ref inside life-cycles" crashes
          // when the keepAlive timer fired during disposal. Just remove the cache;
          // user can retry manually or the provider will be recreated on next access.
          unawaited(
            ref
                .read(mediaCacheProvider)
                .removeCachedFile(params.videoId)
                .then((_) {
                  Log.info(
                    '🗑️ Removed corrupted cache for video $videoIdDisplay',
                    name: 'IndividualVideoController',
                    category: LogCategory.video,
                  );
                })
                .catchError((removeError) {
                  Log.error(
                    '❌ Failed to remove corrupted cache: $removeError',
                    name: 'IndividualVideoController',
                    category: LogCategory.video,
                  );
                }),
          );
        } else if (_isCodecError(errorMessage) &&
            !kIsWeb &&
            Platform.isAndroid) {
          // Android codec error - try HLS fallback with H.264 Baseline Profile
          // IMPORTANT: Read all provider state SYNCHRONOUSLY before any async work
          // to avoid "Cannot use Ref inside life-cycles" crashes when keepAlive timer fires
          try {
            final currentFallbackCache = ref.read(fallbackUrlCacheProvider);
            final alreadyUsedFallback = currentFallbackCache.containsKey(
              params.videoId,
            );

            if (!alreadyUsedFallback && params.videoEvent is VideoEvent) {
              // Cast to VideoEvent to use the extension method
              final videoEvent = params.videoEvent as VideoEvent;
              final hlsFallback = videoEvent.getHlsFallbackUrl();

              if (hlsFallback != null) {
                // Store HLS URL as fallback for retry
                final newCache = {...currentFallbackCache};
                newCache[params.videoId] = hlsFallback;
                ref.read(fallbackUrlCacheProvider.notifier).state = newCache;

                Log.info(
                  '📱 Android codec error - stored HLS fallback for retry: $hlsFallback',
                  name: 'IndividualVideoController',
                  category: LogCategory.video,
                );

                // Cancel loop timer - provider will be recreated on next access
                loopEnforcementTimer?.cancel();
                return;
              } else {
                Log.warning(
                  '📱 Android codec error but no HLS fallback available (non-Divine video)',
                  name: 'IndividualVideoController',
                  category: LogCategory.video,
                );
              }
            }
          } catch (e) {
            // Provider may be disposed - ignore since this is error handling
            Log.debug(
              '⚠️ Could not set HLS fallback (provider likely disposed): $e',
              name: 'IndividualVideoController',
              category: LogCategory.video,
            );
          }
        } else if (_isVideoError(errorMessage)) {
          // Check if we can try a fallback URL before marking as broken
          // IMPORTANT: All ref operations must be synchronous and wrapped in try-catch
          // to avoid "Cannot use Ref inside life-cycles" crashes
          try {
            final currentFallbackCache = ref.read(fallbackUrlCacheProvider);
            final alreadyUsedFallback = currentFallbackCache.containsKey(
              params.videoId,
            );

            if (!alreadyUsedFallback) {
              // Try to generate a fallback URL using sha256
              String? sha256;
              if (params.videoEvent != null) {
                final videoEvent = params.videoEvent as dynamic;
                sha256 = videoEvent.sha256 as String?;
              }
              // Also try extracting from URL
              sha256 ??= _extractSha256FromUrl(params.videoUrl);

              if (sha256 != null && sha256.isNotEmpty) {
                // Store fallback URL for retry
                final fallbackUrl = '$_blossomFallbackServer/$sha256';
                final newCache = {...currentFallbackCache};
                newCache[params.videoId] = fallbackUrl;
                ref.read(fallbackUrlCacheProvider.notifier).state = newCache;

                Log.info(
                  '🔄 Stored fallback URL for video $videoIdDisplay: $fallbackUrl',
                  name: 'IndividualVideoController',
                  category: LogCategory.video,
                );
                // Don't mark as broken - let retry use the fallback
                return;
              }
            }

            // No fallback available or already tried - mark video as broken
            // Get tracker synchronously, then mark broken in fire-and-forget manner
            final trackerFuture = ref.read(brokenVideoTrackerProvider.future);
            unawaited(
              trackerFuture
                  .then((tracker) {
                    tracker.markVideoBroken(
                      params.videoId,
                      'Playback initialization failed: $errorMessage',
                    );
                  })
                  .catchError((trackerError) {
                    Log.warning(
                      'Failed to mark video as broken: $trackerError',
                      name: 'IndividualVideoController',
                      category: LogCategory.system,
                    );
                  }),
            );
          } catch (e) {
            // Provider may be disposed - ignore since this is error handling
            Log.debug(
              '⚠️ Could not handle video error (provider likely disposed): $e',
              name: 'IndividualVideoController',
              category: LogCategory.video,
            );
          }
        }
      });

  // AutoDispose: Cleanup controller when provider is disposed
  ref.onDispose(() {
    loopEnforcementTimer?.cancel();
    cacheTimer?.cancel();
    Log.info(
      '🧹 Disposing VideoPlayerController for video ${params.videoId.length > 8 ? params.videoId : params.videoId}...',
      name: 'IndividualVideoController',
      category: LogCategory.system,
    );

    // Remove state change listener before disposal
    controller.removeListener(stateChangeListener);

    // Mark controller as disposed IMMEDIATELY (synchronously) so that
    // any widget that rebuilds before the microtask runs can check this
    // flag and avoid calling VideoPlayer with a stale controller.
    // This prevents the "No active player with ID" crash (Crashlytics issue).
    //
    // Uses global tracker directly instead of ref.read() which is forbidden
    // inside Riverpod lifecycle callbacks (onDispose, onCancel, etc.).
    disposedControllersTracker.markDisposed(params.videoId);

    // Defer controller disposal to avoid triggering listener callbacks during lifecycle
    // This prevents "Cannot use Ref inside life-cycles" errors when listeners try to access providers
    Future.microtask(() {
      // Only dispose if controller exists
      try {
        controller.dispose();
      } catch (e) {
        Log.warning(
          'Failed to dispose controller: $e',
          name: 'IndividualVideoController',
          category: LogCategory.system,
        );
      }
    });
  });

  // NOTE: Play/pause logic has been moved to VideoFeedItem widget
  // The provider only manages controller lifecycle, NOT playback state
  // This ensures videos can only play when widget is mounted and visible

  return controller;
}

/// Extract sha256 hash from a CDN URL path
/// CDN URLs often follow the pattern: https://cdn.domain.com/{sha256hash}
/// Returns null if URL doesn't match expected pattern
String? _extractSha256FromUrl(String url) {
  try {
    final uri = Uri.parse(url);
    final pathSegments = uri.pathSegments;

    // The last path segment is often the sha256 hash
    if (pathSegments.isNotEmpty) {
      final lastSegment = pathSegments.last;
      // SHA256 hashes are 64 hex characters
      // Also handle filenames like "hash.mp4" by stripping extension
      final cleanSegment = lastSegment.split('.').first;
      if (cleanSegment.length == 64 &&
          RegExp(r'^[a-fA-F0-9]+$').hasMatch(cleanSegment)) {
        return cleanSegment.toLowerCase();
      }
    }
    return null;
  } catch (e) {
    return null;
  }
}

/// Compute auth headers synchronously if possible (for VideoPlayerController)
/// Returns cached headers if available, null otherwise
Map<String, String>? _computeAuthHeadersSync(
  Ref ref,
  VideoControllerParams params,
) {
  Log.debug(
    '🔐 [AUTH-SYNC] Computing auth headers for video ${params.videoId}',
    name: 'IndividualVideoController',
    category: LogCategory.video,
  );

  final blossomAuthService = ref.read(blossomAuthServiceProvider);

  // If we can't create headers (not authenticated), return null
  if (!blossomAuthService.canCreateHeaders) {
    Log.debug(
      '🔐 [AUTH-SYNC] Cannot create headers (not authenticated) - returning null',
      name: 'IndividualVideoController',
      category: LogCategory.video,
    );
    return null;
  }

  // Check if we have cached auth headers for this video
  final cache = ref.read(authHeadersCacheProvider);
  final cachedHeaders = cache[params.videoId];

  Log.debug(
    '🔐 [AUTH-SYNC] Cache check: cacheSize=${cache.length}, hasCachedHeaders=${cachedHeaders != null}',
    name: 'IndividualVideoController',
    category: LogCategory.video,
  );

  if (cachedHeaders != null) {
    Log.info(
      '🔐 [AUTH-SYNC] ✅ Using cached auth headers for video ${params.videoId}',
      name: 'IndividualVideoController',
      category: LogCategory.video,
    );
    return cachedHeaders;
  }

  // No cached headers - trigger async generation for next time
  Log.debug(
    '🔐 [AUTH-SYNC] No cached headers found - triggering async generation',
    name: 'IndividualVideoController',
    category: LogCategory.video,
  );
  unawaited(_generateAuthHeadersAsync(ref, params));

  // Return null for now - first load may fail with 401
  // but the error overlay retry will have cached headers available
  return null;
}

/// Generate auth headers asynchronously and cache them for future use
Future<void> _generateAuthHeadersAsync(
  Ref ref,
  VideoControllerParams params,
) async {
  try {
    final blossomAuthService = ref.read(blossomAuthServiceProvider);

    // Try to get sha256 from video event first
    String? sha256;
    if (params.videoEvent != null) {
      final videoEvent = params.videoEvent as dynamic;
      sha256 = videoEvent.sha256 as String?;
    }

    // If no sha256 in event, try to extract from URL
    // CDN URLs often have format: https://cdn.domain.com/{sha256hash}
    if (sha256 == null || sha256.isEmpty) {
      sha256 = _extractSha256FromUrl(params.videoUrl);
      if (sha256 != null) {
        Log.debug(
          '🔐 Extracted sha256 from URL: ${sha256.substring(0, 8)}...',
          name: 'IndividualVideoController',
          category: LogCategory.video,
        );
      }
    }

    if (sha256 == null || sha256.isEmpty) {
      Log.debug(
        '🔐 No sha256 available for video ${params.videoId} - cannot generate auth header',
        name: 'IndividualVideoController',
        category: LogCategory.video,
      );
      return;
    }

    // Extract server URL from video URL
    String? serverUrl;
    try {
      final uri = Uri.parse(params.videoUrl);
      serverUrl = '${uri.scheme}://${uri.host}';
    } catch (e) {
      Log.warning(
        'Failed to parse video URL for server: $e',
        name: 'IndividualVideoController',
        category: LogCategory.video,
      );
      return;
    }

    // Generate auth header
    final authHeader = await blossomAuthService.createGetAuthHeader(
      sha256Hash: sha256,
      serverUrl: serverUrl,
    );

    if (authHeader != null) {
      // Cache the header for future use
      final cache = {...ref.read(authHeadersCacheProvider)};
      cache[params.videoId] = {'Authorization': authHeader};
      ref.read(authHeadersCacheProvider.notifier).state = cache;

      Log.info(
        '✅ Cached auth header for video ${params.videoId}',
        name: 'IndividualVideoController',
        category: LogCategory.video,
      );
    }
  } catch (error) {
    Log.debug(
      'Failed to generate auth headers: $error',
      name: 'IndividualVideoController',
      category: LogCategory.video,
    );
  }
}

/// Cache video with authentication if needed for NSFW content
Future<dynamic> _cacheVideoWithAuth(
  Ref ref,
  MediaCacheManager videoCache,
  VideoControllerParams params,
) async {
  // Get tracker for broken video handling (used at call site for error reporting)
  BrokenVideoTracker? tracker;
  try {
    tracker = await ref.read(brokenVideoTrackerProvider.future);
  } catch (e) {
    Log.warning(
      'Failed to get BrokenVideoTracker: $e',
      name: 'IndividualVideoController',
      category: LogCategory.video,
    );
  }

  // Check if we should add auth headers
  Map<String, String>? authHeaders;

  final blossomAuthService = ref.read(blossomAuthServiceProvider);

  Log.debug(
    '🔐 Auth check: canCreate=${blossomAuthService.canCreateHeaders}',
    name: 'IndividualVideoController',
    category: LogCategory.video,
  );

  // If user is authenticated, create auth header for all CDN requests
  if (blossomAuthService.canCreateHeaders) {
    // Try to get sha256 from video event first
    String? sha256;
    if (params.videoEvent != null) {
      final videoEvent = params.videoEvent as dynamic;
      sha256 = videoEvent.sha256 as String?;
    }

    // If no sha256 in event, try to extract from URL
    if (sha256 == null || sha256.isEmpty) {
      sha256 = _extractSha256FromUrl(params.videoUrl);
    }

    Log.debug(
      '🔐 Video sha256: ${sha256 != null ? '${sha256.substring(0, 8)}...' : 'null'}',
      name: 'IndividualVideoController',
      category: LogCategory.video,
    );

    if (sha256 != null && sha256.isNotEmpty) {
      Log.debug(
        '🔐 Creating Blossom auth header for video cache request',
        name: 'IndividualVideoController',
        category: LogCategory.video,
      );

      // Extract server URL from video URL for auth
      String? serverUrl;
      try {
        final uri = Uri.parse(params.videoUrl);
        serverUrl = '${uri.scheme}://${uri.host}';
      } catch (e) {
        Log.warning(
          'Failed to parse video URL for server: $e',
          name: 'IndividualVideoController',
          category: LogCategory.video,
        );
      }

      final authHeader = await blossomAuthService.createGetAuthHeader(
        sha256Hash: sha256,
        serverUrl: serverUrl,
      );

      if (authHeader != null) {
        authHeaders = {'Authorization': authHeader};
        Log.info(
          '✅ Added Blossom auth header for video cache',
          name: 'IndividualVideoController',
          category: LogCategory.video,
        );
      }
    }
  }

  // Cache video with optional auth headers
  // Use effectiveCacheUrl (original MP4) not videoUrl (may be HLS on Android)
  // HLS manifests can't be cached as single files
  try {
    return await videoCache.cacheFile(
      params.effectiveCacheUrl,
      key: params.videoId,
      authHeaders: authHeaders,
    );
  } catch (e) {
    // If caching fails, mark video as broken for future reference
    if (tracker != null) {
      tracker.markVideoBroken(params.videoId, 'Cache download failed: $e');
    }
    rethrow;
  }
}

/// Check if error indicates a 401 Unauthorized (likely NSFW content)
bool _is401Error(String errorMessage) {
  final lowerError = errorMessage.toLowerCase();
  return lowerError.contains('401') ||
      lowerError.contains('unauthorized') ||
      lowerError.contains('invalid statuscode: 401');
}

/// Check if error indicates a corrupted cache file
bool _isCacheCorruption(String errorMessage) {
  final lowerError = errorMessage.toLowerCase();
  return lowerError.contains('osstatus error -12848') ||
      lowerError.contains('media may be damaged') ||
      lowerError.contains('cannot open') ||
      (lowerError.contains('failed to load video') &&
          lowerError.contains('damaged'));
}

/// Check if error indicates a broken/non-functional video
bool _isVideoError(String errorMessage) {
  final lowerError = errorMessage.toLowerCase();
  return lowerError.contains('404') ||
      lowerError.contains('not found') ||
      lowerError.contains('invalid statuscode: 404') ||
      lowerError.contains('httpexception') ||
      lowerError.contains('timeout') ||
      lowerError.contains('connection refused') ||
      lowerError.contains('network error') ||
      lowerError.contains('video initialization timed out');
}

/// Check if error indicates Android codec/decoder failure
///
/// These errors typically occur when hardware decoders cannot handle
/// certain video formats (e.g., H.264 High Profile at high resolutions
/// on Motorola, Huawei, OnePlus devices).
bool _isCodecError(String errorMessage) {
  final lowerError = errorMessage.toLowerCase();
  return lowerError.contains('mediacodec') ||
      lowerError.contains('decoder init failed') ||
      lowerError.contains('no_exceeds_capabilities') ||
      lowerError.contains('omx.') ||
      lowerError.contains('format_supported=no') ||
      lowerError.contains('codec') ||
      lowerError.contains('unsupported video format') ||
      lowerError.contains('decoder') ||
      lowerError.contains('video format');
}

/// Log Android device info for codec-related errors
///
/// This helps diagnose which devices have hardware decoder limitations.
Future<void> _logAndroidDeviceInfo(String videoId, String errorMessage) async {
  try {
    final deviceInfo = DeviceInfoPlugin();
    final androidInfo = await deviceInfo.androidInfo;

    final deviceInfoLog =
        '''
📱 Android Device Info for video $videoId:
   • Model: ${androidInfo.model}
   • Manufacturer: ${androidInfo.manufacturer}
   • Android Version: ${androidInfo.version.release}
   • SDK Level: ${androidInfo.version.sdkInt}
   • Brand: ${androidInfo.brand}
   • Device: ${androidInfo.device}
   • Hardware: ${androidInfo.hardware}
   • 64-bit ABIs: ${androidInfo.supported64BitAbis}
   • 32-bit ABIs: ${androidInfo.supported32BitAbis}
   • Error: $errorMessage''';

    Log.warning(
      deviceInfoLog,
      name: 'AndroidCodecDiagnostics',
      category: LogCategory.video,
    );
  } catch (e) {
    Log.warning(
      '📱 Failed to get Android device info: $e',
      name: 'AndroidCodecDiagnostics',
      category: LogCategory.video,
    );
  }
}

/// Provider for video loading state
@riverpod
VideoLoadingState videoLoadingState(Ref ref, VideoControllerParams params) {
  final controller = ref.watch(individualVideoControllerProvider(params));

  if (controller.value.hasError) {
    return VideoLoadingState(
      videoId: params.videoId,
      isLoading: false,
      isInitialized: false,
      hasError: true,
      errorMessage: controller.value.errorDescription,
    );
  }

  if (controller.value.isInitialized) {
    return VideoLoadingState(
      videoId: params.videoId,
      isLoading: false,
      isInitialized: true,
      hasError: false,
    );
  }

  return VideoLoadingState(
    videoId: params.videoId,
    isLoading: true,
    isInitialized: false,
    hasError: false,
  );
}

// NOTE: PrewarmManager removed - using Riverpod-native lifecycle (onCancel/onResume + 15s timeout)
// NOTE: Active video state moved to active_video_provider.dart (route-reactive derived providers)
