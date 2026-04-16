// ABOUTME: Web-native video feed using Flutter's video_player package
// ABOUTME: Replaces PooledVideoFeed on web where media_kit is not available

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:models/models.dart';
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
    this.onNearEnd,
    this.nearEndThreshold = 3,
    this.headers = const {},
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

  /// Called when near the end of the list for pagination.
  final void Function(int index)? onNearEnd;

  /// How many videos from the end should trigger [onNearEnd].
  final int nearEndThreshold;

  /// HTTP headers for video requests.
  final Map<String, String> headers;

  /// Factory used to create underlying web video controllers.
  final WebVideoPlayerControllerFactory controllerFactory;

  @override
  State<WebVideoFeed> createState() => _WebVideoFeedState();
}

class _WebVideoFeedState extends State<WebVideoFeed> {
  late PageController _pageController;
  int _currentIndex = 0;

  // Track web player keys to control playback
  final Map<int, GlobalKey<WebVideoPlayerState>> _playerKeys = {};
  final Map<int, VideoPlayerController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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
                  _controllers[index] = controller;
                });
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
