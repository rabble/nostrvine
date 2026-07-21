// ABOUTME: Smart video thumbnail widget that displays thumbnails or blurhash placeholders
// ABOUTME: Uses existing thumbnail URLs from video events and falls back to blurhash when missing

import 'dart:async';

import 'package:blurhash_service/blurhash_service.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart'
    show HttpExceptionWithStatus;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart' hide AspectRatio, LogCategory;
import 'package:openvine/models/viewer_auth_result.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/utils/blossom_blob_hash.dart';
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

  static VineContentType? _deriveContentType(VideoEvent video) =>
      BlurhashService.deriveContentType(
        hashtags: video.hashtags,
        group: video.group,
        title: video.title,
        content: video.content,
      );

  @override
  void didUpdateWidget(VideoThumbnailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.video.id != widget.video.id ||
        oldWidget.video.thumbnailUrl != widget.video.thumbnailUrl ||
        oldWidget.video.blurhash != widget.video.blurhash ||
        oldWidget.video.dimensions != widget.video.dimensions) {
      _resolvedAspectRatio = null;
      _loadThumbnail();
    }
  }

  void _loadThumbnail() {
    final url = widget.video.thumbnailUrl;
    if (url != null && url.isNotEmpty) {
      _thumbnailUrl = url;
    } else {
      _thumbnailUrl = null;
    }
    if (mounted) setState(() {});
  }

  void _handleImageDimensionsResolved(String url, int width, int height) {
    if (url != _thumbnailUrl ||
        !mounted ||
        _hasUsableVideoDimensions ||
        width <= 0 ||
        height <= 0) {
      return;
    }

    final aspectRatio = width / height;
    if (_resolvedAspectRatio == aspectRatio) return;
    setState(() {
      _resolvedAspectRatio = aspectRatio;
    });
  }

  bool get _hasUsableVideoDimensions {
    final width = widget.video.width;
    final height = widget.video.height;
    return width != null && width > 0 && height != null && height > 0;
  }

  Widget _buildContent(BoxFit fit) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Show blurhash or flat color as background while image loads
        BlurhashDisplay(
          blurhash: widget.video.blurhash,
          contentType: _deriveContentType(widget.video),
          width: widget.width,
          height: widget.height,
          fit: fit,
        ),

        // Actual thumbnail image with error boundary, rendered on top of
        // the blurhash placeholder once it loads.
        if (_thumbnailUrl != null)
          _SafeNetworkImage(
            url: _thumbnailUrl!,
            width: widget.width,
            height: widget.height,
            fit: fit,
            videoId: widget.video.id,
            showPlayIcon: widget.showPlayIcon,
            borderRadius: widget.borderRadius,
            onImageDimensionsResolved: _handleImageDimensionsResolved,
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
              child: const DivineIcon(
                icon: DivineIconName.play,
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
    if (_hasUsableVideoDimensions) {
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

/// Error-safe network image widget that prevents HTTP 404 and other network exceptions.
/// Uses [VineCachedImage] for shared cache-backed loading where appropriate.
class _SafeNetworkImage extends StatefulWidget {
  const _SafeNetworkImage({
    required this.url,
    required this.videoId,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.showPlayIcon = false,
    this.borderRadius,
    this.onImageDimensionsResolved,
  });

  final String url;
  final String videoId;
  final double? width;
  final double? height;
  final BoxFit fit;
  final bool showPlayIcon;
  final BorderRadius? borderRadius;
  final void Function(String url, int width, int height)?
  onImageDimensionsResolved;

  // Toggle to test with plain Image.network instead of VineCachedImage.
  // Set to true to debug cache-manager behavior.
  static const bool _useSimpleImageNetwork = false;

  static bool _shouldBypassCacheManager(String url) {
    final host = Uri.tryParse(url)?.host.toLowerCase();
    if (host == null || host.isEmpty) return false;

    // Explore/grid thumbnails are predominantly served from Divine-owned,
    // immutable blob URLs. These load reliably with Image.network, while the
    // The shared cache-manager path has been less reliable
    // under concurrent grid loads on desktop.
    return host == 'divine.video' || host.endsWith('.divine.video');
  }

  @override
  State<_SafeNetworkImage> createState() => _SafeNetworkImageState();
}

class _SafeNetworkImageState extends State<_SafeNetworkImage> {
  Map<String, String>? _authHeaders;
  bool _authRetryAttempted = false;

  @override
  void didUpdateWidget(covariant _SafeNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _authHeaders = null;
      _authRetryAttempted = false;
    }
  }

  Future<void> _maybeRetryWithPassiveAuth(Object error) async {
    if (_authRetryAttempted || !_isAuthChallenge(error)) return;
    _authRetryAttempted = true;

    final sha256Hash = extractSha256FromBlossomUrl(widget.url);
    if (sha256Hash == null) return;

    final authResult = await ProviderScope.containerOf(context, listen: false)
        .read(mediaAuthInterceptorProvider)
        .createPassiveAuthHeadersForAdultMedia(
          sha256Hash: sha256Hash,
          serverUrl: _extractServerUrl(widget.url),
        );
    if (!mounted) return;

    switch (authResult) {
      case ViewerAuthAuthorized(:final headers):
        setState(() {
          _authHeaders = headers;
        });
      case ViewerAuthSignerUnreachable():
      case ViewerAuthBlockedByPreference():
      case ViewerAuthUnavailable():
        break;
    }
  }

  bool _isAuthChallenge(Object error) {
    if (error is NetworkImageLoadException) {
      return error.statusCode == 401 || error.statusCode == 403;
    }
    if (error is HttpExceptionWithStatus) {
      return error.statusCode == 401 || error.statusCode == 403;
    }
    final message = error.toString();
    return message.contains(' 401 ') ||
        message.contains(' 403 ') ||
        message.contains('statusCode: 401') ||
        message.contains('statusCode: 403');
  }

  String? _extractServerUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final portSuffix = uri.hasPort ? ':${uri.port}' : '';
      return '${uri.scheme}://${uri.host}$portSuffix';
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Decode thumbnails at their on-screen size rather than full source
        // resolution. Full-resolution decodes exhaust Flutter's in-memory image
        // cache within a few screens of fast scrolling, evicting already-loaded
        // thumbnails so they visibly reload on the way back. Capping the decode
        // width keeps far more thumbnails resident in the cache.
        final cacheWidth = _decodeWidth(context, constraints.maxWidth);
        final resolvedUrl = widget.url;

        // Debug mode: test with plain Image.network to isolate cache issues
        if (_SafeNetworkImage._useSimpleImageNetwork ||
            _SafeNetworkImage._shouldBypassCacheManager(resolvedUrl)) {
          final imageProvider = ResizeImage.resizeIfNeeded(
            cacheWidth,
            null,
            NetworkImage(resolvedUrl, headers: _authHeaders),
          );
          return ImageWithDimensionsListener(
            imageProvider: imageProvider,
            onImageDimensionsResolved: widget.onImageDimensionsResolved == null
                ? null
                : (width, height) => widget.onImageDimensionsResolved!(
                    resolvedUrl,
                    width,
                    height,
                  ),
            child: Image(
              image: imageProvider,
              width: widget.width,
              height: widget.height,
              fit: widget.fit,
              alignment: Alignment.topCenter,
              errorBuilder: (context, error, stackTrace) {
                unawaited(_maybeRetryWithPassiveAuth(error));
                Log.warning(
                  '🖼️ [Image.network] Thumbnail load failed for video ${widget.videoId}:\n'
                  '  URL: ${widget.url}\n'
                  '  Error type: ${error.runtimeType}\n'
                  '  Error: $error\n'
                  '  Stack: ${stackTrace?.toString().split('\n').take(5).join('\n')}',
                  name: 'VideoThumbnailWidget',
                  category: LogCategory.video,
                );
                return Container(
                  width: widget.width,
                  height: widget.height,
                  color: VineTheme.transparent,
                );
              },
            ),
          );
        }

        return VineCachedImage(
          imageUrl: resolvedUrl,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          memCacheWidth: cacheWidth,
          authHeaders: _authHeaders,
          alignment: Alignment.topCenter,
          onImageDimensionsResolved: widget.onImageDimensionsResolved == null
              ? null
              : (width, height) => widget.onImageDimensionsResolved!(
                  resolvedUrl,
                  width,
                  height,
                ),
          // Show transparent container so background surfaceContainer color shows through
          placeholder: (context, url) => Container(
            width: widget.width,
            height: widget.height,
            color: VineTheme.transparent,
          ),
          errorWidget: (context, url, error) {
            unawaited(_maybeRetryWithPassiveAuth(error));
            // 404s are expected — thumbnail may not exist yet.
            final is404 = error is HttpExceptionWithStatus
                ? error.statusCode == 404
                : error.toString().contains('404');

            if (!is404) {
              Log.warning(
                '🖼️ Thumbnail load failed for video ${widget.videoId}:\n'
                '  URL: $url\n'
                '  Error type: ${error.runtimeType}\n'
                '  Error: $error',
                name: 'VideoThumbnailWidget',
                category: LogCategory.video,
              );
            }

            // Show transparent so background surfaceContainer color shows through
            return Container(
              width: widget.width,
              height: widget.height,
              color: VineTheme.transparent,
            );
          },
        );
      },
    );
  }

  /// Physical-pixel decode width for the thumbnail, derived from its laid-out
  /// [maxWidth] (or the explicit [width] when the layout is unbounded).
  ///
  /// Returns `null` when no finite width is available, leaving the framework to
  /// decode at native resolution.
  int? _decodeWidth(BuildContext context, double maxWidth) {
    final logicalWidth = maxWidth.isFinite && maxWidth > 0
        ? maxWidth
        : widget.width;
    if (logicalWidth == null || logicalWidth <= 0) return null;
    return (logicalWidth * MediaQuery.devicePixelRatioOf(context)).ceil();
  }
}

/// Resolves [imageProvider] alongside the rendered [child] purely to report the
/// decoded image's intrinsic dimensions via [onImageDimensionsResolved].
///
/// Used by the Image.network thumbnail path (which has no built-in dimension
/// callback like [VineCachedImage]) so the aspect ratio can be recovered from
/// the displayed image instead of a separate probe decode.
@visibleForTesting
class ImageWithDimensionsListener extends StatefulWidget {
  const ImageWithDimensionsListener({
    required this.imageProvider,
    required this.child,
    super.key,
    this.onImageDimensionsResolved,
  });

  final ImageProvider<Object> imageProvider;
  final ImageDimensionsResolved? onImageDimensionsResolved;
  final Widget child;

  @override
  State<ImageWithDimensionsListener> createState() =>
      _ImageWithDimensionsListenerState();
}

class _ImageWithDimensionsListenerState
    extends State<ImageWithDimensionsListener> {
  ImageStream? _imageStream;
  ImageStreamListener? _listener;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveImageStream();
  }

  @override
  void didUpdateWidget(covariant ImageWithDimensionsListener oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageProvider != widget.imageProvider) {
      _resolveImageStream();
    }
  }

  @override
  void dispose() {
    _removeImageListener();
    super.dispose();
  }

  void _resolveImageStream() {
    final newStream = widget.imageProvider.resolve(
      createLocalImageConfiguration(context),
    );
    if (_imageStream?.key == newStream.key) {
      return;
    }

    _removeImageListener();
    _imageStream = newStream;

    _listener = ImageStreamListener(
      (image, synchronousCall) {
        final imageWidth = image.image.width;
        final imageHeight = image.image.height;
        final onImageDimensionsResolved = widget.onImageDimensionsResolved;
        image.dispose();
        if (!mounted) return;
        if (onImageDimensionsResolved == null) return;
        if (synchronousCall) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              onImageDimensionsResolved(imageWidth, imageHeight);
            }
          });
        } else {
          onImageDimensionsResolved(imageWidth, imageHeight);
        }
      },
      // The rendered Image handles visible failures; this listener only needs
      // dimensions when decoding succeeds.
      onError: (Object error, StackTrace? stackTrace) {},
    );
    _imageStream!.addListener(_listener!);
  }

  void _removeImageListener() {
    if (_imageStream != null && _listener != null) {
      _imageStream!.removeListener(_listener!);
    }
    _imageStream = null;
    _listener = null;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
