// ABOUTME: Smart video thumbnail widget that displays thumbnails or blurhash placeholders
// ABOUTME: Uses existing thumbnail URLs from video events and falls back to blurhash when missing

import 'package:cached_network_image/cached_network_image.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:models/models.dart' hide LogCategory, AspectRatio;
import 'package:openvine/extensions/video_event_extensions.dart';
import 'package:openvine/services/image_cache_manager.dart';
import 'package:openvine/services/thumbnail_api_service.dart'
    show ThumbnailSize;
import 'package:openvine/utils/unified_logger.dart';

/// Smart thumbnail widget that displays thumbnails with blurhash fallback
class VideoThumbnailWidget extends StatefulWidget {
  const VideoThumbnailWidget({
    required this.video,
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.timeSeconds = 2.5,
    this.size = ThumbnailSize.medium,
    this.showPlayIcon = false,
    this.borderRadius,
  });
  final VideoEvent video;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double timeSeconds;
  final ThumbnailSize size;
  final bool showPlayIcon;
  final BorderRadius? borderRadius;

  @override
  State<VideoThumbnailWidget> createState() => _VideoThumbnailWidgetState();
}

class _VideoThumbnailWidgetState extends State<VideoThumbnailWidget> {
  String? _thumbnailUrl;
  bool _isLoading = false;
  double? _resolvedAspectRatio;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  @override
  void didUpdateWidget(VideoThumbnailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload if video ID changed
    if (oldWidget.video.id != widget.video.id) {
      _resolvedAspectRatio = null;
      _loadThumbnail();
    }
  }

  Future<void> _loadThumbnail() async {
    Log.debug(
      '🖼️ VideoThumbnailWidget loading: id=${widget.video.id}, '
      'thumbnailUrl=${widget.video.thumbnailUrl}, '
      'blurhash=${widget.video.blurhash != null ? '${widget.video.blurhash!.length} chars' : 'null'}',
      name: 'VideoThumbnailWidget',
      category: LogCategory.video,
    );

    // Check if we have an existing thumbnail URL
    if (widget.video.thumbnailUrl != null &&
        widget.video.thumbnailUrl!.isNotEmpty) {
      _thumbnailUrl = widget.video.thumbnailUrl;
      _isLoading = false;
      _resolveImageDimensions(_thumbnailUrl!);
      if (mounted) setState(() {});
      return;
    }

    // Check if video is hosted on api.openvine.co - only try API thumbnails for those
    final videoUrl = widget.video.videoUrl;
    final shouldTryApiThumbnail =
        videoUrl != null && videoUrl.contains('api.openvine.co');

    if (!shouldTryApiThumbnail) {
      // Video not hosted on api.openvine.co - don't try to generate thumbnail
      // Just show blurhash or placeholder
      if (mounted) {
        setState(() {
          _thumbnailUrl = null;
          _isLoading = false;
        });
      }
      return;
    }

    // Video is on api.openvine.co - try to get API thumbnail
    // Keep in loading state - show blurhash or loading indicator while generating
    setState(() {
      _isLoading = true;
    });

    try {
      final generatedThumbnailUrl = await widget.video.getApiThumbnailUrl();
      if (generatedThumbnailUrl != null && generatedThumbnailUrl.isNotEmpty) {
        if (mounted) {
          setState(() {
            _thumbnailUrl = generatedThumbnailUrl;
            _isLoading = false;
          });
        }
        return;
      }
    } catch (e) {
      // Silently fail - will use blurhash or placeholder
    }

    // No API thumbnail available - stop loading and show blurhash or placeholder
    if (mounted) {
      setState(() {
        _thumbnailUrl = null;
        _isLoading = false;
      });
    }
  }

  /// Resolves image dimensions from the network image when video dimensions
  /// are not available from metadata.
  void _resolveImageDimensions(String url) {
    // Skip if video already has dimensions
    if (widget.video.width != null && widget.video.height != null) return;

    final imageStream = NetworkImage(url).resolve(ImageConfiguration.empty);
    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (ImageInfo info, bool _) {
        final imageWidth = info.image.width;
        final imageHeight = info.image.height;
        if (mounted && imageHeight > 0) {
          setState(() {
            _resolvedAspectRatio = imageWidth / imageHeight;
          });
        }
        imageStream.removeListener(listener);
      },
      onError: (Object error, StackTrace? stackTrace) {
        imageStream.removeListener(listener);
      },
    );
    imageStream.addListener(listener);
  }

  Widget _buildContent(BoxFit fit) {
    // While loading, show flat placeholder color
    if (_isLoading) {
      return Stack(
        children: [
          Container(
            width: widget.width,
            height: widget.height,
            color: VineTheme.surfaceContainer,
          ),
          if (widget.showPlayIcon)
            Center(
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
        ],
      );
    }

    if (_thumbnailUrl != null) {
      // Show the thumbnail with flat color as placeholder while loading
      return Stack(
        fit: StackFit.expand,
        children: [
          // Show flat color as background while image loads
          Container(
            width: widget.width,
            height: widget.height,
            color: VineTheme.surfaceContainer,
          ),
          // Actual thumbnail image with error boundary
          _SafeNetworkImage(
            url: _thumbnailUrl!,
            width: widget.width,
            height: widget.height,
            fit: fit,
            videoId: widget.video.id,
            showPlayIcon: widget.showPlayIcon,
            borderRadius: widget.borderRadius,
          ),
          // Play icon overlay if requested
          if (widget.showPlayIcon)
            Center(
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
        ],
      );
    }

    // No thumbnail URL - show flat placeholder color with optional play icon
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          width: widget.width,
          height: widget.height,
          color: VineTheme.surfaceContainer,
        ),
        if (widget.showPlayIcon)
          Center(
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Use video metadata dimensions, resolved image dimensions, or fallback
    final double aspectRatio;
    if (widget.video.width != null &&
        widget.video.height != null &&
        widget.video.height! > 0) {
      aspectRatio = widget.video.width! / widget.video.height!;
    } else if (_resolvedAspectRatio != null) {
      aspectRatio = _resolvedAspectRatio!;
    } else {
      // Fallback to 2:3 portrait until image dimensions are resolved
      aspectRatio = 2 / 3;
    }

    // Clamp portrait videos to 2:3 minimum for grid thumbnails
    final double clampedAspectRatio = aspectRatio < 2 / 3 ? 2 / 3 : aspectRatio;

    // Match video player's BoxFit strategy to prevent visual jump:
    // - Portrait videos (aspectRatio < 0.9): Use BoxFit.cover to fill screen
    // - Square/Landscape videos (aspectRatio >= 0.9): Use BoxFit.contain to show full video
    final bool isPortrait = clampedAspectRatio < 0.9;
    final BoxFit effectiveFit = isPortrait ? BoxFit.cover : BoxFit.contain;

    // Build content with the calculated fit
    var content = _buildContent(effectiveFit);

    if (widget.borderRadius != null) {
      content = ClipRRect(borderRadius: widget.borderRadius!, child: content);
    }

    return AspectRatio(aspectRatio: clampedAspectRatio, child: content);
  }
}

/// Error-safe network image widget that prevents HTTP 404 and other network exceptions
/// Uses CachedNetworkImage which handles network errors more gracefully than Image.network
class _SafeNetworkImage extends StatelessWidget {
  const _SafeNetworkImage({
    required this.url,
    required this.videoId,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.showPlayIcon = false,
    this.borderRadius,
  });

  final String url;
  final String videoId;
  final double? width;
  final double? height;
  final BoxFit fit;
  final bool showPlayIcon;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: fit,
      alignment: Alignment.topCenter,
      cacheManager: openVineImageCache,
      // Show transparent container so background surfaceContainer color shows through
      placeholder: (context, url) =>
          Container(width: width, height: height, color: Colors.transparent),
      errorWidget: (context, url, error) {
        // 404s are expected - thumbnail may not exist yet. Handle silently.
        final errorStr = error.toString();
        final is404 =
            errorStr.contains('404') ||
            (errorStr.contains('statusCode') && errorStr.contains('Invalid'));

        if (!is404) {
          // Only log unexpected errors (not 404s)
          Log.warning(
            '🖼️ Thumbnail load failed for video $videoId: ${error.runtimeType}',
            name: 'VideoThumbnailWidget',
            category: LogCategory.video,
          );
        }

        // Show transparent so background surfaceContainer color shows through
        return Container(
          width: width,
          height: height,
          color: Colors.transparent,
        );
      },
    );
  }
}
