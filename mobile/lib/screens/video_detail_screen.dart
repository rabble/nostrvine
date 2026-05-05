// ABOUTME: Screen for viewing a specific video by ID (from deep links)
// ABOUTME: Fetches video from Nostr and displays it in full-screen player

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:nostr_client/nostr_client.dart' show NostrClient;
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/services/screen_analytics_service.dart';
import 'package:openvine/services/view_event_publisher.dart';
import 'package:unified_logger/unified_logger.dart';

class VideoDetailScreen extends ConsumerStatefulWidget {
  /// Route name for this screen.
  static const routeName = 'video';

  /// Base path for video routes.
  static const basePath = '/video';

  /// Path pattern for this route.
  static const path = '/video/:id';

  /// Build path for a specific video route reference.
  ///
  /// The route segment may be a raw event ID, a stable ID / d-tag, or
  /// a NIP-19 reference such as `note1...`, `nevent1...`, or `naddr1...`.
  static String pathForId(String id) => '$basePath/$id';

  const VideoDetailScreen({
    required this.videoId,
    this.videoFeedBuilder,
    super.key,
  });

  final String videoId;
  final Widget Function(VideoEvent video)? videoFeedBuilder;

  @override
  ConsumerState<VideoDetailScreen> createState() => _VideoDetailScreenState();
}

class _VideoDetailScreenState extends ConsumerState<VideoDetailScreen> {
  VideoEvent? _video;
  bool _isLoading = true;
  String? _error;
  StreamSubscription? _relayReadySubscription;
  bool _retryScheduled = false;
  bool _hasRetriedAfterRelayReady = false;

  @override
  void initState() {
    super.initState();
    _loadVideo();
  }

  @override
  void didUpdateWidget(covariant VideoDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoId == widget.videoId) return;

    // Deep links can retarget an already-mounted video screen. Reset the
    // previous request state so the second shared link triggers a fresh load.
    _relayReadySubscription?.cancel();
    _relayReadySubscription = null;
    _retryScheduled = false;
    _hasRetriedAfterRelayReady = false;

    setState(() {
      _video = null;
      _isLoading = true;
      _error = null;
    });

    unawaited(_loadVideo());
  }

  @override
  void dispose() {
    _relayReadySubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadVideo({bool allowRelayReadyRetry = true}) async {
    try {
      Log.info(
        '📱 Loading video from route ref: ${widget.videoId}',
        name: 'VideoDetailScreen',
        category: LogCategory.video,
      );

      final nostrClient = ref.read(nostrServiceProvider);
      final canQueryRelays =
          nostrClient.isInitialized && nostrClient.connectedRelayCount > 0;

      // fetchVideoWithStats handles cache→relay lookup and bulk-stats
      // hydration in one call, matching what feed providers do.
      final videosRepository = ref.read(videosRepositoryProvider);
      final video = await videosRepository.fetchVideoWithStatsForRouteId(
        widget.videoId,
      );

      if (video != null) {
        Log.info(
          '✅ Loaded video: ${video.title}',
          name: 'VideoDetailScreen',
          category: LogCategory.video,
        );
        if (mounted) {
          setState(() {
            _video = video;
            _isLoading = false;
            _error = null;
          });
          ScreenAnalyticsService().markDataLoaded('video_detail');
        }
      } else {
        if (allowRelayReadyRetry &&
            !canQueryRelays &&
            _scheduleRelayReadyRetry(nostrClient)) {
          // Cold-start links can arrive before the relay layer is queryable.
          // Retry once after the first relay connection instead of surfacing a
          // permanent "Video not found" during startup.
          Log.info(
            '⏳ Video lookup deferred until relay connection is ready',
            name: 'VideoDetailScreen',
            category: LogCategory.video,
          );
          return;
        }
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
      final nostrClient = ref.read(nostrServiceProvider);
      final canQueryRelays =
          nostrClient.isInitialized && nostrClient.connectedRelayCount > 0;
      if (allowRelayReadyRetry &&
          !canQueryRelays &&
          _scheduleRelayReadyRetry(nostrClient)) {
        Log.warning(
          '⏳ Video lookup failed before relay readiness; waiting to retry: $e',
          name: 'VideoDetailScreen',
          category: LogCategory.video,
        );
        return;
      }
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

  bool _scheduleRelayReadyRetry(NostrClient nostrClient) {
    if (_retryScheduled || _hasRetriedAfterRelayReady) {
      return false;
    }

    _retryScheduled = true;
    _relayReadySubscription?.cancel();

    void retry() {
      _relayReadySubscription?.cancel();
      _relayReadySubscription = null;
      _retryScheduled = false;
      _hasRetriedAfterRelayReady = true;
      if (!mounted) return;
      setState(() {
        _isLoading = true;
        _error = null;
      });
      unawaited(_loadVideo(allowRelayReadyRetry: false));
    }

    if (nostrClient.isInitialized && nostrClient.connectedRelayCount > 0) {
      retry();
      return true;
    }

    _relayReadySubscription = nostrClient.relayStatusStream.listen((statuses) {
      final hasConnectedRelay = statuses.values.any(
        (status) => status.isConnected,
      );
      if (hasConnectedRelay) {
        retry();
      }
    });
    return true;
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(blocklistVersionProvider);
    ref.watch(divineHostFilterVersionProvider);
    final videoEventService = ref.read(videoEventServiceProvider);

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
        appBar: _buildExitAppBar(context),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: VineTheme.error, size: 64),
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

    if (_video == null || videoEventService.shouldHideVideo(_video!)) {
      return Scaffold(
        backgroundColor: VineTheme.backgroundColor,
        appBar: _buildExitAppBar(context),
        body: const Center(
          child: Text(
            'Video not found',
            style: TextStyle(color: VineTheme.primaryText),
          ),
        ),
      );
    }

    // Display video in full-screen pooled player
    return widget.videoFeedBuilder?.call(_video!) ??
        PooledFullscreenVideoFeedScreen(
          videosStream: Stream.value([_video!]),
          initialIndex: 0,
          removedIdsStream: ref.read(videoEventServiceProvider).removedVideoIds,
          contextTitle: 'Shared Video',
          trafficSource: ViewTrafficSource.share,
        );
  }

  DiVineAppBar _buildExitAppBar(BuildContext context) {
    return DiVineAppBar(
      title: '',
      showBackButton: true,
      onBackPressed: () => _handleExit(context),
      backButtonSemanticLabel: 'Close video player',
      backgroundMode: DiVineAppBarBackgroundMode.transparent,
    );
  }

  void _handleExit(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/');
  }
}
