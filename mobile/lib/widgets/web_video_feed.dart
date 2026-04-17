// ABOUTME: Web-native video feed using Flutter's video_player package
// ABOUTME: Replaces PooledVideoFeed on web where media_kit is not available

import 'package:divine_ui/divine_ui.dart';
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

  // Track web player keys to control playback
  final Map<int, GlobalKey<WebVideoPlayerState>> _playerKeys = {};
  final Map<int, VideoPlayerController> _controllers = {};
  final Map<int, VoidCallback> _controllerListeners = {};
  final Map<int, Duration> _lastPositions = {};
  final Map<int, bool> _armedForCompletion = {};

  int get currentIndex => _currentIndex;
  int get videoCount => widget.videos.length;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    for (final entry in _controllers.entries) {
      _detachCompletionListener(entry.key, entry.value);
    }
    _pageController.dispose();
    super.dispose();
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
    return _playerKeys.putIfAbsent(
      index,
      GlobalKey<WebVideoPlayerState>.new,
    );
  }

  void _attachCompletionListener(
    int index,
    VideoPlayerController controller,
  ) {
    final previousController = _controllers[index];
    if (identical(previousController, controller) &&
        _controllerListeners.containsKey(index)) {
      return;
    }

    if (previousController != null) {
      _detachCompletionListener(index, previousController);
    }

    _controllers[index] = controller;
    _lastPositions[index] = controller.value.position;
    _armedForCompletion[index] = false;

    void listener() => _handleControllerTick(index, controller);

    _controllerListeners[index] = listener;
    controller.addListener(listener);
  }

  void _detachCompletionListener(
    int index,
    VideoPlayerController controller,
  ) {
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

        return Stack(
          fit: StackFit.expand,
          children: [
            // Video layer
            WebVideoPlayer(
              key: playerKey,
              url: videoUrl,
              autoPlay: isActive,
              headers: widget.headers,
              controllerFactory: widget.controllerFactory,
              onInitialized: (controller) {
                if (!mounted) return;
                setState(() {
                  _attachCompletionListener(index, controller);
                });
              },
              onError: () {
                if (!mounted) return;
                widget.onErrored?.call(index);
              },
            ),
            // Custom overlay layer
            if (widget.itemBuilder != null)
              widget.itemBuilder!(
                context,
                video,
                index,
                isActive: isActive,
                controller:
                    _controllers[index] ?? playerKey.currentState?.controller,
              ),
          ],
        );
      },
    );
  }
}
