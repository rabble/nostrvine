// ABOUTME: Video feed item using individual controller architecture
// ABOUTME: Each video gets its own controller with automatic lifecycle management via Riverpod autoDispose

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/video_interactions/video_interactions_bloc.dart';
import 'package:openvine/constants/nip71_migration.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:models/models.dart' hide LogCategory, NIP71VideoKinds;
import 'package:openvine/providers/active_video_provider.dart'; // For isVideoActiveProvider (router-driven)
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/individual_video_providers.dart'; // For individualVideoControllerProvider only
import 'package:openvine/providers/social_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/router/nav_extensions.dart';
import 'package:openvine/router/page_context_provider.dart';
import 'package:openvine/router/route_utils.dart';
import 'package:openvine/screens/curated_list_feed_screen.dart';
import 'package:openvine/services/visibility_tracker.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/ui/overlay_policy.dart';
import 'package:openvine/utils/string_utils.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/badge_explanation_modal.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/circular_icon_button.dart';
import 'package:openvine/widgets/clickable_hashtag_text.dart';
import 'package:openvine/widgets/proofmode_badge.dart';
import 'package:openvine/widgets/proofmode_badge_row.dart';
import 'package:openvine/widgets/share_video_menu.dart';
import 'package:openvine/widgets/user_name.dart';
import 'package:openvine/widgets/video_feed_item/actions/like_action_button.dart';
import 'package:openvine/widgets/video_feed_item/audio_attribution_row.dart';
import 'package:openvine/widgets/video_feed_item/list_attribution_chip.dart';
import 'package:openvine/widgets/video_feed_item/video_error_overlay.dart';
import 'package:openvine/widgets/video_feed_item/video_follow_button.dart';
import 'package:openvine/widgets/video_metrics_tracker.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

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

  /// Stable video identifier for active state tracking
  String get _stableVideoId => widget.video.stableId;

  /// Controller params for the current video
  VideoControllerParams get _controllerParams => VideoControllerParams(
    videoId: widget.video.id,
    videoUrl: widget.video.videoUrl!,
    videoEvent: widget.video,
  );

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

      // If using override, handle playback directly without provider listener
      if (widget.isActiveOverride != null) {
        Log.info(
          '🎬 VideoFeedItem.initState: using isActiveOverride=${widget.isActiveOverride} for ${widget.video.id}',
          name: 'VideoFeedItem',
          category: LogCategory.video,
        );
        if (widget.isActiveOverride!) {
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

    _interactionsBloc = VideoInteractionsBloc(
      eventId: widget.video.id,
      authorPubkey: widget.video.pubkey,
      likesRepository: likesRepository,
      commentsRepository: commentsRepository,
    );
    // Start listening for liked IDs changes
    _interactionsBloc.add(const VideoInteractionsSubscriptionRequested());
    // Trigger initial fetch
    _interactionsBloc.add(const VideoInteractionsFetchRequested());
  }

  @override
  void dispose() {
    // Close the interactions bloc
    _interactionsBloc.close();

    // When using override mode, we need to stop playback manually on dispose
    // (provider mode handles this automatically via provider cleanup)
    if (widget.isActiveOverride == true && widget.video.videoUrl != null) {
      Log.info(
        '🛑 VideoFeedItem.dispose: stopping playback for ${widget.video.id} (override mode)',
        name: 'VideoFeedItem',
        category: LogCategory.video,
      );

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
                final newRoute = RouteContext(
                  type: ctx.type,
                  videoIndex: widget.index,
                  npub: ctx.npub,
                  hashtag: ctx.hashtag,
                );

                Log.info(
                  '🎯 Navigating to route: ${buildRoute(newRoute)}',
                  name: 'VideoFeedItem',
                  category: LogCategory.ui,
                );

                context.go(buildRoute(newRoute));
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

                final videoWidget = ValueListenableBuilder<VideoPlayerValue>(
                  valueListenable: controller,
                  builder: (context, value, _) {
                    // Check for video error state
                    // IMPORTANT: Only show error if video is NOT playing
                    // hasError can be stale after transient errors; if video recovered
                    // and is playing (audio/video working), don't show error overlay
                    final isActuallyBroken = value.hasError && !value.isPlaying;
                    if (isActuallyBroken) {
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

                    // Only show loading indicator after 2 seconds
                    final shouldShowIndicator =
                        !value.isInitialized &&
                        isActive &&
                        _loadingStartTime != null &&
                        DateTime.now()
                                .difference(_loadingStartTime!)
                                .inMilliseconds >
                            2000;

                    // Schedule rebuild after 2s if still loading
                    if (!value.isInitialized &&
                        isActive &&
                        !shouldShowIndicator &&
                        _loadingStartTime != null) {
                      final elapsed = DateTime.now()
                          .difference(_loadingStartTime!)
                          .inMilliseconds;
                      Future.delayed(
                        Duration(milliseconds: 2100 - elapsed),
                        () {
                          if (mounted) setState(() {});
                        },
                      );
                    }

                    // Use video dimensions if available, otherwise placeholder
                    final videoWidth = value.size.width > 0
                        ? value.size.width
                        : 1.0;
                    final videoHeight = value.size.height > 0
                        ? value.size.height
                        : 1.0;

                    // In fullscreen mode:
                    //   - Portrait videos (9:16): use BoxFit.cover to fill screen
                    //   - Square/landscape videos (legacy Vine): use BoxFit.contain
                    //     to stay centered without cropping
                    // In normal mode, use BoxFit.contain to preserve aspect ratio
                    final isPortraitVideo = videoHeight > videoWidth;
                    final useFullscreenCover =
                        widget.isFullscreen && isPortraitVideo;

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
                                fit: useFullscreenCover
                                    ? BoxFit.cover
                                    : BoxFit.contain,
                                alignment: widget.isFullscreen
                                    ? Alignment.center
                                    : Alignment.topCenter,
                                child: SizedBox(
                                  width: videoWidth,
                                  height: videoHeight,
                                  child: VideoPlayer(controller),
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
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Semantics(
                                    identifier: 'play_button',
                                    container: true,
                                    explicitChildNodes: true,
                                    label: 'Play video',
                                    child: const Icon(
                                      Icons.play_arrow,
                                      size: 56,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
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
  });

  final VideoEvent video;
  final bool isVisible;
  final bool isActive;
  final bool hasBottomNavigation;
  final String? contextTitle;
  final bool isFullscreen;

  /// Set of curated list IDs this video is from (for list attribution display).
  final Set<String>? listSources;

  /// Whether to show the list attribution chip below the author info.
  final bool showListAttribution;

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
    // In fullscreen mode, add extra offset to clear the back button row (AppBar ~56px + padding)
    final hasListHeader = contextTitle != null && contextTitle!.isNotEmpty;
    final fullscreenOffset = isFullscreen ? 48.0 : 0.0;
    final topOffset = (hasListHeader ? 80.0 : 16.0) + fullscreenOffset;

    return Stack(
      children: [
        // ProofMode and Vine badges in upper right corner (tappable)
        Positioned(
          top: MediaQuery.of(context).viewPadding.top + topOffset,
          right: 16,
          child: GestureDetector(
            onTap: () {
              _showBadgeExplanationModal(context, ref, video, isActive);
            },
            child: ProofModeBadgeRow(video: video, size: BadgeSize.small),
          ),
        ),
        // Bottom left column: Repost banner, author row, description
        // TODO(cleanup): Remove hasBottomNavigation and use only isFullscreen
        Positioned(
          bottom: hasBottomNavigation ? 16 : (isFullscreen ? 48 : 16),
          left: 16,
          right: 16,
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
                // Author row with profile and follow button
                VideoAuthorRow(video: video, isFullscreen: isFullscreen),
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
                          final list = curatedListService?.getListById(listId);
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
                // Description (if there's text content)
                if (hasTextContent) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(right: 64),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Video title with clickable hashtags
                          Semantics(
                            identifier: 'video_description',
                            container: true,
                            explicitChildNodes: true,
                            label: 'Video description',
                            child: ClickableHashtagText(
                              text: video.content.isNotEmpty
                                  ? video.content
                                  : video.title!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                height: 1.3,
                                shadows: [
                                  Shadow(
                                    offset: Offset(0, 0),
                                    blurRadius: 8,
                                    color: Colors.black,
                                  ),
                                  Shadow(
                                    offset: Offset(2, 2),
                                    blurRadius: 4,
                                    color: Colors.black,
                                  ),
                                ],
                              ),
                              hashtagStyle: TextStyle(
                                color: VineTheme.vineGreen,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                height: 1.3,
                                shadows: const [
                                  Shadow(
                                    offset: Offset(0, 0),
                                    blurRadius: 8,
                                    color: Colors.black,
                                  ),
                                  Shadow(
                                    offset: Offset(2, 2),
                                    blurRadius: 4,
                                    color: Colors.black,
                                  ),
                                ],
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Show original loop count if available
                          if (video.originalLoops != null &&
                              video.originalLoops! > 0) ...[
                            const SizedBox(height: 4),
                            Semantics(
                              identifier: 'loop_count',
                              container: true,
                              explicitChildNodes: true,
                              label: 'Video loop count',
                              child: Text(
                                '🔁 ${StringUtils.formatCompactNumber(video.originalLoops!)} loops',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  shadows: [
                                    Shadow(
                                      offset: Offset(0, 0),
                                      blurRadius: 6,
                                      color: Colors.black,
                                    ),
                                    Shadow(
                                      offset: Offset(1, 1),
                                      blurRadius: 3,
                                      color: Colors.black,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          // Audio attribution row (if video uses external audio)
                          if (video.hasAudioReference) ...[
                            const SizedBox(height: 4),
                            AudioAttributionRow(video: video),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        // Action buttons at bottom right
        // In fullscreen mode (no bottom nav), add extra padding to avoid edge
        Positioned(
          bottom: hasBottomNavigation ? 16 : (isFullscreen ? 48 : 16),
          right: 16,
          child: AnimatedOpacity(
            opacity: isActive ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: IgnorePointer(
              ignoring: false, // Action buttons SHOULD receive taps
              child: Column(
                children: [
                  // Like button - uses dedicated widget for isolated rebuilds
                  LikeActionButton(video: video),

                  const SizedBox(height: 16),

                  // Comment button with count - uses VideoInteractionsBloc
                  _CommentActionButton(video: video, ref: ref),

                  const SizedBox(height: 16),

                  // Repost/Revine button - wrapped in Consumer to isolate rebuilds
                  Consumer(
                    builder: (context, ref, _) {
                      final socialState = ref.watch(socialProvider);
                      // Construct addressable ID for repost state check
                      final dTag = video.rawTags['d'];
                      final addressableId = dTag != null
                          ? '${NIP71VideoKinds.addressableShortVideo}:${video.pubkey}:$dTag'
                          : video.id;
                      final isReposted = socialState.hasReposted(addressableId);
                      final isRepostInProgress = socialState.isRepostInProgress(
                        video.id,
                      );

                      return Column(
                        children: [
                          Semantics(
                            identifier: 'repost_button',
                            container: true,
                            explicitChildNodes: true,
                            button: true,
                            label: isReposted
                                ? 'Remove repost'
                                : 'Repost video',
                            child: CircularIconButton(
                              onPressed: isRepostInProgress
                                  ? () {}
                                  : () async {
                                      Log.info(
                                        '🔁 Repost button tapped for ${video.id}',
                                        name: 'VideoFeedItem',
                                        category: LogCategory.ui,
                                      );
                                      await ref
                                          .read(socialProvider.notifier)
                                          .toggleRepost(video);
                                    },
                              icon: isRepostInProgress
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Icon(
                                      Icons.repeat,
                                      color: isReposted
                                          ? VineTheme.vineGreen
                                          : Colors.white,
                                      size: 32,
                                    ),
                            ),
                          ),
                          // Show repost count: Nostr reposts + original reposts (if any)
                          Builder(
                            builder: (context) {
                              final nostrReposts =
                                  video.reposterPubkeys?.length ?? 0;
                              final originalReposts =
                                  video.originalReposts ?? 0;
                              final totalReposts =
                                  nostrReposts + originalReposts;

                              if (totalReposts > 0) {
                                return Padding(
                                  padding: EdgeInsets.zero,
                                  child: Text(
                                    StringUtils.formatCompactNumber(
                                      totalReposts,
                                    ),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      shadows: [
                                        Shadow(
                                          offset: Offset(0, 0),
                                          blurRadius: 6,
                                          color: Colors.black,
                                        ),
                                        Shadow(
                                          offset: Offset(1, 1),
                                          blurRadius: 3,
                                          color: Colors.black,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 16),

                  // Share button with label
                  Column(
                    children: [
                      Semantics(
                        identifier: 'share_button',
                        container: true,
                        explicitChildNodes: true,
                        button: true,
                        label: 'Share video',
                        child: CircularIconButton(
                          onPressed: () {
                            Log.info(
                              '📤 Share button tapped for ${video.id}',
                              name: 'VideoFeedItem',
                              category: LogCategory.ui,
                            );
                            _showShareMenu(context, ref, video, isActive);
                          },
                          icon: const Icon(
                            Icons.share_outlined,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ),
                      const SizedBox(height: 0),
                      const Text(
                        'Share',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              offset: Offset(0, 0),
                              blurRadius: 6,
                              color: Colors.black,
                            ),
                            Shadow(
                              offset: Offset(1, 1),
                              blurRadius: 3,
                              color: Colors.black,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Flag/Report button for content moderation
                  Column(
                    children: [
                      Semantics(
                        identifier: 'report_button',
                        container: true,
                        explicitChildNodes: true,
                        button: true,
                        label: 'Report video',
                        child: CircularIconButton(
                          onPressed: () {
                            Log.info(
                              '🚩 Report button tapped for ${video.id}',
                              name: 'VideoFeedItem',
                              category: LogCategory.ui,
                            );
                            showDialog(
                              context: context,
                              builder: (context) =>
                                  ReportContentDialog(video: video),
                            );
                          },
                          icon: const Icon(
                            Icons.flag_outlined,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ),
                      const SizedBox(height: 0),
                      const Text(
                        'Report',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              offset: Offset(0, 0),
                              blurRadius: 6,
                              color: Colors.black,
                            ),
                            Shadow(
                              offset: Offset(1, 1),
                              blurRadius: 3,
                              color: Colors.black,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Edit button (only show for owned videos when feature is enabled)
                  _VideoEditButton(video: video),
                ],
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
        videoUrl: video.videoUrl!,
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

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ShareVideoMenu(video: video),
    );

    // Video stays paused after dialog closes - user must explicitly play
    // or navigate to a new video to trigger auto-play
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
        videoUrl: video.videoUrl!,
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

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => BadgeExplanationModal(video: video),
    );

    // Video stays paused after dialog closes - user must explicitly play
    // or navigate to a new video to trigger auto-play
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
        const SizedBox(height: 16),
        IconButton(
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
          icon: const Icon(Icons.edit, color: Colors.white, size: 32),
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
  });

  final VideoEvent video;
  final bool isFullscreen;

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
            context.pushOtherProfile(video.pubkey);
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
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
        // Follow button (handles own video check internally)
        const SizedBox(width: 8),
        VideoFollowButton(pubkey: video.pubkey),
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
        reposterProfile?.bestDisplayName ?? reposterPubkey.substring(0, 8);

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
          final commentCount = state.commentCount ?? 0;
          final totalComments = commentCount + (video.originalComments ?? 0);
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
          child: CircularIconButton(
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
                    videoUrl: video.videoUrl!,
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
              context.pushComments(video);
            },
            icon: const Icon(
              Icons.comment_outlined,
              color: Colors.white,
              size: 32,
            ),
          ),
        ),
        if (totalComments > 0) ...[
          const SizedBox(height: 0),
          Text(
            StringUtils.formatCompactNumber(totalComments),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(
                  offset: Offset(0, 0),
                  blurRadius: 6,
                  color: Colors.black,
                ),
                Shadow(
                  offset: Offset(1, 1),
                  blurRadius: 3,
                  color: Colors.black,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
