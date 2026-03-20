// ABOUTME: Detail screen for viewing a sound and videos using that sound.
// ABOUTME: Displays sound info, preview/use buttons, and grid of related videos.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/models/audio_event.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/sound_library_service_provider.dart';
import 'package:openvine/providers/sounds_providers.dart';
import 'package:openvine/services/screen_analytics_service.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/video_feed_item/video_feed_item.dart';
import 'package:sound_service/sound_service.dart';
import 'package:url_launcher/url_launcher.dart';

/// Screen displaying details of a specific sound and videos using it.
///
/// Features:
/// - Sound header with title, duration, and video count
/// - Preview button to play/stop audio preview
/// - Use Sound button to select for recording
/// - Grid of videos using this sound
class SoundDetailScreen extends ConsumerStatefulWidget {
  /// Route name for this screen.
  static const routeName = 'sound';

  /// Base path for sound routes.
  static const basePath = '/sound';

  /// Path pattern for this route.
  static const path = '/sound/:id';

  /// Build path for a specific sound ID.
  static String pathForId(String id) => '$basePath/$id';

  /// Creates a SoundDetailScreen.
  ///
  /// [sound] is the audio event to display.
  const SoundDetailScreen({required this.sound, super.key});

  /// The audio event to display details for.
  final AudioEvent sound;

  @override
  ConsumerState<SoundDetailScreen> createState() => _SoundDetailScreenState();
}

class _SoundDetailScreenState extends ConsumerState<SoundDetailScreen> {
  bool _isPlayingPreview = false;
  bool _isLoadingPreview = false;

  /// Whether the video feed overlay is showing
  bool _showingVideoFeed = false;

  /// Starting index for video feed
  int _videoFeedStartIndex = 0;

  /// List of videos for the feed (populated when grid loads)
  List<VideoEvent> _videosForFeed = [];

  /// Cached reference to audio service for safe disposal
  AudioPlaybackService? _audioService;

  @override
  void dispose() {
    // Stop any playing preview when leaving the screen
    if (_isPlayingPreview && _audioService != null) {
      _audioService!.stop();
    }
    super.dispose();
  }

  Future<void> _togglePreview() async {
    if (_isLoadingPreview) return;

    // Cache audio service for safe disposal
    _audioService ??= ref.read(audioPlaybackServiceProvider);
    final audioService = _audioService!;

    if (_isPlayingPreview) {
      // Stop playing
      await audioService.stop();
      if (mounted) {
        setState(() {
          _isPlayingPreview = false;
        });
      }
      return;
    }

    // Check if sound has a URL to play
    if (widget.sound.url == null || widget.sound.url!.isEmpty) {
      Log.warning(
        'Cannot preview sound: no URL available (${widget.sound.id})',
        name: 'SoundDetailScreen',
        category: LogCategory.ui,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to preview sound - no audio available'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    setState(() {
      _isLoadingPreview = true;
    });

    try {
      Log.info(
        'Starting preview for sound: ${widget.sound.title} (${widget.sound.id})',
        name: 'SoundDetailScreen',
        category: LogCategory.ui,
      );

      await audioService.loadAudio(widget.sound.url!);
      if (mounted) {
        setState(() {
          _isPlayingPreview = true;
          _isLoadingPreview = false;
        });
      }
      await audioService.play();

      if (mounted) {
        setState(() {
          _isPlayingPreview = true;
          _isLoadingPreview = false;
        });
      }
    } catch (e) {
      Log.error(
        'Failed to preview sound: $e',
        name: 'SoundDetailScreen',
        category: LogCategory.ui,
      );
      if (mounted) {
        setState(() {
          _isPlayingPreview = false;
          _isLoadingPreview = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to play preview: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _onUseSound() {
    Log.info(
      'Using sound: ${widget.sound.title} (${widget.sound.id})',
      name: 'SoundDetailScreen',
      category: LogCategory.ui,
    );

    // Stop preview if playing
    if (_isPlayingPreview && _audioService != null) {
      _audioService!.stop();
    }

    // Set the selected sound via provider
    ref.read(selectedSoundProvider.notifier).select(widget.sound);

    // Pop with result indicating success
    context.pop(true);
  }

  void _navigateToVideo(String videoId, int index, List<VideoEvent> videos) {
    Log.info(
      'Showing video feed at index $index for video: $videoId',
      name: 'SoundDetailScreen',
      category: LogCategory.ui,
    );

    // Stop preview if playing before showing video feed
    if (_isPlayingPreview && _audioService != null) {
      _audioService!.stop();
      setState(() {
        _isPlayingPreview = false;
      });
    }

    // Show video feed overlay instead of navigating away
    setState(() {
      _videosForFeed = videos;
      _videoFeedStartIndex = index;
      _showingVideoFeed = true;
    });
  }

  void _closeVideoFeed() {
    Log.info(
      'Closing video feed overlay',
      name: 'SoundDetailScreen',
      category: LogCategory.ui,
    );
    setState(() {
      _showingVideoFeed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final usageCountAsync = ref.watch(soundUsageCountProvider(widget.sound.id));

    return Scaffold(
      backgroundColor: VineTheme.backgroundColor,
      appBar: _showingVideoFeed
          ? null
          : DiVineAppBar(
              title: 'Sound',
              showBackButton: true,
              onBackPressed: context.pop,
              backgroundColor: VineTheme.cardBackground,
            ),
      body: Stack(
        children: [
          // Main content
          Semantics(
            identifier: 'sound_detail_screen_${widget.sound.id}',
            container: true,
            child: Column(
              children: [
                // Sound header
                _SoundHeader(
                  sound: widget.sound,
                  usageCount: usageCountAsync.value ?? 0,
                  isPlaying: _isPlayingPreview,
                  isLoadingPreview: _isLoadingPreview,
                  onPreviewTap: _togglePreview,
                  onUseSoundTap: _onUseSound,
                ),

                // Divider
                const Divider(color: VineTheme.cardBackground, height: 1),

                // Videos section header
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.videocam,
                        color: VineTheme.vineGreen,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Videos using this sound',
                        style: TextStyle(
                          color: VineTheme.whiteText,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                // Videos grid
                Expanded(
                  child: _VideosGrid(
                    audioEventId: widget.sound.id,
                    onVideoTap: _navigateToVideo,
                  ),
                ),
              ],
            ),
          ),

          // Video feed overlay
          if (_showingVideoFeed && _videosForFeed.isNotEmpty)
            _SoundVideoFeedOverlay(
              videos: _videosForFeed,
              startIndex: _videoFeedStartIndex,
              soundTitle: widget.sound.title ?? 'Original sound',
              onClose: _closeVideoFeed,
            ),
        ],
      ),
    );
  }
}

/// Header section displaying sound info and action buttons.
class _SoundHeader extends ConsumerStatefulWidget {
  const _SoundHeader({
    required this.sound,
    required this.usageCount,
    required this.isPlaying,
    required this.isLoadingPreview,
    required this.onPreviewTap,
    required this.onUseSoundTap,
  });

  final AudioEvent sound;
  final int usageCount;
  final bool isPlaying;
  final bool isLoadingPreview;
  final VoidCallback onPreviewTap;
  final VoidCallback onUseSoundTap;

  @override
  ConsumerState<_SoundHeader> createState() => _SoundHeaderState();
}

class _SoundHeaderState extends ConsumerState<_SoundHeader> {
  String? _artistName;
  String? _license;
  String? _sourceUrl;

  @override
  void initState() {
    super.initState();
    _lookUpAttribution();
  }

  void _lookUpAttribution() {
    final sound = widget.sound;
    if (!sound.isBundled) return;

    final soundId = sound.id.replaceFirst('${AudioEvent.bundledMarker}_', '');
    final service = ref.read(soundLibraryServiceSyncProvider);
    final vineSound = service.getSoundById(soundId);
    if (vineSound != null) {
      _artistName = vineSound.artist;
      _license = vineSound.license;
      _sourceUrl = vineSound.sourceUrl;
    }
  }

  String get _formattedDuration {
    final seconds = widget.sound.duration;
    if (seconds == null || seconds <= 0) return '';
    if (seconds < 60) {
      return '${seconds.toStringAsFixed(1)}s';
    }
    final minutes = (seconds / 60).floor();
    final remainingSeconds = (seconds % 60).toStringAsFixed(0);
    return '$minutes:${remainingSeconds.padLeft(2, '0')}';
  }

  String get _videoCountText {
    if (widget.usageCount == 0) return 'No videos yet';
    if (widget.usageCount == 1) return '1 video';
    return '${widget.usageCount} videos';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: VineTheme.cardBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sound title and icon
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: VineTheme.vineGreen.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.music_note,
                  color: VineTheme.vineGreen,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 4,
                  children: [
                    Text(
                      widget.sound.title ?? 'Original sound',
                      style: const TextStyle(
                        color: VineTheme.whiteText,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    _buildMetadataRow(),
                    if (_artistName != null)
                      _AttributionInfo(
                        artistName: _artistName!,
                        license: _license,
                        sourceUrl: _sourceUrl,
                      ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Action buttons
          Row(
            children: [
              // Preview button
              Expanded(
                child: Semantics(
                  identifier: 'sound_detail_preview_button',
                  button: true,
                  child: OutlinedButton.icon(
                    onPressed: widget.onPreviewTap,
                    icon: widget.isLoadingPreview
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: VineTheme.vineGreen,
                              strokeWidth: 2,
                            ),
                          )
                        : Icon(
                            widget.isPlaying ? Icons.stop : Icons.play_arrow,
                            size: 20,
                          ),
                    label: Text(widget.isPlaying ? 'Stop' : 'Preview'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: VineTheme.vineGreen,
                      side: const BorderSide(color: VineTheme.vineGreen),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Use Sound button
              Expanded(
                child: Semantics(
                  identifier: 'sound_detail_use_button',
                  button: true,
                  child: ElevatedButton.icon(
                    onPressed: widget.onUseSoundTap,
                    icon: const Icon(Icons.add, size: 20),
                    label: const Text('Use Sound'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: VineTheme.vineGreen,
                      foregroundColor: VineTheme.backgroundColor,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataRow() {
    final items = <String>[];

    final duration = _formattedDuration;
    if (duration.isNotEmpty) {
      items.add(duration);
    }

    items.add(_videoCountText);

    return Text(
      items.join(' · '),
      style: const TextStyle(color: VineTheme.secondaryText, fontSize: 14),
    );
  }
}

/// Displays artist name, license, and optional "View on Freesound" link.
class _AttributionInfo extends StatelessWidget {
  const _AttributionInfo({
    required this.artistName,
    this.license,
    this.sourceUrl,
  });

  final String artistName;
  final String? license;
  final String? sourceUrl;

  @override
  Widget build(BuildContext context) {
    final attributionText = [
      'by $artistName',
      if (license != null) license,
    ].join(' · ');

    return Text.rich(
      TextSpan(
        style: const TextStyle(
          color: VineTheme.secondaryText,
          fontSize: 12,
        ),
        children: [
          TextSpan(text: attributionText),
          if (sourceUrl != null) ...[
            const TextSpan(text: ' · '),
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: GestureDetector(
                onTap: () async {
                  final uri = Uri.parse(sourceUrl!);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(
                      uri,
                      mode: LaunchMode.externalApplication,
                    );
                  }
                },
                child: const Text(
                  'View source',
                  style: TextStyle(
                    color: VineTheme.vineGreen,
                    fontSize: 12,
                    decoration: TextDecoration.underline,
                    decorationColor: VineTheme.vineGreen,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Grid of videos using the specified sound.
class _VideosGrid extends ConsumerWidget {
  const _VideosGrid({required this.audioEventId, required this.onVideoTap});

  final String audioEventId;
  final void Function(String videoId, int index, List<VideoEvent> videos)
  onVideoTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videosAsync = ref.watch(videosUsingSoundProvider(audioEventId));

    return videosAsync.when(
      data: (videoIds) {
        if (videoIds.isEmpty) {
          return _buildEmptyState();
        }

        return _VideosGridContent(videoIds: videoIds, onVideoTap: onVideoTap);
      },
      loading: () => const Center(child: BrandedLoadingIndicator(size: 60)),
      error: (error, stack) => _buildErrorState(error, () {
        ref.invalidate(videosUsingSoundProvider(audioEventId));
      }),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.videocam_off_outlined,
            size: 64,
            color: VineTheme.lightText,
          ),
          SizedBox(height: 16),
          Text(
            'No videos yet',
            style: TextStyle(
              color: VineTheme.whiteText,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Be the first to use this sound!',
            style: TextStyle(color: VineTheme.onSurfaceMuted, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(Object error, VoidCallback onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: VineTheme.likeRed),
            const SizedBox(height: 16),
            const Text(
              'Failed to load videos',
              style: TextStyle(
                color: VineTheme.whiteText,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: const TextStyle(
                color: VineTheme.onSurfaceMuted,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: VineTheme.vineGreen,
                foregroundColor: VineTheme.backgroundColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Content widget that fetches and displays video events in a grid.
class _VideosGridContent extends ConsumerStatefulWidget {
  const _VideosGridContent({required this.videoIds, required this.onVideoTap});

  final List<String> videoIds;
  final void Function(String videoId, int index, List<VideoEvent> videos)
  onVideoTap;

  @override
  ConsumerState<_VideosGridContent> createState() => _VideosGridContentState();
}

class _VideosGridContentState extends ConsumerState<_VideosGridContent> {
  Map<String, VideoEvent?> _videoEvents = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchVideoEvents();
  }

  @override
  void didUpdateWidget(_VideosGridContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.videoIds != oldWidget.videoIds) {
      _fetchVideoEvents();
    }
  }

  Future<void> _fetchVideoEvents() async {
    setState(() {
      _isLoading = true;
    });

    final videoEventService = ref.read(videoEventServiceProvider);
    final nostrService = ref.read(nostrServiceProvider);
    final events = <String, VideoEvent?>{};

    for (final videoId in widget.videoIds) {
      // First try to get from cache
      var video = videoEventService.getVideoById(videoId);

      // If not in cache, fetch from Nostr
      if (video == null) {
        try {
          final event = await nostrService.fetchEventById(videoId);
          if (event != null) {
            video = VideoEvent.fromNostrEvent(event);
          }
        } catch (e) {
          Log.error(
            'Failed to fetch video $videoId: $e',
            name: 'SoundDetailScreen',
            category: LogCategory.video,
          );
        }
      }

      if (video != null && videoEventService.shouldHideVideo(video)) {
        video = null;
      }

      events[videoId] = video;
    }

    if (mounted) {
      setState(() {
        _videoEvents = events;
        _isLoading = false;
      });
      ScreenAnalyticsService().markDataLoaded(
        'sound_detail',
        dataMetrics: {'video_count': events.length},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(divineHostFilterVersionProvider);
    final videoEventService = ref.read(videoEventServiceProvider);
    if (_isLoading) {
      return const Center(child: BrandedLoadingIndicator(size: 60));
    }

    final validVideos = widget.videoIds.where((id) {
      final video = _videoEvents[id];
      return video != null && !videoEventService.shouldHideVideo(video);
    }).toList();

    if (validVideos.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.videocam_off_outlined,
              size: 64,
              color: VineTheme.lightText,
            ),
            SizedBox(height: 16),
            Text(
              'Videos unavailable',
              style: TextStyle(
                color: VineTheme.whiteText,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Could not load video details',
              style: TextStyle(color: VineTheme.onSurfaceMuted, fontSize: 14),
            ),
          ],
        ),
      );
    }

    // Build list of valid video events in order
    final videosList = validVideos.map((id) => _videoEvents[id]!).toList();

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(2),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 2,
              mainAxisSpacing: 2,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              final video = videosList[index];
              return _VideoGridTile(
                video: video,
                onTap: () => widget.onVideoTap(video.id, index, videosList),
              );
            }, childCount: videosList.length),
          ),
        ),
      ],
    );
  }
}

/// Individual video tile in the grid.
class _VideoGridTile extends StatelessWidget {
  const _VideoGridTile({required this.video, required this.onTap});

  final VideoEvent video;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: VineTheme.cardBackground,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: _VideoThumbnail(thumbnailUrl: video.thumbnailUrl),
              ),
            ),
            const Center(
              child: Icon(
                Icons.play_circle_filled,
                color: VineTheme.onSurfaceVariant,
                size: 32,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Video thumbnail with loading and error states.
class _VideoThumbnail extends StatelessWidget {
  const _VideoThumbnail({required this.thumbnailUrl});

  final String? thumbnailUrl;

  @override
  Widget build(BuildContext context) {
    if (thumbnailUrl != null && thumbnailUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: thumbnailUrl!,
        fit: BoxFit.cover,
        placeholder: (context, url) => const _ThumbnailPlaceholder(),
        errorWidget: (context, url, error) => const _ThumbnailPlaceholder(),
      );
    }
    return const _ThumbnailPlaceholder();
  }
}

/// Gradient placeholder for thumbnails.
class _ThumbnailPlaceholder extends StatelessWidget {
  const _ThumbnailPlaceholder();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        gradient: LinearGradient(
          colors: [
            VineTheme.vineGreen.withValues(alpha: 0.3),
            VineTheme.info.withValues(alpha: 0.3),
          ],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.play_circle_outline,
          color: VineTheme.whiteText,
          size: 24,
        ),
      ),
    );
  }
}

/// Full-screen video feed overlay for browsing videos using a sound.
///
/// Shows a swipeable PageView of videos with a header showing sound info
/// and a close button to return to the grid view.
class _SoundVideoFeedOverlay extends StatefulWidget {
  const _SoundVideoFeedOverlay({
    required this.videos,
    required this.startIndex,
    required this.soundTitle,
    required this.onClose,
  });

  final List<VideoEvent> videos;
  final int startIndex;
  final String soundTitle;
  final VoidCallback onClose;

  @override
  State<_SoundVideoFeedOverlay> createState() => _SoundVideoFeedOverlayState();
}

class _SoundVideoFeedOverlayState extends State<_SoundVideoFeedOverlay> {
  late PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.startIndex;
    _pageController = PageController(initialPage: widget.startIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: VineTheme.backgroundColor,
      child: SafeArea(
        child: Stack(
          children: [
            // Video PageView
            PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              itemCount: widget.videos.length,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              itemBuilder: (context, index) {
                final video = widget.videos[index];
                return VideoFeedItem(
                  key: ValueKey('sound-video-${video.id}'),
                  video: video,
                  index: index,
                  hasBottomNavigation: false,
                  contextTitle: widget.soundTitle,
                );
              },
            ),

            // Header with close button and sound title
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      VineTheme.backgroundColor.withValues(alpha: 0.7),
                      VineTheme.transparent,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    // Close button
                    IconButton(
                      icon: const Icon(Icons.close, color: VineTheme.whiteText),
                      onPressed: widget.onClose,
                      tooltip: 'Close',
                    ),

                    // Sound title
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.music_note,
                            color: VineTheme.vineGreen,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              widget.soundTitle,
                              style: const TextStyle(
                                color: VineTheme.whiteText,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Video counter
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        '${_currentIndex + 1}/${widget.videos.length}',
                        style: const TextStyle(
                          color: VineTheme.secondaryText,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
