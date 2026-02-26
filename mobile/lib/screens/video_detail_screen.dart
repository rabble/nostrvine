// ABOUTME: Screen for viewing a specific video by ID (from deep links)
// ABOUTME: Fetches video from Nostr and displays it in full-screen player

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/services/screen_analytics_service.dart';
import 'package:openvine/services/view_event_publisher.dart';
import 'package:openvine/utils/unified_logger.dart';

class VideoDetailScreen extends ConsumerStatefulWidget {
  /// Route name for this screen.
  static const routeName = 'video';

  /// Base path for video routes.
  static const basePath = '/video';

  /// Path pattern for this route.
  static const path = '/video/:id';

  /// Build path for a specific video ID.
  static String pathForId(String id) => '$basePath/$id';

  const VideoDetailScreen({required this.videoId, super.key});

  final String videoId;

  @override
  ConsumerState<VideoDetailScreen> createState() => _VideoDetailScreenState();
}

class _VideoDetailScreenState extends ConsumerState<VideoDetailScreen> {
  VideoEvent? _video;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadVideo();
  }

  Future<void> _loadVideo() async {
    try {
      Log.info(
        '📱 Loading video by ID: ${widget.videoId}',
        name: 'VideoDetailScreen',
        category: LogCategory.video,
      );

      final videoEventService = ref.read(videoEventServiceProvider);

      // Try to find video in existing loaded events first
      final video = videoEventService.getVideoById(widget.videoId);

      if (video != null) {
        Log.info(
          '✅ Found video in cache: ${video.title}',
          name: 'VideoDetailScreen',
          category: LogCategory.video,
        );
        if (mounted) {
          setState(() {
            _video = video;
            _isLoading = false;
          });
          ScreenAnalyticsService().markDataLoaded('video_detail');
        }
        return;
      }

      // Video not in cache, fetch from Nostr
      Log.info(
        '🔍 Video not in cache, fetching from Nostr...',
        name: 'VideoDetailScreen',
        category: LogCategory.video,
      );

      final nostrService = ref.read(nostrServiceProvider);
      final event = await nostrService.fetchEventById(widget.videoId);

      if (event != null) {
        final fetchedVideo = VideoEvent.fromNostrEvent(event);

        Log.info(
          '✅ Fetched video from Nostr: ${fetchedVideo.title}',
          name: 'VideoDetailScreen',
          category: LogCategory.video,
        );
        if (mounted) {
          setState(() {
            _video = fetchedVideo;
            _isLoading = false;
          });
          ScreenAnalyticsService().markDataLoaded('video_detail');
        }
      } else {
        Log.warning(
          '❌ Video not found: ${widget.videoId}',
          name: 'VideoDetailScreen',
          category: LogCategory.video,
        );
        if (mounted) {
          setState(() {
            _error = 'Video not found';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      Log.error(
        'Error loading video: $e',
        name: 'VideoDetailScreen',
        category: LogCategory.video,
      );
      if (mounted) {
        setState(() {
          _error = 'Failed to load video: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: VineTheme.backgroundColor,
        body: Center(
          child: CircularProgressIndicator(color: VineTheme.vineGreen),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: VineTheme.backgroundColor,
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 64),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(
                  color: VineTheme.primaryText,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (_video == null) {
      return const Scaffold(
        backgroundColor: VineTheme.backgroundColor,
        body: Center(
          child: Text(
            'Video not found',
            style: TextStyle(color: VineTheme.primaryText),
          ),
        ),
      );
    }

    // Check if video author has muted us (mutual mute blocking)
    final blocklistService = ref.watch(contentBlocklistServiceProvider);
    if (blocklistService.shouldFilterFromFeeds(_video!.pubkey)) {
      return Scaffold(
        backgroundColor: VineTheme.backgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back,
              color: Colors.white,
              semanticLabel: 'Close video player',
            ),
            onPressed: context.pop,
          ),
        ),
        body: const Center(
          child: Text(
            'This account is not available',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ),
      );
    }

    // Display video in full-screen pooled player
    return PooledFullscreenVideoFeedScreen(
      videosStream: Stream.value([_video!]),
      initialIndex: 0,
      contextTitle: 'Shared Video',
      trafficSource: ViewTrafficSource.share,
    );
  }
}
