// ABOUTME: Smart video thumbnail widget that displays thumbnails or blurhash placeholders
// ABOUTME: Uses existing thumbnail URLs from video events and falls back to blurhash when missing

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart'
    show HttpExceptionWithStatus;
import 'package:models/models.dart' hide AspectRatio, LogCategory;
import 'package:openvine/widgets/blurhash_display.dart';
import 'package:openvine/widgets/vine_cached_image.dart';
import 'package:unified_logger/unified_logger.dart';

/// Smart thumbnail widget that displays thumbnails with blurhash fallback
class VideoThumbnailWidget extends StatefulWidget {
  const VideoThumbnailWidget({
    required this.video,
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.showPlayIcon = false,
    this.borderRadius,
  });
  final VideoEvent video;
  final double? width;
  final double? height;
  final BoxFit fit;
  final bool showPlayIcon;
  final BorderRadius? borderRadius;

  @override
  State<VideoThumbnailWidget> createState() => _VideoThumbnailWidgetState();
}

class _VideoThumbnailWidgetState extends State<VideoThumbnailWidget> {
  String? _thumbnailUrl;
  double? _resolvedAspectRatio;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  @override
  void didUpdateWidget(VideoThumbnailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.video.id != widget.video.id) {
      _resolvedAspectRatio = null;
      _loadThumbnail();
    }
  }

  void _loadThumbnail() {
    final url = widget.video.thumbnailUrl;
    if (url != null && url.isNotEmpty) {
      _thumbnailUrl = url;
      _resolveImageDimensions(url);
    } else {
      _thumbnailUrl = null;
    }
    if (mounted) setState(() {});
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
    if (_thumbnailUrl != null) {
      // Show the thumbnail with flat color as placeholder while loading
      return Stack(
        fit: StackFit.expand,
        children: [
          // Show blurhash or flat color as background while image loads
          if (widget.video.blurhash != null)
            BlurhashDisplay(
              blurhash: widget.video.blurhash!,
              width: widget.width,
              height: widget.height,
              fit: fit,
            )
          else
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
                  color: VineTheme.backgroundColor.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: VineTheme.whiteText,
                  size: 32,
                ),
              ),
            ),
        ],
      );
    }

    // No thumbnail URL - show blurhash or flat placeholder color with
    // optional play icon
    return Stack(
      fit: StackFit.expand,
      children: [
        if (widget.video.blurhash != null)
          BlurhashDisplay(
            blurhash: widget.video.blurhash!,
            width: widget.width,
            height: widget.height,
            fit: fit,
          )
        else
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
                color: VineTheme.backgroundColor.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow,
                color: VineTheme.whiteText,
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

  // Toggle to test with plain Image.network instead of CachedNetworkImage
  // Set to true to debug if the issue is with flutter_cache_manager
  static const bool _useSimpleImageNetwork = false;

  static bool _shouldBypassCacheManager(String url) {
    final host = Uri.tryParse(url)?.host.toLowerCase();
    if (host == null || host.isEmpty) return false;

    // Explore/grid thumbnails are predominantly served from Divine-owned,
    // immutable blob URLs. These load reliably with Image.network, while the
    // CachedNetworkImage + custom cache manager path has been less reliable
    // under concurrent grid loads on desktop.
    return host == 'divine.video' || host.endsWith('.divine.video');
  }

  @override
  Widget build(BuildContext context) {
    // Debug mode: test with plain Image.network to isolate cache issues
    if (_useSimpleImageNetwork || _shouldBypassCacheManager(url)) {
      return Image.network(
        url,
        width: width,
        height: height,
        fit: fit,
        alignment: Alignment.topCenter,
        errorBuilder: (context, error, stackTrace) {
          Log.warning(
            '🖼️ [Image.network] Thumbnail load failed for video $videoId:\n'
            '  URL: $url\n'
            '  Error type: ${error.runtimeType}\n'
            '  Error: $error\n'
            '  Stack: ${stackTrace?.toString().split('\n').take(5).join('\n')}',
            name: 'VideoThumbnailWidget',
            category: LogCategory.video,
          );
          return Container(
            width: width,
            height: height,
            color: VineTheme.transparent,
          );
        },
      );
    }

    return VineCachedImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: fit,
      alignment: Alignment.topCenter,
      // Show transparent container so background surfaceContainer color shows through
      placeholder: (context, url) =>
          Container(width: width, height: height, color: VineTheme.transparent),
      errorWidget: (context, url, error) {
        // 404s are expected — thumbnail may not exist yet.
        final is404 = error is HttpExceptionWithStatus
            ? error.statusCode == 404
            : error.toString().contains('404');

        if (!is404) {
          Log.warning(
            '🖼️ Thumbnail load failed for video $videoId:\n'
            '  URL: $url\n'
            '  Error type: ${error.runtimeType}\n'
            '  Error: $error',
            name: 'VideoThumbnailWidget',
            category: LogCategory.video,
          );
        }

        // Show transparent so background surfaceContainer color shows through
        return Container(
          width: width,
          height: height,
          color: VineTheme.transparent,
        );
      },
    );
  }
}
