// ABOUTME: Web-specific video feed using PageView and video_player package
// ABOUTME: Replacement for native PooledVideoFeed on Flutter web platform

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:models/models.dart';
import 'package:openvine/widgets/web_video_player.dart';

/// A simple vertical-swipe video feed for Flutter web.
///
/// Uses [PageView] with [WebVideoPlayer] widgets. Only the active page
/// plays; when the user swipes, the previous player is paused and the
/// new one starts.
class WebVideoFeed extends StatefulWidget {
  const WebVideoFeed({
    required this.videos,
    this.initialIndex = 0,
    this.onActiveVideoChanged,
    super.key,
  });

  /// The list of videos to display.
  final List<VideoEvent> videos;

  /// The initial page index.
  final int initialIndex;

  /// Called when the active video changes.
  final void Function(VideoEvent video, int index)? onActiveVideoChanged;

  @override
  State<WebVideoFeed> createState() => _WebVideoFeedState();
}

class _WebVideoFeedState extends State<WebVideoFeed> {
  late PageController _pageController;
  late int _currentIndex;
  final Map<int, GlobalKey<WebVideoPlayerState>> _playerKeys = {};

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

  GlobalKey<WebVideoPlayerState> _keyForIndex(int index) {
    return _playerKeys.putIfAbsent(
      index,
      GlobalKey<WebVideoPlayerState>.new,
    );
  }

  void _onPageChanged(int index) {
    // Pause previous
    _playerKeys[_currentIndex]?.currentState?.pause();

    _currentIndex = index;

    // Play new
    _playerKeys[_currentIndex]?.currentState?.play();

    widget.onActiveVideoChanged?.call(widget.videos[index], index);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.videos.isEmpty) {
      return const ColoredBox(
        color: VineTheme.backgroundColor,
        child: Center(
          child: Text(
            'No videos available',
            style: TextStyle(color: VineTheme.lightText),
          ),
        ),
      );
    }

    return ColoredBox(
      color: VineTheme.backgroundColor,
      child: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: widget.videos.length,
        onPageChanged: _onPageChanged,
        itemBuilder: (context, index) {
          final video = widget.videos[index];
          final url = video.videoUrl;
          if (url == null || url.isEmpty) {
            return const ColoredBox(
              color: VineTheme.backgroundColor,
              child: Center(
                child: Text(
                  'Video unavailable',
                  style: TextStyle(color: VineTheme.lightText),
                ),
              ),
            );
          }

          return WebVideoPlayer(
            key: _keyForIndex(index),
            videoUrl: url,
            thumbnailUrl: video.thumbnailUrl,
            autoplay: index == _currentIndex,
          );
        },
      ),
    );
  }
}
