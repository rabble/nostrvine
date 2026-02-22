// ABOUTME: Video feed item using individual controller architecture
// ABOUTME: Each video gets its own controller with automatic lifecycle management via Riverpod autoDispose

import 'package:cached_network_image/cached_network_image.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' hide LogCategory, NIP71VideoKinds;
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/extensions/video_event_extensions.dart';
import 'package:openvine/blocs/video_interactions/video_interactions_bloc.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/providers/active_video_provider.dart'; // For isVideoActiveProvider (router-driven)
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/individual_video_providers.dart'; // For individualVideoControllerProvider only
import 'package:openvine/providers/overlay_visibility_provider.dart'; // For hasVisibleOverlayProvider (modal pause/resume)
import 'package:openvine/providers/nip05_verification_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/services/nip05_verification_service.dart';
import 'package:openvine/screens/comments/comments.dart';
import 'package:openvine/screens/other_profile_screen.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/explore_screen.dart';
import 'package:openvine/screens/hashtag_screen_router.dart';
import 'package:openvine/screens/home_screen_router.dart';
import 'package:openvine/screens/liked_videos_screen_router.dart';
import 'package:openvine/screens/notifications_screen.dart';
import 'package:openvine/screens/profile_screen_router.dart';
import 'package:openvine/screens/pure/search_screen_pure.dart';
import 'package:openvine/utils/public_identifier_normalizer.dart';
import 'package:openvine/screens/curated_list_feed_screen.dart';
import 'package:openvine/services/visibility_tracker.dart';
import 'package:openvine/ui/overlay_policy.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/utils/pause_aware_modals.dart';
import 'package:openvine/utils/string_utils.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/badge_explanation_modal.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/clickable_hashtag_text.dart';
import 'package:openvine/widgets/proofmode_badge.dart';
import 'package:openvine/widgets/proofmode_badge_row.dart';
import 'package:openvine/widgets/share_video_menu.dart';
import 'package:openvine/widgets/user_name.dart';
import 'package:openvine/widgets/video_feed_item/actions/actions.dart';
import 'package:openvine/providers/subtitle_providers.dart';
import 'package:openvine/widgets/video_feed_item/audio_attribution_row.dart';
import 'package:openvine/widgets/video_feed_item/collaborator_avatar_row.dart';
import 'package:openvine/widgets/video_feed_item/inspired_by_attribution_row.dart';
import 'package:openvine/widgets/video_feed_item/list_attribution_chip.dart';
import 'package:openvine/widgets/video_feed_item/subtitle_overlay.dart';
import 'package:openvine/widgets/video_feed_item/video_error_overlay.dart';
import 'package:openvine/widgets/video_feed_item/video_follow_button.dart';
import 'package:openvine/widgets/video_metrics_tracker.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../video_thumbnail_widget.dart';

/// Video feed item using individual controller architecture
class VideoFeedItem extends ConsumerStatefulWidget {
  const VideoFeedItem({
    super.key,
    required this.video,
    required this.index,
    this.onTap,
    this.forceShowOverlay = false,
    this.hasBottomNavigation = true,
    this.contextTitle,
    this.disableAutoplay = false,
    this.isActiveOverride,
    this.disableTapNavigation = false,
    this.isFullscreen = false,
    this.listSources,
    this.showListAttribution = false,
    this.hideFollowButtonIfFollowing = false,
  });

  final VideoEvent video;
  final int index;
  final VoidCallback? onTap;
  final bool forceShowOverlay;
  final bool hasBottomNavigation;
  final String? contextTitle;
  final bool disableAutoplay;

  /// When non-null, overrides isVideoActiveProvider for determining active state.
  /// Used for custom contexts (like lists) that don't use URL routing.
  final bool? isActiveOverride;

  /// When true, tapping an inactive video won't navigate via router.
  /// Instead, it just calls onTap callback. Used for contexts with local state management.
  final bool disableTapNavigation;

  /// When true, adds extra top padding to avoid overlapping with fullscreen
  /// back button (e.g., in FullscreenVideoFeedScreen).
  final bool isFullscreen;

  /// Set of curated list IDs this video is from (for list attribution display).
  final Set<String>? listSources;

  /// Whether to show the list attribution chip below the author info.
  final bool showListAttribution;

  /// When true, hides the follow button if already following the author.
  /// Useful for Home feed (all videos are from followed users) and
  /// Profile views of followed users.
  final bool hideFollowButtonIfFollowing;

  @override
  ConsumerState<VideoFeedItem> createState() => _VideoFeedItemState();
}

class _VideoFeedItemState extends ConsumerState<VideoFeedItem> {
  int _playbackGeneration =
      0; // Prevents race conditions with rapid state changes
  DateTime? _lastTapTime; // Debounce rapid taps to prevent phantom pauses
  DateTime?
  _loadingStartTime; // Track when loading started for delayed indicator
  late final VideoInteractionsBloc
  _interactionsBloc; // Per-video interactions bloc

  // State for fading pause button animation
  bool _showFadingPauseButton = false;
  double _pauseButtonOpacity = 1.0;

  // State for double-tap heart animation
  bool _showDoubleTapHeart = false;
  double _heartScale = 0.0;
  double _heartOpacity = 1.0;

  /// Triggers the fading pause button animation.
  /// Shows pause icon that fades from 100% to 0% opacity over 500ms.
  void _triggerPauseButtonFade() {
    setState(() {
      _showFadingPauseButton = true;
      _pauseButtonOpacity = 1.0;
    });

    // Animate opacity to 0 over 500ms using linear animation
    Future.delayed(const Duration(milliseconds: 50), () {
      if (!mounted) return;
      setState(() {
        _pauseButtonOpacity = 0.0;
      });
    });

    // Hide the button completely after animation completes
    Future.delayed(const Duration(milliseconds: 550), () {
      if (!mounted) return;
      setState(() {
        _showFadingPauseButton = false;
        _pauseButtonOpacity = 1.0; // Reset for next use
      });
    });
  }

  /// Triggers the double-tap heart animation.
  /// Shows heart that scales up and fades out over ~1 second.
  void _triggerDoubleTapHeartAnimation() {
    setState(() {
      _showDoubleTapHeart = true;
      _heartScale = 0.0;
      _heartOpacity = 1.0;
    });

    // Scale up quickly
    Future.delayed(const Duration(milliseconds: 50), () {
      if (!mounted) return;
      setState(() => _heartScale = 1.0);
    });

    // Hold, then fade out
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      setState(() => _heartOpacity = 0.0);
    });

    // Hide completely after animation
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (!mounted) return;
      setState(() {
        _showDoubleTapHeart = false;
        _heartScale = 0.0;
        _heartOpacity = 1.0;
      });
    });
  }

  /// Handles double-tap to like. Only likes (never unlikes) per Instagram behavior.
  void _handleDoubleTapLike() {
    final state = _interactionsBloc.state;

    // Only trigger like if not already liked and not in progress
    if (!state.isLiked && !state.isLikeInProgress) {
      _interactionsBloc.add(const VideoInteractionsLikeToggled());
    }

    // Always show heart animation (even if already liked)
    _triggerDoubleTapHeartAnimation();
  }

  /// Stable video identifier for active state tracking
  String get _stableVideoId => widget.video.stableId;

  /// Controller params for the current video
  /// Uses platform-aware URL selection: HLS on Android, MP4 on iOS/macOS
  /// Cache uses original MP4 URL (HLS can't be cached as single file)
  /// Checks fallback URL cache first (set when quality variant fails)
  VideoControllerParams get _controllerParams {
    // Check for fallback URL (stored when quality variant 720p/480p fails)
    final fallbackUrl = ref.read(fallbackUrlCacheProvider)[widget.video.id];
    return VideoControllerParams(
      videoId: widget.video.id,
      videoUrl:
          fallbackUrl ??
          widget.video.getOptimalVideoUrlForPlatform() ??
          widget.video.videoUrl!,
      cacheUrl: widget.video.videoUrl, // Always cache original MP4
      videoEvent: widget.video,
    );
  }

  @override
  void initState() {
    super.initState();

    // Create VideoInteractionsBloc for this video immediately
    // This must happen before build() to ensure the bloc is available
    _createInteractionsBloc();

    // Listen for active state changes to control playback
    // Active state is now derived from URL + feed + foreground (pure provider)
    // OR from isActiveOverride for custom contexts like lists
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return; // Safety check: don't use ref if widget is disposed

      if (widget.disableAutoplay) {
        Log.info(
          '🎬 VideoFeedItem.initState: autoplay disabled for ${widget.video.id}',
          name: 'VideoFeedItem',
          category: LogCategory.video,
        );
        return;
      }

      // Listen for quality variant fallback URL changes (applies to all play modes).
      // When a 720p/480p variant fails, the provider stores a fallback URL.
      // We need to detect this and re-trigger playback with the new controller.
      ref.listenManual(
        fallbackUrlCacheProvider.select((cache) => cache[widget.video.id]),
        (prev, next) {
          if (!mounted) return;
          if (prev == null && next != null) {
            Log.info(
              '🔄 Quality fallback URL detected for ${widget.video.id}, '
              'retriggering playback with original MP4: $next',
              name: 'VideoFeedItem',
              category: LogCategory.video,
            );
            // Use postFrameCallback to ensure the widget has rebuilt with
            // new _controllerParams before we try to play
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              final bool isActive =
                  widget.isActiveOverride == true ||
                  (widget.isActiveOverride == null &&
                      ref.read(isVideoActiveProvider(_stableVideoId)));
              if (isActive) {
                _handlePlaybackChange(true);
              }
            });
          }
        },
      );

      // If using override, handle playback directly without provider listener
      // BUT still listen to overlay visibility for modal pause/resume
      final initialOverride = widget.isActiveOverride;
      if (initialOverride != null) {
        Log.info(
          '🎬 VideoFeedItem.initState: using isActiveOverride=$initialOverride for ${widget.video.id}',
          name: 'VideoFeedItem',
          category: LogCategory.video,
        );

        // Listen to overlay visibility to pause/resume when modals open/close
        ref.listenManual(hasVisibleOverlayProvider, (prev, next) {
          if (!mounted) return;
          // Re-read current override value (may have changed since listener setup)
          final currentOverride = widget.isActiveOverride;
          if (currentOverride == null)
            return; // Widget rebuilt without override
          // Compute effective active state: override must be true AND no overlay visible
          final effectivelyActive = currentOverride && !next;
          Log.info(
            '🔄 VideoFeedItem overlay changed: videoId=${widget.video.id}, hasOverlay=$next, effectivelyActive=$effectivelyActive',
            name: 'VideoFeedItem',
            category: LogCategory.video,
          );
          _handlePlaybackChange(effectivelyActive);
        });

        // Initial play if override is true and no overlay
        final hasOverlay = ref.read(hasVisibleOverlayProvider);
        if (initialOverride && !hasOverlay) {
          _handlePlaybackChange(true);
        }
        return;
      }

      // Set up listener FIRST to avoid missing provider updates during setup
      // Use _stableVideoId (vineId) for active state since event ID changes on metadata updates
      ref.listenManual(isVideoActiveProvider(_stableVideoId), (prev, next) {
        Log.info(
          '🔄 VideoFeedItem active state changed: videoId=$_stableVideoId, prev=$prev → next=$next',
          name: 'VideoFeedItem',
          category: LogCategory.video,
        );
        _handlePlaybackChange(next);
      });

      // Also listen for controller recreation (e.g., after cache corruption retry)
      // When controller is recreated while video is active, re-trigger play setup
      if (widget.video.videoUrl != null) {
        ref.listenManual(
          individualVideoControllerProvider(_controllerParams),
          (previous, next) {
            // Only react to actual controller changes (recreation), not initial emission
            // previous will be null on first emission, non-null on recreation
            if (previous != null && previous != next) {
              Log.info(
                '🔄 Controller recreated for $_stableVideoId, checking if should auto-play',
                name: 'VideoFeedItem',
                category: LogCategory.video,
              );
              final isActive = ref.read(isVideoActiveProvider(_stableVideoId));
              if (isActive) {
                // Re-trigger play setup - this will attach checkAndPlay listener to NEW controller
                _handlePlaybackChange(true);
              }
            }
          },
          // Don't fire immediately - we only care about changes (recreation)
          fireImmediately: false,
        );
      }

      // THEN check current state (providers may have become ready while listener was setting up)
      // This two-step approach handles the race condition where providers might not be ready initially
      // but become ready shortly after widget mounts
      final isActive = ref.read(isVideoActiveProvider(_stableVideoId));
      Log.info(
        '🎬 VideoFeedItem.initState postFrameCallback: videoId=${widget.video.id}, isActive=$isActive',
        name: 'VideoFeedItem',
        category: LogCategory.video,
      );
      if (isActive) {
        _handlePlaybackChange(true);
      }
    });
  }

  @override
  void didUpdateWidget(VideoFeedItem oldWidget) {
    super.didUpdateWidget(oldWidget);

    // React to override changes when parent updates current page
    // This is critical for local state mode (curated lists, etc.)
    if (widget.isActiveOverride != oldWidget.isActiveOverride) {
      Log.info(
        '🔄 VideoFeedItem.didUpdateWidget: override changed from ${oldWidget.isActiveOverride} to ${widget.isActiveOverride} for ${widget.video.id}',
        name: 'VideoFeedItem',
        category: LogCategory.video,
      );
      if (widget.isActiveOverride != null) {
        _handlePlaybackChange(widget.isActiveOverride!);
      }
    }
  }

  /// Creates the VideoInteractionsBloc for this video.
  /// Called synchronously in initState before the first build.
  void _createInteractionsBloc() {
    final likesRepository = ref.read(likesRepositoryProvider);
    final commentsRepository = ref.read(commentsRepositoryProvider);
    final repostsRepository = ref.read(repostsRepositoryProvider);

    // Build addressable ID for reposts if video has a d-tag (vineId)
    final addressableId = widget.video.addressableId;

    _interactionsBloc = VideoInteractionsBloc(
      eventId: widget.video.id,
      authorPubkey: widget.video.pubkey,
      likesRepository: likesRepository,
      commentsRepository: commentsRepository,
      repostsRepository: repostsRepository,
      addressableId: addressableId,
    );
    // Start listening for liked/reposted IDs changes
    _interactionsBloc.add(const VideoInteractionsSubscriptionRequested());
    // Trigger initial fetch
    _interactionsBloc.add(const VideoInteractionsFetchRequested());
  }

  @override
  void dispose() {
    // Close the interactions bloc
    _interactionsBloc.close();

    // Always pause video on dispose - defensive cleanup required because:
    // 1. iOS back gesture may dispose widget before reactive listeners fire
    // 2. Provider cleanup only triggers on route TYPE changes, not videoIndex changes
    // 3. Feed→grid transition stays on same route type (e.g., explore)
    if (widget.video.videoUrl != null) {
      // Directly pause the controller - don't rely on _handlePlaybackChange
      // which might fail if ref is in an inconsistent state during dispose
      // Use safePause to handle "No active player with ID" errors gracefully
      try {
        final controller = ref.read(
          individualVideoControllerProvider(_controllerParams),
        );
        if (controller.value.isInitialized && controller.value.isPlaying) {
          Log.info(
            '⏸️ VideoFeedItem.dispose: pausing video ${widget.video.id}',
            name: 'VideoFeedItem',
            category: LogCategory.video,
          );
          // Use safePause to handle disposed controller gracefully
          safePause(controller, widget.video.id);
        }
      } catch (e) {
        // Log only if not a disposal-related error (those are expected during cleanup)
        final errorStr = e.toString().toLowerCase();
        if (!errorStr.contains('no active player') &&
            !errorStr.contains('bad state') &&
            !errorStr.contains('disposed')) {
          Log.error(
            '❌ VideoFeedItem.dispose: failed to pause ${widget.video.id}: $e',
            name: 'VideoFeedItem',
            category: LogCategory.video,
          );
        }
      }
    }
    super.dispose();
  }

  /// Handle playback state changes with generation counter to prevent race conditions
  void _handlePlaybackChange(bool shouldPlay) {
    final gen = ++_playbackGeneration;

    // Get stack trace to understand why playback is changing
    final stackTrace = StackTrace.current;
    final stackLines = stackTrace.toString().split('\n').take(5).join('\n');

    try {
      final controller = ref.read(
        individualVideoControllerProvider(_controllerParams),
      );

      if (shouldPlay) {
        Log.info(
          '▶️ PLAY REQUEST for video ${widget.video.id} | gen=$gen | initialized=${controller.value.isInitialized} | isPlaying=${controller.value.isPlaying}\nCalled from:\n$stackLines',
          name: 'VideoFeedItem',
          category: LogCategory.video,
        );

        Log.info(
          '🔍 Play condition check: isInitialized=${controller.value.isInitialized}, isPlaying=${controller.value.isPlaying}, hasError=${controller.value.hasError}',
          name: 'VideoFeedItem',
          category: LogCategory.video,
        );

        if (controller.value.isInitialized && !controller.value.isPlaying) {
          final positionBeforePlay = controller.value.position;

          // Controller ready - play immediately
          Log.info(
            '▶️ Widget starting video ${widget.video.id} (controller already initialized)\n'
            '   • Current position before play: ${positionBeforePlay.inMilliseconds}ms\n'
            '   • Duration: ${controller.value.duration.inMilliseconds}ms\n'
            '   • Size: ${controller.value.size.width.toInt()}x${controller.value.size.height.toInt()}',
            name: 'VideoFeedItem',
            category: LogCategory.ui,
          );

          // Use safePlay to handle "No active player with ID" errors gracefully
          safePlay(controller, widget.video.id)
              .then((success) {
                if (success) {
                  final positionAfterPlay = controller.value.position;
                  Log.info(
                    '✅ Video ${widget.video.id} play() completed\n'
                    '   • Position after play: ${positionAfterPlay.inMilliseconds}ms\n'
                    '   • Is playing: ${controller.value.isPlaying}',
                    name: 'VideoFeedItem',
                    category: LogCategory.ui,
                  );
                  if (gen != _playbackGeneration) {
                    Log.debug(
                      '⏭️ Ignoring stale play() completion for ${widget.video.id}',
                      name: 'VideoFeedItem',
                      category: LogCategory.ui,
                    );
                  }
                }
              })
              .catchError((error) {
                if (gen == _playbackGeneration) {
                  Log.error(
                    '❌ Widget failed to play video ${widget.video.id}: $error',
                    name: 'VideoFeedItem',
                    category: LogCategory.ui,
                  );
                }
              });
        } else if (!controller.value.isInitialized &&
            !controller.value.hasError) {
          // Controller not ready yet - wait for initialization then play
          Log.debug(
            '⏳ Waiting for initialization of ${widget.video.id} before playing',
            name: 'VideoFeedItem',
            category: LogCategory.ui,
          );

          void checkAndPlay() {
            // Safety check: don't use ref if widget is disposed
            if (!mounted) {
              Log.debug(
                '⏭️ Ignoring initialization callback for ${widget.video.id} (widget disposed)',
                name: 'VideoFeedItem',
                category: LogCategory.ui,
              );
              controller.removeListener(checkAndPlay);
              return;
            }

            // Check if video is still active (even if generation changed)
            // Use isActiveOverride if set (for self-managed screens like FullscreenVideoFeedScreen)
            final bool stillActive =
                widget.isActiveOverride ??
                ref.read(isVideoActiveProvider(_stableVideoId));

            if (!stillActive) {
              // Video no longer active, don't play
              Log.debug(
                '⏭️ Ignoring initialization callback for ${widget.video.id} (no longer active)',
                name: 'VideoFeedItem',
                category: LogCategory.ui,
              );
              controller.removeListener(checkAndPlay);
              return;
            }

            if (gen != _playbackGeneration) {
              // Generation changed but video still active - this can happen if state toggled quickly
              Log.debug(
                '⏭️ Ignoring stale initialization callback for ${widget.video.id} (generation mismatch)',
                name: 'VideoFeedItem',
                category: LogCategory.ui,
              );
              controller.removeListener(checkAndPlay);
              return;
            }

            if (controller.value.isInitialized && !controller.value.isPlaying) {
              Log.info(
                '▶️ Widget starting video ${widget.video.id} after initialization',
                name: 'VideoFeedItem',
                category: LogCategory.ui,
              );
              // Use safePlay to handle disposed controller gracefully
              safePlay(controller, widget.video.id).catchError((error) {
                if (gen == _playbackGeneration) {
                  Log.error(
                    '❌ Widget failed to play video ${widget.video.id} after init: $error',
                    name: 'VideoFeedItem',
                    category: LogCategory.ui,
                  );
                }
                return false; // Return bool to match Future<bool> type
              });
              controller.removeListener(checkAndPlay);
            }
          }

          // Listen for initialization completion
          controller.addListener(checkAndPlay);
          // Clean up listener after first initialization or when generation changes
          Future.delayed(const Duration(seconds: 10), () {
            controller.removeListener(checkAndPlay);
          });
        } else {
          Log.info(
            '❓ PLAY REQUEST for video ${widget.video.id} - No action taken | initialized=${controller.value.isInitialized} | isPlaying=${controller.value.isPlaying} | hasError=${controller.value.hasError}',
            name: 'VideoFeedItem',
            category: LogCategory.video,
          );
        }
      } else if (!shouldPlay && controller.value.isPlaying) {
        Log.info(
          '⏸️ PAUSE REQUEST for video ${widget.video.id} | gen=$gen | initialized=${controller.value.isInitialized} | isPlaying=${controller.value.isPlaying}\nCalled from:\n$stackLines',
          name: 'VideoFeedItem',
          category: LogCategory.video,
        );
        // Use safePause to handle disposed controller gracefully
        safePause(controller, widget.video.id)
            .then((success) {
              if (gen != _playbackGeneration) {
                Log.debug(
                  '⏭️ Ignoring stale pause() completion for ${widget.video.id}',
                  name: 'VideoFeedItem',
                  category: LogCategory.ui,
                );
              }
            })
            .catchError((error) {
              if (gen == _playbackGeneration) {
                Log.error(
                  '❌ Widget failed to pause video ${widget.video.id}: $error',
                  name: 'VideoFeedItem',
                  category: LogCategory.ui,
                );
              }
            });
      }
    } catch (e) {
      Log.error(
        '❌ Error in playback change handler: $e',
        name: 'VideoFeedItem',
        category: LogCategory.ui,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final video = widget.video;
    Log.debug(
      '🏗️ VideoFeedItem.build() for video ${video.id}..., index: ${widget.index}',
      name: 'VideoFeedItem',
      category: LogCategory.ui,
    );

    // Watch fallback URL to trigger rebuild when quality variant (720p/480p) fails.
    // This ensures _controllerParams switches to the fallback URL and creates a new
    // controller with the original MP4 URL.
    ref.watch(fallbackUrlCacheProvider.select((cache) => cache[video.id]));

    // Skip rendering if no video URL
    if (video.videoUrl == null) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.black,
        child: const Center(
          child: Icon(Icons.error_outline, color: Colors.white, size: 48),
        ),
      );
    }

    // Watch if this video is currently active
    // Use override if provided (for custom contexts like lists), otherwise use provider
    // IMPORTANT: When override is non-null, skip provider watch entirely to avoid
    // Riverpod rebuilds interfering with local state management
    final bool isActiveFromProvider = widget.isActiveOverride != null
        ? widget.isActiveOverride!
        : ref.watch(isVideoActiveProvider(video.stableId));

    // Check if a dialog/modal is covering this screen - if so, pause playback
    // ModalRoute.of(context)?.isCurrent returns false when a dialog is on top
    final modalRoute = ModalRoute.of(context);
    final isCurrentRoute = modalRoute?.isCurrent ?? true;
    final bool isActive = isActiveFromProvider && isCurrentRoute;

    Log.debug(
      '📱 VideoFeedItem state: isActive=$isActive (override=${widget.isActiveOverride})',
      name: 'VideoFeedItem',
      category: LogCategory.ui,
    );

    // Check if tracker is Noop - if so, skip VisibilityDetector entirely to prevent timer leaks in tests
    final tracker = ref.watch(visibilityTrackerProvider);

    // Compute overlay visibility with policy override
    final policy = ref.watch(overlayPolicyProvider);
    bool overlayVisible = widget.forceShowOverlay || isActive;

    // Override by policy
    switch (policy) {
      case OverlayPolicy.alwaysOn:
        overlayVisible = true;
        break;
      case OverlayPolicy.alwaysOff:
        overlayVisible = false;
        break;
      case OverlayPolicy.auto:
        // keep computed overlayVisible
        break;
    }

    assert(() {
      debugPrint(
        '[OVERLAY] id=${video.id} policy=$policy active=$isActive -> overlay=$overlayVisible',
      );
      return true;
    }());

    final child = GestureDetector(
      behavior: HitTestBehavior.translucent,
      onDoubleTap: () {
        Log.debug(
          '💕 Double-tap detected on VideoFeedItem for ${video.id}',
          name: 'VideoFeedItem',
          category: LogCategory.ui,
        );
        _handleDoubleTapLike();
      },
      onTap: () {
        // Lighter debounce - ignore taps within 150ms of previous tap
        // 300ms was too aggressive and was swallowing legitimate pause taps
        final now = DateTime.now();
        if (_lastTapTime != null &&
            now.difference(_lastTapTime!) < const Duration(milliseconds: 150)) {
          Log.debug(
            '⏭️ Ignoring rapid tap (debounced) for ${video.id}...',
            name: 'VideoFeedItem',
            category: LogCategory.ui,
          );
          return;
        }
        _lastTapTime = now;

        Log.debug(
          '📱 Tap detected on VideoFeedItem for ${video.id}...',
          name: 'VideoFeedItem',
          category: LogCategory.ui,
        );
        try {
          final controller = ref.read(
            individualVideoControllerProvider(_controllerParams),
          );

          Log.debug(
            '📱 Tap state: isActive=$isActive, isPlaying=${controller.value.isPlaying}, isInitialized=${controller.value.isInitialized}',
            name: 'VideoFeedItem',
            category: LogCategory.ui,
          );

          if (isActive) {
            // Toggle play/pause only if currently active and initialized
            if (controller.value.isInitialized) {
              if (controller.value.isPlaying) {
                Log.info(
                  '⏸️ Tap pausing video ${video.id}...',
                  name: 'VideoFeedItem',
                  category: LogCategory.ui,
                );
                // Use safePause to handle disposed controller gracefully
                safePause(controller, video.id);
              } else {
                Log.info(
                  '▶️ Tap playing video ${video.id}...',
                  name: 'VideoFeedItem',
                  category: LogCategory.ui,
                );
                // Use safePlay to handle disposed controller gracefully
                safePlay(controller, video.id);

                // Show fading pause button animation
                _triggerPauseButtonFade();
              }
            } else {
              Log.debug(
                '⏳ Tap ignored - video ${video.id}... not yet initialized',
                name: 'VideoFeedItem',
                category: LogCategory.ui,
              );
            }
          } else {
            // Tapping inactive video: Navigate to this video's index
            // Active state is derived from URL, so navigation will update it
            // Unless disableTapNavigation is true (for custom contexts like lists)
            if (widget.disableTapNavigation) {
              Log.info(
                '🎯 Tap on inactive video ${video.id}... - navigation disabled, calling onTap only',
                name: 'VideoFeedItem',
                category: LogCategory.ui,
              );
              // Don't navigate - parent handles activation via onTap callback
            } else {
              Log.info(
                '🎯 Tap navigating to video ${video.id}... at index ${widget.index}',
                name: 'VideoFeedItem',
                category: LogCategory.ui,
              );

              // Read current route context to determine which route type to navigate to
              final pageContext = ref.read(pageContextProvider);
              pageContext.whenData((ctx) {
                // Build new route with same type but different index
                final routePath = switch (ctx.type) {
                  RouteType.home => HomeScreenRouter.pathForIndex(widget.index),
                  RouteType.explore => ExploreScreen.pathForIndex(widget.index),
                  RouteType.notifications => NotificationsScreen.pathForIndex(
                    widget.index,
                  ),
                  RouteType.profile => ProfileScreenRouter.pathForIndex(
                    ctx.npub ?? 'me',
                    widget.index,
                  ),
                  RouteType.hashtag => HashtagScreenRouter.pathForTag(
                    ctx.hashtag ?? '',
                    index: widget.index,
                  ),
                  RouteType.likedVideos => LikedVideosScreenRouter.pathForIndex(
                    widget.index,
                  ),
                  RouteType.search => SearchScreenPure.pathForTerm(
                    term: ctx.searchTerm,
                    index: widget.index,
                  ),
                  _ => ExploreScreen.pathForIndex(widget.index),
                };

                Log.info(
                  '🎯 Navigating to route: $routePath',
                  name: 'VideoFeedItem',
                  category: LogCategory.ui,
                );

                context.go(routePath);
              });
            }
          }
          widget.onTap?.call();
        } catch (e) {
          Log.error(
            '❌ Error in VideoFeedItem tap handler for ${video.id}...: $e',
            name: 'VideoFeedItem',
            category: LogCategory.ui,
          );
        }
      },
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Always watch controller to enable preloading
            Consumer(
              builder: (context, ref, child) {
                final controller = ref.watch(
                  individualVideoControllerProvider(_controllerParams),
                );

                final isAgeVerificationRetry = ref.watch(
                  ageVerificationRetryProvider.select(
                    (state) => state[video.id] ?? false,
                  ),
                );

                final videoWidget = ValueListenableBuilder<VideoPlayerValue>(
                  valueListenable: controller,
                  builder: (context, value, _) {
                    if (isAgeVerificationRetry) {
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          VideoThumbnailWidget(
                            video: video,
                            fit: BoxFit.cover,
                            showPlayIcon: false,
                          ),
                          Container(
                            color: Colors.black54,
                            child: const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  BrandedLoadingIndicator(size: 60),
                                  SizedBox(height: 16),
                                  Text(
                                    'Loading video...',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    }

                    // Check for video error state
                    // IMPORTANT: Only show error if video is NOT playing
                    // hasError can be stale after transient errors; if video recovered
                    // and is playing (audio/video working), don't show error overlay
                    final isActuallyBroken = value.hasError && !value.isPlaying;
                    if (isActuallyBroken) {
                      // When a quality variant (720p/480p) fails, the catchError
                      // handler in the provider will store a fallback URL and
                      // trigger a rebuild with a fresh controller for the original
                      // MP4. During the brief window between the error and the
                      // rebuild, suppress the error overlay and show the loading
                      // state instead so the user sees a seamless transition.
                      final optimalUrl = video.getOptimalVideoUrlForPlatform();
                      final isQualityVariant =
                          optimalUrl != null &&
                          (optimalUrl.contains('/720p') ||
                              optimalUrl.contains('/480p'));
                      final fallbackUrl = ref.read(
                        fallbackUrlCacheProvider,
                      )[video.id];

                      if (isQualityVariant && fallbackUrl == null) {
                        // Fallback pending — show thumbnail + loading indicator
                        return SizedBox.expand(
                          child: Container(
                            color: Colors.black,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                VideoThumbnailWidget(
                                  video: video,
                                  fit: BoxFit.cover,
                                  showPlayIcon: false,
                                ),
                                if (isActive)
                                  const Center(
                                    child: BrandedLoadingIndicator(size: 60),
                                  ),
                              ],
                            ),
                          ),
                        );
                      }

                      return VideoErrorOverlay(
                        video: video,
                        controllerParams: _controllerParams,
                        errorDescription: value.errorDescription ?? '',
                        isActive: isActive,
                      );
                    }

                    // Track loading time for delayed indicator
                    if (!value.isInitialized) {
                      _loadingStartTime ??= DateTime.now();
                    } else {
                      _loadingStartTime = null;
                    }

                    // Show loading indicator immediately when not initialized
                    final shouldShowIndicator =
                        !value.isInitialized && isActive;

                    // Use video dimensions if available, otherwise placeholder
                    final videoWidth = value.size.width > 0
                        ? value.size.width
                        : 1.0;
                    final videoHeight = value.size.height > 0
                        ? value.size.height
                        : 1.0;

                    // Portrait videos (9:16): use BoxFit.cover to fill screen
                    // Square/landscape videos (legacy Vine): use BoxFit.contain
                    //   to stay centered without cropping
                    final isPortraitVideo = videoHeight > videoWidth;
                    final useCoverFit = isPortraitVideo;

                    // UNIFIED structure - use Offstage instead of conditional
                    // widgets to maintain stable widget tree during scroll
                    return SizedBox.expand(
                      child: Container(
                        color: Colors.black,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Video player - use Offstage to keep in tree
                            Offstage(
                              offstage: !value.isInitialized,
                              child: FittedBox(
                                fit: useCoverFit
                                    ? BoxFit.cover
                                    : BoxFit.contain,
                                alignment: Alignment.center,
                                child: SizedBox(
                                  width: videoWidth,
                                  height: videoHeight,
                                  child: _SafeVideoPlayer(
                                    controller: controller,
                                    videoId: video.id,
                                  ),
                                ),
                              ),
                            ),
                            // Loading indicator after 2s delay
                            Offstage(
                              offstage: !shouldShowIndicator,
                              child: const Center(
                                child: BrandedLoadingIndicator(size: 60),
                              ),
                            ),
                            // Buffering indicator
                            if (value.isInitialized && value.isBuffering)
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: const LinearProgressIndicator(
                                  minHeight: 12,
                                  backgroundColor: Colors.transparent,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              ),
                            // Play button when active and paused
                            if (isActive &&
                                value.isInitialized &&
                                !value.isPlaying)
                              Center(
                                child: Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.65),
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  child: Semantics(
                                    identifier: 'play_button',
                                    container: true,
                                    explicitChildNodes: true,
                                    label: 'Play video',
                                    child: Center(
                                      child: SvgPicture.asset(
                                        'assets/icon/content-controls/play.svg',
                                        width: 32,
                                        height: 32,
                                        colorFilter: const ColorFilter.mode(
                                          Colors.white,
                                          BlendMode.srcIn,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            // Fading pause button when resuming playback
                            if (_showFadingPauseButton &&
                                isActive &&
                                value.isInitialized &&
                                value.isPlaying)
                              Center(
                                child: AnimatedOpacity(
                                  opacity: _pauseButtonOpacity,
                                  duration: const Duration(milliseconds: 500),
                                  curve: Curves.linear,
                                  child: Container(
                                    width: 64,
                                    height: 64,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(
                                        alpha: 0.65,
                                      ),
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                    child: Center(
                                      child: SvgPicture.asset(
                                        'assets/icon/content-controls/pause.svg',
                                        width: 32,
                                        height: 32,
                                        colorFilter: const ColorFilter.mode(
                                          Colors.white,
                                          BlendMode.srcIn,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            // Double-tap heart animation
                            if (_showDoubleTapHeart)
                              Center(
                                child: AnimatedOpacity(
                                  opacity: _heartOpacity,
                                  duration: const Duration(milliseconds: 400),
                                  curve: Curves.easeOut,
                                  child: AnimatedScale(
                                    scale: _heartScale,
                                    duration: const Duration(milliseconds: 200),
                                    curve: Curves.elasticOut,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.3,
                                            ),
                                            blurRadius: 20,
                                            spreadRadius: 5,
                                          ),
                                        ],
                                      ),
                                      child: SvgPicture.asset(
                                        'assets/icon/content-controls/like.svg',
                                        width: 120,
                                        height: 120,
                                        colorFilter: const ColorFilter.mode(
                                          Colors.white,
                                          BlendMode.srcIn,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            // Subtitle overlay
                            if (isActive && video.hasSubtitles)
                              Consumer(
                                builder: (context, ref, _) {
                                  final visibilityMap = ref.watch(
                                    subtitleVisibilityProvider,
                                  );
                                  final subtitlesVisible =
                                      visibilityMap[video.id] ?? false;
                                  return SubtitleOverlay(
                                    video: video,
                                    positionMs: value.position.inMilliseconds,
                                    visible: subtitlesVisible,
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );

                // Wrap with VideoMetricsTracker only for active videos
                return isActive
                    ? VideoMetricsTracker(
                        video: video,
                        controller: controller,
                        child: videoWidget,
                      )
                    : videoWidget;
              },
            ),

            // Video overlay with actions (badges, title, action buttons)
            // Wrap with VideoInteractionsBloc if available
            BlocProvider<VideoInteractionsBloc>.value(
              value: _interactionsBloc,
              child: VideoOverlayActions(
                video: video,
                isVisible: overlayVisible,
                isActive: isActive,
                hasBottomNavigation: widget.hasBottomNavigation,
                contextTitle: widget.contextTitle,
                isFullscreen: widget.isFullscreen,
                listSources: widget.listSources,
                showListAttribution: widget.showListAttribution,
                hideFollowButtonIfFollowing: widget.hideFollowButtonIfFollowing,
              ),
            ),
          ],
        ),
      ),
    );

    // If tracker is Noop, return child directly (avoids VisibilityDetector's internal timers in tests)
    if (tracker is NoopVisibilityTracker) return child;

    // In production, wrap with VisibilityDetector for analytics
    return VisibilityDetector(
      key: Key('vis-${video.id}'),
      onVisibilityChanged: (info) {
        final isVisible = info.visibleFraction > 0.7;
        Log.debug(
          '👁️ Visibility changed: ${video.id}... fraction=${info.visibleFraction.toStringAsFixed(3)}, isVisible=$isVisible',
          name: 'VideoFeedItem',
          category: LogCategory.ui,
        );

        if (isVisible) {
          tracker.onVisible(video.id, fractionVisible: info.visibleFraction);
        } else {
          tracker.onInvisible(video.id);
        }
      },
      child: child,
    );
  }
}

/// A wrapper around [VideoPlayer] that guards against "No active player
/// with ID" crashes caused by the native AVFoundation/ExoPlayer being
/// disposed while the Flutter widget tree still references the controller.
///
/// This race condition occurs during tab switches or feed scrolling when
/// Riverpod auto-disposes the [VideoPlayerController] (via `Future.microtask`)
/// while the [ValueListenableBuilder] still holds a reference and triggers
/// a rebuild.
///
/// The widget performs two layers of defense:
/// 1. **Pre-build**: Checks [disposedControllersProvider] which is marked
///    synchronously in the Riverpod `onDispose` callback, BEFORE the deferred
///    `controller.dispose()` microtask runs. If the video ID is in the set,
///    the native player is gone (or will be momentarily) and we show a
///    placeholder instead.
/// 2. **Fallback**: If the pre-build check misses the race (e.g. the disposal
///    happened outside our provider lifecycle), the error is handled at the
///    [FlutterError.onError] level in `main.dart` where it is downgraded from
///    FATAL to non-fatal, and the global [ErrorWidget.builder] renders a dark
///    placeholder.
class _SafeVideoPlayer extends ConsumerWidget {
  const _SafeVideoPlayer({required this.controller, required this.videoId});

  final VideoPlayerController controller;
  final String videoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Check the disposed-controllers tracker. This is marked synchronously in
    // Riverpod's onDispose, so it is always up-to-date BEFORE the deferred
    // controller.dispose() microtask removes the native player.
    final isDisposed = ref.watch(
      disposedControllersProvider.select(
        (tracker) => tracker.contains(videoId),
      ),
    );

    if (isDisposed) {
      Log.debug(
        'SafeVideoPlayer: controller for $videoId is marked disposed, '
        'showing placeholder',
        name: 'SafeVideoPlayer',
        category: LogCategory.video,
      );
      return const SizedBox.shrink();
    }

    return VideoPlayer(controller);
  }
}

/// Video overlay actions widget with working functionality
class VideoOverlayActions extends ConsumerWidget {
  const VideoOverlayActions({
    super.key,
    required this.video,
    required this.isVisible,
    required this.isActive,
    this.hasBottomNavigation = true,
    this.contextTitle,
    this.isFullscreen = false,
    this.listSources,
    this.showListAttribution = false,
    this.isPreviewMode = false,
    this.hideFollowButtonIfFollowing = false,
  });

  final VideoEvent video;
  final bool isVisible;
  final bool isActive;
  final bool hasBottomNavigation;
  final String? contextTitle;
  final bool isFullscreen;

  /// Displays the overlay in preview mode during video creation.
  /// When true, users can preview how their video will appear to other users
  /// before publishing.
  final bool isPreviewMode;

  /// Set of curated list IDs this video is from (for list attribution display).
  final Set<String>? listSources;

  /// Whether to show the list attribution chip below the author info.
  final bool showListAttribution;

  /// When true, hides the follow button if already following the author.
  final bool hideFollowButtonIfFollowing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isVisible) return const SizedBox();

    // Check if there's meaningful text content to display
    final hasTextContent =
        video.content.isNotEmpty ||
        (video.title != null && video.title!.isNotEmpty);

    // Stack does not block pointer events by default - taps pass through to GestureDetector below
    // Only interactive elements (buttons, chips with GestureDetector) absorb taps
    // When contextTitle is non-empty, a list header exists above - add extra offset to avoid overlap
    // List header is roughly 64px tall (8px padding + 48px content + 8px padding), add clearance
    // In fullscreen mode, the AppBar floats transparently over the content
    // so the badge just needs the same base offset - no extra list header padding
    final hasListHeader =
        !isFullscreen && contextTitle != null && contextTitle!.isNotEmpty;
    final topOffset = hasListHeader ? 80.0 : 8.0;

    // Calculate bottom offset based on navigation state
    final bottomOffset = 14.0;

    return Stack(
      children: [
        // Bottom gradient overlay (sits below UI elements, only overlays video)
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: IgnorePointer(
            child: FractionallySizedBox(
              widthFactor: 1.0,
              child: SizedBox(
                height: MediaQuery.of(context).size.height / 4,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.0),
                        Colors.black.withValues(alpha: 0.5),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        // ProofMode and Vine badges in upper right corner (tappable)
        if (!isPreviewMode)
          Positioned(
            top: MediaQuery.viewPaddingOf(context).top + topOffset,
            right: 16,
            child: GestureDetector(
              onTap: () {
                _showBadgeExplanationModal(context, ref, video, isActive);
              },
              child: ProofModeBadgeRow(video: video, size: BadgeSize.small),
            ),
          ),
        // Author info and video description overlay at bottom left
        Positioned(
          bottom: bottomOffset,
          left: 16,
          right: 80, // Leave space for action buttons
          child: SafeArea(
            child: AnimatedOpacity(
              opacity: isActive ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Repost banner (if video is a repost)
                  if (video.isRepost && video.reposterPubkey != null) ...[
                    VideoRepostHeader(reposterPubkey: video.reposterPubkey!),
                    const SizedBox(height: 8),
                  ],
                  // Author avatar and info row
                  Consumer(
                    builder: (context, ref, _) {
                      final userProfileService = ref.watch(
                        userProfileServiceProvider,
                      );
                      final profile = userProfileService.getCachedProfile(
                        video.pubkey,
                      );
                      // Use embedded author data from REST API as fallback
                      // This avoids WebSocket profile fetches for videos
                      // that already have author_name/author_avatar embedded
                      final avatarUrl = profile?.picture ?? video.authorAvatar;
                      final displayName =
                          profile?.bestDisplayName ??
                          video.authorName ??
                          NostrKeyUtils.truncateNpub(video.pubkey);
                      final archivedLoops = video.originalLoops ?? 0;
                      final liveViews =
                          int.tryParse(video.rawTags['views'] ?? '') ?? 0;
                      final isClassicVine =
                          video.pubkey == AppConstants.classicVinesPubkey;
                      final loopCount = isClassicVine
                          ? archivedLoops + liveViews
                          : (archivedLoops > 0 ? archivedLoops : liveViews);
                      final hasLoopMetadata =
                          video.originalLoops != null ||
                          video.rawTags.containsKey('loops') ||
                          video.rawTags.containsKey('views');

                      void navigateToProfile() {
                        Log.info(
                          '👤 User tapped profile: videoId=${video.id}, authorPubkey=${video.pubkey}',
                          name: 'VideoFeedItem',
                          category: LogCategory.ui,
                        );
                        final npub = normalizeToNpub(video.pubkey);
                        if (npub != null) {
                          context.push(OtherProfileScreen.pathForNpub(npub));
                        }
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Avatar with follow button overlay
                          SizedBox(
                            width:
                                58, // 48 avatar + space for follow button overflow
                            height: 58,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                // Avatar (tappable to go to profile)
                                GestureDetector(
                                  onTap: navigateToProfile,
                                  child: Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(14),
                                      child:
                                          avatarUrl != null &&
                                              avatarUrl.isNotEmpty
                                          ? CachedNetworkImage(
                                              imageUrl: avatarUrl,
                                              width: 44,
                                              height: 44,
                                              fit: BoxFit.cover,
                                              placeholder: (context, url) =>
                                                  Container(
                                                    color: VineTheme
                                                        .cardBackground,
                                                    child: const Icon(
                                                      Icons.person,
                                                      color: Colors.white54,
                                                      size: 24,
                                                    ),
                                                  ),
                                              errorWidget:
                                                  (context, url, error) =>
                                                      Container(
                                                        color: VineTheme
                                                            .cardBackground,
                                                        child: const Icon(
                                                          Icons.person,
                                                          color: Colors.white54,
                                                          size: 24,
                                                        ),
                                                      ),
                                            )
                                          : Container(
                                              color: VineTheme.cardBackground,
                                              child: const Icon(
                                                Icons.person,
                                                color: Colors.white54,
                                                size: 24,
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                                // Follow button positioned at bottom-right of avatar
                                Positioned(
                                  left: 31,
                                  top: 31,
                                  child: VideoFollowButton(
                                    pubkey: video.pubkey,
                                    hideIfFollowing:
                                        hideFollowButtonIfFollowing,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          // User name and loop count (tappable to go to profile)
                          Expanded(
                            child: GestureDetector(
                              onTap: navigateToProfile,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Semantics(
                                          identifier: 'video_author_name',
                                          container: true,
                                          explicitChildNodes: true,
                                          label: 'Video author: $displayName',
                                          child: Text(
                                            displayName,
                                            style: VineTheme.titleFont(
                                              fontSize: 14,
                                              height: 20 / 14,
                                              color: Colors.white,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                      // Use actual NIP-05 verification —
                                      // only show badge when DNS lookup
                                      // confirms the pubkey owns the claimed
                                      // identifier (NIP-05 spec).
                                      _Nip05Badge(pubkey: video.pubkey),
                                    ],
                                  ),
                                  Text(
                                    hasLoopMetadata
                                        ? '${StringUtils.formatCompactNumber(loopCount)} loops'
                                        : video.relativeTime,
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 14,
                                      height: 20 / 14,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  // List attribution chip (shown when video is from subscribed curated list)
                  if (showListAttribution &&
                      listSources != null &&
                      listSources!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Consumer(
                      builder: (context, ref, _) {
                        final curatedListState = ref.watch(
                          curatedListsStateProvider,
                        );
                        final curatedListService = curatedListState.whenOrNull(
                          data: (_) => ref
                              .read(curatedListsStateProvider.notifier)
                              .service,
                        );

                        return ListAttributionChip(
                          listIds: listSources!,
                          listLookup: (listId) =>
                              curatedListService?.getListById(listId),
                          onListTap: (listId, listName) {
                            final list = curatedListService?.getListById(
                              listId,
                            );
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (context) => CuratedListFeedScreen(
                                  listId: listId,
                                  listName: listName,
                                  videoIds: list?.videoEventIds,
                                  authorPubkey: list?.pubkey,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                  // Video description with clickable hashtags (only if there's text content)
                  if (hasTextContent) ...[
                    const SizedBox(
                      height: 2,
                    ), // 2px + 10px from avatar container = 12px total
                    Semantics(
                      identifier: 'video_description',
                      container: true,
                      explicitChildNodes: true,
                      label:
                          'Video description: ${(video.content.isNotEmpty ? video.content : video.title ?? '').trim()}',
                      child: ClickableHashtagText(
                        text:
                            (video.content.isNotEmpty
                                    ? video.content
                                    : video.title ?? '')
                                .trim(),
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          color: Colors.white,
                          fontSize: 14,
                          height: 20 / 14,
                          letterSpacing: 0.25,
                        ),
                        hashtagStyle: TextStyle(
                          fontFamily: 'Inter',
                          color: VineTheme.vineGreen,
                          fontSize: 14,
                          height: 20 / 14,
                          letterSpacing: 0.25,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Collaborator avatar row (if video has collaborators)
                    if (video.hasCollaborators) ...[
                      const SizedBox(height: 4),
                      CollaboratorAvatarRow(video: video),
                    ],
                    // Inspired-by attribution row (if video credits another creator)
                    if (video.hasInspiredBy) ...[
                      const SizedBox(height: 4),
                      InspiredByAttributionRow(
                        video: video,
                        isActive: isActive,
                      ),
                    ],
                    // Audio attribution row (if video uses external audio)
                    if (video.hasAudioReference) ...[
                      const SizedBox(height: 4),
                      AudioAttributionRow(video: video),
                    ],
                    const SizedBox(
                      height: 8,
                    ), // Bottom spacing only when description exists
                  ],
                ],
              ),
            ),
          ),
        ),
        // Action buttons at bottom right
        Positioned(
          bottom: bottomOffset,
          right: 16,
          child: SafeArea(
            child: AnimatedOpacity(
              opacity: isActive ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: false, // Action buttons SHOULD receive taps
                child: Column(
                  children: [
                    // Edit button (only show for owned videos when feature is enabled)
                    // Hide in fullscreen mode since it's shown in AppBar instead
                    if (!isFullscreen && !isPreviewMode)
                      _VideoEditButton(video: video),

                    // Flag/Report button for content moderation
                    Semantics(
                      identifier: 'report_button',
                      container: true,
                      explicitChildNodes: true,
                      button: true,
                      label: 'Report video',
                      child: IconButton(
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints.tightFor(
                          width: 48,
                          height: 48,
                        ),
                        style: IconButton.styleFrom(
                          highlightColor: Colors.transparent,
                          splashFactory: NoSplash.splashFactory,
                        ),
                        onPressed: () {
                          Log.info(
                            '🚩 Report button tapped for ${video.id}',
                            name: 'VideoFeedItem',
                            category: LogCategory.ui,
                          );
                          context.showVideoPausingDialog(
                            builder: (context) =>
                                ReportContentDialog(video: video),
                          );
                        },
                        icon: DecoratedBox(
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 15,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: SvgPicture.asset(
                            'assets/icon/content-controls/flag.svg',
                            width: 32,
                            height: 32,
                            colorFilter: const ColorFilter.mode(
                              Colors.white,
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 4),

                    // CC (subtitles) button
                    CcActionButton(video: video),

                    const SizedBox(height: 4),

                    // Share button
                    Semantics(
                      identifier: 'share_button',
                      container: true,
                      explicitChildNodes: true,
                      button: true,
                      label: 'Share video',
                      child: IconButton(
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints.tightFor(
                          width: 48,
                          height: 48,
                        ),
                        style: IconButton.styleFrom(
                          highlightColor: Colors.transparent,
                          splashFactory: NoSplash.splashFactory,
                        ),
                        onPressed: () {
                          Log.info(
                            '📤 Share button tapped for ${video.id}',
                            name: 'VideoFeedItem',
                            category: LogCategory.ui,
                          );
                          _showShareMenu(context, ref, video, isActive);
                        },
                        icon: DecoratedBox(
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 15,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: SvgPicture.asset(
                            'assets/icon/content-controls/share.svg',
                            width: 32,
                            height: 32,
                            colorFilter: const ColorFilter.mode(
                              Colors.white,
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 4),

                    // Repost button
                    RepostActionButton(
                      video: video,
                      isPreviewMode: isPreviewMode,
                    ),

                    const SizedBox(height: 4),

                    // Comment button with count
                    _CommentActionButton(video: video, ref: ref),

                    const SizedBox(height: 4),

                    // Like button
                    LikeActionButton(
                      video: video,
                      isPreviewMode: isPreviewMode,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showShareMenu(
    BuildContext context,
    WidgetRef ref,
    VideoEvent video,
    bool isActive,
  ) async {
    // Pause video before showing share menu
    bool wasPaused = false;
    try {
      final controllerParams = VideoControllerParams(
        videoId: video.id,
        videoUrl: video.getOptimalVideoUrlForPlatform() ?? video.videoUrl!,
        cacheUrl: video.videoUrl,
        videoEvent: video,
      );
      final controller = ref.read(
        individualVideoControllerProvider(controllerParams),
      );
      if (controller.value.isInitialized && controller.value.isPlaying) {
        wasPaused = await safePause(controller, video.id);
        if (wasPaused) {
          Log.info(
            '🎬 Paused video for share menu',
            name: 'VideoFeedItem',
            category: LogCategory.ui,
          );
        }
      }
    } catch (e) {
      final errorStr = e.toString().toLowerCase();
      if (!errorStr.contains('no active player') &&
          !errorStr.contains('disposed')) {
        Log.error(
          'Failed to pause video for share menu: $e',
          name: 'VideoFeedItem',
          category: LogCategory.ui,
        );
      }
    }

    await context.showVideoPausingVineBottomSheet<void>(
      builder: (context) => ShareVideoMenu(video: video),
    );

    // Video resumes when modal closes via overlay visibility provider
  }

  Future<void> _showBadgeExplanationModal(
    BuildContext context,
    WidgetRef ref,
    VideoEvent video,
    bool isActive,
  ) async {
    // Pause video before showing modal
    bool wasPaused = false;
    try {
      final controllerParams = VideoControllerParams(
        videoId: video.id,
        videoUrl: video.getOptimalVideoUrlForPlatform() ?? video.videoUrl!,
        cacheUrl: video.videoUrl,
        videoEvent: video,
      );

      final controller = ref.read(
        individualVideoControllerProvider(controllerParams),
      );
      if (controller.value.isInitialized && controller.value.isPlaying) {
        // Use safePause to handle disposed controller gracefully
        wasPaused = await safePause(controller, video.id);
        if (wasPaused) {
          Log.info(
            '🎬 Paused video for badge modal',
            name: 'VideoFeedItem',
            category: LogCategory.ui,
          );
        }
      }
    } catch (e) {
      // Ignore disposal errors
      final errorStr = e.toString().toLowerCase();
      if (!errorStr.contains('no active player') &&
          !errorStr.contains('disposed')) {
        Log.error(
          'Failed to pause video for modal: $e',
          name: 'VideoFeedItem',
          category: LogCategory.ui,
        );
      }
    }

    await context.showVideoPausingDialog<void>(
      barrierDismissible: true,
      builder: (context) => BadgeExplanationModal(video: video),
    );

    // Video resumes when modal closes via overlay visibility provider
  }
}

/// Edit button shown only for owned videos when feature flag is enabled.
///
/// This widget checks:
/// 1. Feature flag `enableVideoEditorV1` is enabled
/// 2. Current user owns the video
///
/// If both conditions are met, displays an edit button that opens the
/// video edit dialog.
class _VideoEditButton extends ConsumerWidget {
  const _VideoEditButton({required this.video});

  final VideoEvent video;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Check feature flag
    final featureFlagService = ref.watch(featureFlagServiceProvider);
    final isEditorEnabled = featureFlagService.isEnabled(
      FeatureFlag.enableVideoEditorV1,
    );

    if (!isEditorEnabled) {
      return const SizedBox.shrink();
    }

    // Check ownership
    final authService = ref.watch(authServiceProvider);
    final currentUserPubkey = authService.currentPublicKeyHex;
    final isOwnVideo =
        currentUserPubkey != null && currentUserPubkey == video.pubkey;

    if (!isOwnVideo) {
      return const SizedBox.shrink();
    }

    // Show edit button
    return Column(
      children: [
        const SizedBox(height: 4),
        Semantics(
          identifier: 'edit_button',
          container: true,
          explicitChildNodes: true,
          button: true,
          label: 'Edit video',
          child: IconButton(
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints.tightFor(width: 48, height: 48),
            style: IconButton.styleFrom(
              highlightColor: Colors.transparent,
              splashFactory: NoSplash.splashFactory,
            ),
            onPressed: () {
              Log.info(
                '✏️ Edit button tapped for ${video.id}',
                name: 'VideoFeedItem',
                category: LogCategory.ui,
              );

              // Show edit dialog directly (works on all platforms)
              showEditDialogForVideo(context, video);
            },
            tooltip: 'Edit video',
            icon: DecoratedBox(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 15,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: SvgPicture.asset(
                'assets/icon/content-controls/pencil.svg',
                width: 32,
                height: 32,
                colorFilter: const ColorFilter.mode(
                  Colors.white,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Username and follow button row for video overlay.
///
/// Displays the video author's name (tappable to go to profile) and a follow button.
class VideoAuthorRow extends ConsumerWidget {
  const VideoAuthorRow({
    super.key,
    required this.video,
    this.isFullscreen = false,
    this.hideFollowButtonIfFollowing = false,
  });

  final VideoEvent video;
  final bool isFullscreen;
  final bool hideFollowButtonIfFollowing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch UserProfileService directly (now a ChangeNotifier)
    // This will rebuild when profiles are added/updated
    final userProfileService = ref.watch(userProfileServiceProvider);
    final profile = userProfileService.getCachedProfile(video.pubkey);

    // If profile not cached and not known missing, fetch it
    if (profile == null &&
        !userProfileService.shouldSkipProfileFetch(video.pubkey)) {
      Future.microtask(() {
        ref.read(userProfileProvider.notifier).fetchProfile(video.pubkey);
      });
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Username chip (tappable to go to profile)
        GestureDetector(
          onTap: () {
            Log.info(
              '👤 User tapped profile: videoId=${video.id}, authorPubkey=${video.pubkey}',
              name: 'VideoFeedItem',
              category: LogCategory.ui,
            );
            // Push other user's profile (fullscreen, no bottom nav)
            final npub = normalizeToNpub(video.pubkey);
            if (npub != null) {
              context.push(OtherProfileScreen.pathForNpub(npub));
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.person, size: 14, color: Colors.white),
                const SizedBox(width: 6),
                UserName.fromPubKey(
                  video.pubkey,
                  embeddedName: video.authorName,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
        // Follow button (handles own video check internally)
        const SizedBox(width: 8),
        VideoFollowButton(
          pubkey: video.pubkey,
          hideIfFollowing: hideFollowButtonIfFollowing,
        ),
      ],
    );
  }
}

/// Repost header banner showing who reposted the video.
class VideoRepostHeader extends ConsumerWidget {
  const VideoRepostHeader({super.key, required this.reposterPubkey});

  final String reposterPubkey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Fetch reposter's profile
    final userProfileService = ref.watch(userProfileServiceProvider);
    final reposterProfile = userProfileService.getCachedProfile(reposterPubkey);

    // If profile not cached, fetch it
    if (reposterProfile == null &&
        !userProfileService.shouldSkipProfileFetch(reposterPubkey)) {
      Future.microtask(() {
        userProfileService.fetchProfile(reposterPubkey);
      });
    }

    final displayName =
        reposterProfile?.bestDisplayName ??
        NostrKeyUtils.truncateNpub(reposterPubkey);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.repeat, color: VineTheme.vineGreen, size: 16),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              '$displayName reposted',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Comment action button with count display.
///
/// Uses [VideoInteractionsBloc] for the comment count when available,
/// falls back to showing original Vine comment count.
class _CommentActionButton extends StatelessWidget {
  const _CommentActionButton({required this.video, required this.ref});

  final VideoEvent video;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    // Try to use VideoInteractionsBloc for comment count
    final interactionsBloc = context.read<VideoInteractionsBloc?>();

    if (interactionsBloc != null) {
      return BlocBuilder<VideoInteractionsBloc, VideoInteractionsState>(
        builder: (context, state) {
          // Use bloc's commentCount if available (fetched from relays),
          // otherwise fall back to video metadata's originalComments.
          // Don't add them together - they represent the same data from
          // different sources.
          final totalComments =
              state.commentCount ?? video.originalComments ?? 0;
          return _buildButton(context, totalComments);
        },
      );
    }

    // Fall back to original comment count
    return _buildButton(context, video.originalComments ?? 0);
  }

  Widget _buildButton(BuildContext context, int totalComments) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          identifier: 'comments_button',
          container: true,
          explicitChildNodes: true,
          button: true,
          label: 'View comments',
          child: IconButton(
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints.tightFor(width: 48, height: 48),
            style: IconButton.styleFrom(
              highlightColor: Colors.transparent,
              splashFactory: NoSplash.splashFactory,
            ),
            onPressed: () {
              Log.info(
                '💬 Comment button tapped for ${video.id}',
                name: 'VideoFeedItem',
                category: LogCategory.ui,
              );
              // Pause video before navigating to comments
              if (video.videoUrl != null) {
                try {
                  final controllerParams = VideoControllerParams(
                    videoId: video.id,
                    videoUrl:
                        video.getOptimalVideoUrlForPlatform() ??
                        video.videoUrl!,
                    cacheUrl: video.videoUrl,
                    videoEvent: video,
                  );
                  final controller = ref.read(
                    individualVideoControllerProvider(controllerParams),
                  );
                  if (controller.value.isInitialized &&
                      controller.value.isPlaying) {
                    safePause(controller, video.id);
                  }
                } catch (e) {
                  final errorStr = e.toString().toLowerCase();
                  if (!errorStr.contains('no active player') &&
                      !errorStr.contains('disposed')) {
                    Log.error(
                      'Failed to pause video before comments: $e',
                      name: 'VideoFeedItem',
                      category: LogCategory.video,
                    );
                  }
                }
              }
              CommentsScreen.show(
                context,
                video,
                initialCommentCount: totalComments,
              );
            },
            icon: DecoratedBox(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 15,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: SvgPicture.asset(
                'assets/icon/content-controls/comment.svg',
                width: 32,
                height: 32,
                colorFilter: const ColorFilter.mode(
                  Colors.white,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
        ),
        if (totalComments > 0) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              StringUtils.formatCompactNumber(totalComments),
              style: const TextStyle(
                fontFamily: 'Bricolage Grotesque',
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// NIP-05 verification badge that watches the actual verification provider.
///
/// Only shows the blue checkmark when DNS lookup confirms the pubkey
/// owns the claimed NIP-05 identifier, per the NIP-05 spec.
class _Nip05Badge extends ConsumerWidget {
  const _Nip05Badge({required this.pubkey});

  final String pubkey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final verificationAsync = ref.watch(nip05VerificationProvider(pubkey));
    final isVerified = switch (verificationAsync) {
      AsyncData(:final value) => value == Nip05VerificationStatus.verified,
      _ => false,
    };

    if (!isVerified) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: const BoxDecoration(
          color: Colors.blue,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check, color: Colors.white, size: 10),
      ),
    );
  }
}
