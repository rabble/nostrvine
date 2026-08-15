import 'package:flutter/widgets.dart';
import 'package:media_cache/media_cache.dart';
import 'package:openvine/utils/dead_image_hosts.dart';
import 'package:openvine/utils/open_vine_image_cache.dart';

export 'package:openvine/utils/open_vine_image_cache.dart'
    show clearOpenVineImageCache, openVineImageCache;

/// Signature used to build a loading placeholder.
typedef PlaceholderWidgetBuilder =
    Widget Function(BuildContext context, String imageUrl);

/// Signature used to build an error widget.
typedef LoadingErrorWidgetBuilder =
    Widget Function(BuildContext context, String imageUrl, Object error);

typedef ImageDimensionsResolved = void Function(int width, int height);

/// Test-only override for the cache used by every [VineCachedImage].
///
/// When non-null, images resolve through this manager instead of
/// [openVineImageCache], letting widget tests inject a stubbed
/// `MockMediaCacheManager` so the eager image resolve avoids the real
/// on-disk cache. The real cache performs async `path_provider` work that
/// can settle *after* a test completes, polluting the shared VGV merge
/// isolate; the override keeps that work out of tests. Reset to `null` in
/// `tearDown`.
@visibleForTesting
MediaCacheManager? debugImageCacheOverride;

/// The cache [VineCachedImage] resolves through — the test override if set,
/// otherwise the global [openVineImageCache].
MediaCacheManager get _activeImageCache =>
    debugImageCacheOverride ?? openVineImageCache;

/// A wrapper around [Image] that always uses [openVineImageCache].
class VineCachedImage extends StatefulWidget {
  const VineCachedImage({
    required this.imageUrl,
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.placeholder,
    this.errorWidget,
    this.memCacheWidth,
    this.memCacheHeight,
    this.fadeInDuration = const Duration(milliseconds: 500),
    this.fadeOutDuration = const Duration(milliseconds: 1000),
    this.onImageDimensionsResolved,
  });

  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Alignment alignment;
  final PlaceholderWidgetBuilder? placeholder;
  final LoadingErrorWidgetBuilder? errorWidget;
  final int? memCacheWidth;
  final int? memCacheHeight;
  final Duration fadeInDuration;
  final Duration fadeOutDuration;
  final ImageDimensionsResolved? onImageDimensionsResolved;

  @override
  State<VineCachedImage> createState() => _VineCachedImageState();
}

class _VineCachedImageState extends State<VineCachedImage> {
  ImageStream? _imageStream;
  ImageStreamListener? _listener;
  Object? _error;
  bool _hasImage = false;

  ImageProvider<Object> get _imageProvider => ResizeImage.resizeIfNeeded(
    widget.memCacheWidth,
    widget.memCacheHeight,
    MediaCacheImageProvider(widget.imageUrl, cacheManager: _activeImageCache),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveImageStream();
  }

  @override
  void didUpdateWidget(covariant VineCachedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl ||
        oldWidget.memCacheWidth != widget.memCacheWidth ||
        oldWidget.memCacheHeight != widget.memCacheHeight) {
      _resolveImageStream();
    }
  }

  @override
  void dispose() {
    _removeImageListener();
    super.dispose();
  }

  void _resolveImageStream() {
    if (isKnownDeadImageHost(widget.imageUrl)) {
      _removeImageListener();
      _error = null;
      _hasImage = false;
      return;
    }

    final newStream = _imageProvider.resolve(
      createLocalImageConfiguration(context),
    );
    if (_imageStream?.key == newStream.key) {
      return;
    }

    _removeImageListener();
    _imageStream = newStream;
    _error = null;
    _hasImage = false;

    _listener = ImageStreamListener(
      (image, synchronousCall) {
        final imageWidth = image.image.width;
        final imageHeight = image.image.height;
        final onImageDimensionsResolved = widget.onImageDimensionsResolved;
        image.dispose();
        if (!mounted) return;
        if (onImageDimensionsResolved != null) {
          if (synchronousCall) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                onImageDimensionsResolved(imageWidth, imageHeight);
              }
            });
          } else {
            onImageDimensionsResolved(imageWidth, imageHeight);
          }
        }
        if (_hasImage) return;
        setState(() {
          _hasImage = true;
          _error = null;
        });
      },
      onError: (Object error, StackTrace? stackTrace) {
        if (!mounted) return;
        setState(() {
          _error = error;
          _hasImage = false;
        });
      },
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
  Widget build(BuildContext context) {
    // A known-dead host must never be resolved: the origin is gone, so the
    // request would only burn a failure before landing here anyway.
    if (isKnownDeadImageHost(widget.imageUrl)) {
      return _ErrorWidget(
        error: StateError('known-dead image host: ${widget.imageUrl}'),
        imageUrl: widget.imageUrl,
        width: widget.width,
        height: widget.height,
        errorWidget: widget.errorWidget,
      );
    }

    if (_error != null) {
      return _ErrorWidget(
        error: _error!,
        imageUrl: widget.imageUrl,
        width: widget.width,
        height: widget.height,
        errorWidget: widget.errorWidget,
      );
    }

    final image = Image(
      image: _imageProvider,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      alignment: widget.alignment,
      errorBuilder: (context, error, stackTrace) => _ErrorWidget(
        error: error,
        imageUrl: widget.imageUrl,
        width: widget.width,
        height: widget.height,
        errorWidget: widget.errorWidget,
      ),
    );

    if (widget.placeholder == null) {
      return AnimatedOpacity(
        key: const ValueKey('image'),
        opacity: _hasImage ? 1 : 0,
        duration: widget.fadeInDuration,
        child: image,
      );
    }

    return Stack(
      fit: StackFit.passthrough,
      children: [
        IgnorePointer(
          child: AnimatedOpacity(
            opacity: _hasImage ? 0 : 1,
            duration: widget.fadeOutDuration,
            child: _Placeholder(
              imageUrl: widget.imageUrl,
              width: widget.width,
              height: widget.height,
              placeholder: widget.placeholder,
            ),
          ),
        ),
        AnimatedOpacity(
          key: const ValueKey('image'),
          opacity: _hasImage ? 1 : 0,
          duration: widget.fadeInDuration,
          child: image,
        ),
      ],
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({
    required this.imageUrl,
    required this.width,
    required this.height,
    required this.placeholder,
  });

  final String imageUrl;
  final double? width;
  final double? height;
  final PlaceholderWidgetBuilder? placeholder;

  @override
  Widget build(BuildContext context) {
    if (placeholder == null) {
      return SizedBox(width: width, height: height);
    }
    return KeyedSubtree(
      key: const ValueKey('placeholder'),
      child: placeholder!(context, imageUrl),
    );
  }
}

class _ErrorWidget extends StatelessWidget {
  const _ErrorWidget({
    required this.error,
    required this.imageUrl,
    required this.width,
    required this.height,
    required this.errorWidget,
  });

  final Object error;
  final String imageUrl;
  final double? width;
  final double? height;
  final LoadingErrorWidgetBuilder? errorWidget;

  @override
  Widget build(BuildContext context) {
    if (errorWidget == null) {
      return SizedBox(width: width, height: height);
    }
    return KeyedSubtree(
      key: const ValueKey('error'),
      child: errorWidget!(context, imageUrl, error),
    );
  }
}
