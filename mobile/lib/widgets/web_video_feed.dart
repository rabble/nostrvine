// ABOUTME: Web-native video feed using Flutter's video_player package
// ABOUTME: Replaces PooledVideoFeed on web where media_kit is not available

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:models/models.dart';
import 'package:openvine/screens/feed/feed_auto_advance_policy.dart';
import 'package:openvine/widgets/web_video_player.dart';
import 'package:video_player/video_player.dart';

/// Builder for web video feed items.
///
/// Provides the video event, index, active state, and optionally the
/// [VideoPlayerController] once initialized.
typedef WebVideoFeedItemBuilder =
    Widget Function(
      BuildContext context,
      VideoEvent video,
      int index, {
      required bool isActive,
      VideoPlayerController? controller,
    });

/// Callback when active video changes in the web feed.
typedef WebOnActiveVideoChanged = void Function(VideoEvent video, int index);

/// Callback fired when the active web player crosses the loop boundary.
typedef WebOnCompleted = void Function(int index);

/// Callback fired when a web player for [index] fails to load or initialise.
///
/// Used by auto-advance to skip past broken videos instead of getting stuck
/// on them — a failed player never emits a loop-boundary crossing.
typedef WebOnErrored = void Function(int index);

/// A vertical-scrolling video feed for web platforms.
///
/// Uses Flutter's [video_player] package (HTML5 video via video_player_web_hls)
/// instead of media_kit, which does not work on web.
class WebVideoFeed extends StatefulWidget {
  /// Creates a web video feed.
  const WebVideoFeed({
    required this.videos,
    this.itemBuilder,
    this.initialIndex = 0,
    this.onActiveVideoChanged,
    this.onCompleted,
    this.onErrored,
    this.onNearEnd,
    this.nearEndThreshold = 3,
    this.headers = const {},
    this.startThreshold = FeedAutoAdvanceDefaults.startThreshold,
    this.endThreshold = FeedAutoAdvanceDefaults.endThreshold,
    this.controllerFactory = defaultWebVideoPlayerControllerFactory,
    super.key,
  });

  /// Videos to display.
  final List<VideoEvent> videos;

  /// Optional custom item builder for overlays and controls.
  final WebVideoFeedItemBuilder? itemBuilder;

  /// Initial video index to display.
  final int initialIndex;

  /// Called when active video changes.
  final WebOnActiveVideoChanged? onActiveVideoChanged;

  /// Called when the active video crosses the loop boundary.
  final WebOnCompleted? onCompleted;

  /// Called when a player at a given index fails to initialise.
  ///
  /// Wired to auto-advance so the feed can skip past a broken video instead
  /// of getting stuck on it.
  final WebOnErrored? onErrored;

  /// Called when near the end of the list for pagination.
  final void Function(int index)? onNearEnd;

  /// How many videos from the end should trigger [onNearEnd].
  final int nearEndThreshold;

  /// HTTP headers for video requests.
  final Map<String, String> headers;

  /// Position threshold considered "near the start" for loop detection.
  final Duration startThreshold;

  /// Position threshold considered "near the end" for loop detection.
  final Duration endThreshold;

  /// Factory used to create underlying web video controllers.
  final WebVideoPlayerControllerFactory controllerFactory;

  @override
  State<WebVideoFeed> createState() => WebVideoFeedState();
}

class WebVideoFeedState extends State<WebVideoFeed> {
  late PageController _pageController;
  int _currentIndex = 0;

  // Track web player keys to control playback.
  final Map<int, GlobalKey<WebVideoPlayerState>> _playerKeys = {};

  // Exposed as a [ValueNotifier] so only overlay widgets that care about the
  // initialized controller rebuild when a controller becomes available,
  // instead of the entire feed's itemBuilder.
  final ValueNotifier<Map<int, VideoPlayerController>> _controllers =
      ValueNotifier<Map<int, VideoPlayerController>>(
        const <int, VideoPlayerController>{},
      );

  final Map<int, VoidCallback> _controllerListeners = {};
  final Map<int, Duration> _lastPositions = {};
  final Map<int, bool> _armedForCompletion = {};

  int get currentIndex => _currentIndex;
  int get videoCount => widget.videos.length;

  /// Number of tracked controllers. Exposed for test instrumentation.
  @visibleForTesting
  int get debugControllerCount => _controllers.value.length;

  /// Number of tracked player keys. Exposed for test instrumentation.
  @visibleForTesting
  int get debugPlayerKeyCount => _playerKeys.length;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void didUpdateWidget(WebVideoFeed oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.videos, widget.videos)) {
      _pruneStaleEntries();
    }
  }

  @override
  void dispose() {
    for (final entry in _controllers.value.entries) {
      _detachCompletionListener(entry.key, entry.value);
    }
    _controllers.dispose();
    _pageController.dispose();
    super.dispose();
  }

  /// Removes tracked entries for indices outside the current video list.
  void _pruneStaleEntries() {
    final validCount = widget.videos.length;
    _playerKeys.removeWhere((index, _) => index >= validCount);
    final current = _controllers.value;
    final pruned = <int, VideoPlayerController>{
      for (final entry in current.entries)
        if (entry.key < validCount) entry.key: entry.value,
    };
    if (pruned.length != current.length) {
      // Detach listeners for evicted controllers before dropping the
      // reference so we don't leak the position callback.
      for (final entry in current.entries) {
        if (entry.key >= validCount) {
          _detachCompletionListener(entry.key, entry.value);
        }
      }
      _controllers.value = pruned;
    }
  }

  /// Removes tracked entries when a [WebVideoPlayer] at [index] disposes.
  ///
  /// Drops both the controller reference and the GlobalKey so we don't
  /// retain disposed controllers across scroll. If the user scrolls back
  /// to this index, the next [_getPlayerKey] call mints a fresh key.
  void _onPlayerDisposed(int index) {
    _playerKeys.remove(index);
    final current = _controllers.value;
    final controller = current[index];
    if (controller == null) return;
    _detachCompletionListener(index, controller);
    final next = Map<int, VideoPlayerController>.of(current)..remove(index);
    _controllers.value = next;
  }

  Future<void> animateToPage(int index) async {
    if (!mounted || widget.videos.isEmpty) return;

    final targetIndex = index.clamp(0, widget.videos.length - 1);
    if (targetIndex == _currentIndex) return;

    await _pageController.animateToPage(
      targetIndex,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _onPageChanged(int index) {
    // Pause the old video
    _playerKeys[_currentIndex]?.currentState?.pause();

    setState(() => _currentIndex = index);

    // Play the new video
    _playerKeys[index]?.currentState?.play();

    if (index < widget.videos.length) {
      widget.onActiveVideoChanged?.call(widget.videos[index], index);
    }

    final distanceFromEnd = widget.videos.length - index - 1;
    if (distanceFromEnd <= widget.nearEndThreshold) {
      widget.onNearEnd?.call(index);
    }
  }

  GlobalKey<WebVideoPlayerState> _getPlayerKey(int index) {
    return _playerKeys.putIfAbsent(index, GlobalKey<WebVideoPlayerState>.new);
  }

  void _attachCompletionListener(int index, VideoPlayerController controller) {
    final previousController = _controllers.value[index];
    if (identical(previousController, controller) &&
        _controllerListeners.containsKey(index)) {
      return;
    }

    if (previousController != null) {
      _detachCompletionListener(index, previousController);
    }

    final next = Map<int, VideoPlayerController>.of(_controllers.value)
      ..[index] = controller;
    _controllers.value = next;

    _lastPositions[index] = controller.value.position;
    _armedForCompletion[index] = false;

    void listener() => _handleControllerTick(index, controller);

    _controllerListeners[index] = listener;
    controller.addListener(listener);
  }

  void _detachCompletionListener(int index, VideoPlayerController controller) {
    final listener = _controllerListeners.remove(index);
    if (listener != null) {
      try {
        controller.removeListener(listener);
      } catch (_) {
        // Ignore disposed controller cleanup on teardown.
      }
    }
    _lastPositions.remove(index);
    _armedForCompletion.remove(index);
  }

  void _handleControllerTick(int index, VideoPlayerController controller) {
    final value = controller.value;
    final position = value.position;

    if (!value.isInitialized) {
      _lastPositions[index] = position;
      return;
    }

    final duration = value.duration;
    if (duration <= Duration.zero) {
      _lastPositions[index] = position;
      return;
    }

    if (position >= duration - widget.endThreshold) {
      _armedForCompletion[index] = true;
    }

    final lastPosition = _lastPositions[index] ?? Duration.zero;
    final crossedLoopBoundary =
        (_armedForCompletion[index] ?? false) &&
        position <= widget.startThreshold &&
        lastPosition > position;

    if (crossedLoopBoundary && index == _currentIndex) {
      _armedForCompletion[index] = false;
      widget.onCompleted?.call(index);
    }

    _lastPositions[index] = position;
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _pageController,
      scrollDirection: Axis.vertical,
      onPageChanged: _onPageChanged,
      itemCount: widget.videos.length,
      itemBuilder: (context, index) {
        final video = widget.videos[index];
        final videoUrl = video.videoUrl;
        final isActive = index == _currentIndex;

        if (videoUrl == null || videoUrl.isEmpty) {
          return const ColoredBox(color: VineTheme.backgroundColor);
        }

        final playerKey = _getPlayerKey(index);

        return _WebVideoFeedItem(
          video: video,
          index: index,
          isActive: isActive,
          videoUrl: videoUrl,
          playerKey: playerKey,
          headers: widget.headers,
          controllerFactory: widget.controllerFactory,
          controllersListenable: _controllers,
          itemBuilder: widget.itemBuilder,
          onInitialized: (controller) {
            if (!mounted) return;
            setState(() {
              _attachCompletionListener(index, controller);
            });
          },
          onDisposed: () {
            if (!mounted) return;
            _onPlayerDisposed(index);
          },
          onError: () {
            if (!mounted) return;
            widget.onErrored?.call(index);
          },
        );
      },
    );
  }
}

/// Per-item content of the web video feed.
///
/// Splits the stack so that the overlay subtree rebuilds via
/// [ValueListenableBuilder] when its controller becomes available, instead
/// of rebuilding the entire [PageView.builder] via `setState` on the parent.
class _WebVideoFeedItem extends StatelessWidget {
  const _WebVideoFeedItem({
    required this.video,
    required this.index,
    required this.isActive,
    required this.videoUrl,
    required this.playerKey,
    required this.headers,
    required this.controllerFactory,
    required this.controllersListenable,
    required this.itemBuilder,
    required this.onInitialized,
    required this.onDisposed,
    required this.onError,
  });

  final VideoEvent video;
  final int index;
  final bool isActive;
  final String videoUrl;
  final GlobalKey<WebVideoPlayerState> playerKey;
  final Map<String, String> headers;
  final WebVideoPlayerControllerFactory controllerFactory;
  final ValueListenable<Map<int, VideoPlayerController>> controllersListenable;
  final WebVideoFeedItemBuilder? itemBuilder;
  final ValueChanged<VideoPlayerController> onInitialized;
  final VoidCallback onDisposed;
  final VoidCallback onError;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        WebVideoPlayer(
          key: playerKey,
          url: videoUrl,
          autoPlay: isActive,
          headers: headers,
          controllerFactory: controllerFactory,
          onInitialized: onInitialized,
          onDisposed: onDisposed,
          onError: onError,
        ),
        if (itemBuilder != null)
          ValueListenableBuilder<Map<int, VideoPlayerController>>(
            valueListenable: controllersListenable,
            builder: (context, controllers, _) {
              // Only expose the controller once it has initialized so
              // overlays never receive an uninitialized controller.
              final tracked = controllers[index];
              final controller =
                  (tracked != null && tracked.value.isInitialized)
                  ? tracked
                  : null;
              return itemBuilder!(
                context,
                video,
                index,
                isActive: isActive,
                controller: controller,
              );
            },
          ),
      ],
    );
  }
}
