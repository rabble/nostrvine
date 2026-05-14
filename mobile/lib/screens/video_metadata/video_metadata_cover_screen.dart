import 'dart:async';
import 'dart:io';

import 'package:divine_ui/divine_ui.dart';
import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/services/video_thumbnail_service.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/vine_cached_image.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:time_formatter/time_formatter.dart';
import 'package:unified_logger/unified_logger.dart';

// Shared dimensions for the cover-strip thumbnails. These values appear
// in multiple places (slot generation, render layout, output sizing) and
// must stay in sync.
const double _stripHeight = 64;
const double _stripThumbWidth = 48;

/// Full-screen cover selector for a recorded video clip.
///
/// The user scrubs through a thumbnail strip at the bottom to pick the frame
/// that will be used as the post cover image.
class VideoMetadataCoverScreen extends ConsumerStatefulWidget {
  /// Creates a cover selection screen for the given [clip].
  ///
  /// [thumbnailUrl] is shown as a placeholder while the video player
  /// initialises. Pass the existing cover URL in the edit flow.
  const VideoMetadataCoverScreen({
    required this.clip,
    this.thumbnailUrl,
    super.key,
  });

  /// The clip whose cover is being edited.
  final DivineVideoClip clip;

  /// Optional thumbnail URL shown while the player is not yet ready.
  final String? thumbnailUrl;

  @override
  ConsumerState<VideoMetadataCoverScreen> createState() =>
      _VideoMetadataCoverScreenState();
}

class _VideoMetadataCoverScreenState
    extends ConsumerState<VideoMetadataCoverScreen> {
  DivineVideoPlayerController? _controller;

  List<StripThumbnail> _stripThumbnails = const [];
  // Tracks every strip thumbnail path the service has ever emitted, so
  // dispose can clean them up even if a later batch superseded the list
  // currently held in [_stripThumbnails].
  final Set<String> _allStripThumbnailPaths = <String>{};
  StreamSubscription<List<StripThumbnail>>? _stripSubscription;

  Duration _selectedPosition = Duration.zero;

  bool _playerReady = false;

  bool _isConfirming = false;

  bool _isSeeking = false;
  Duration _videoDuration = Duration.zero;
  Duration? _pendingSeekPosition;
  int _seekEpoch = 0;

  @override
  void initState() {
    super.initState();
    _selectedPosition = widget.clip.thumbnailTimestamp;
    unawaited(_initializePlayer());
  }

  Future<void> _initializePlayer() async {
    final localPath = await widget.clip.video.safeFilePath();

    if (!mounted) return;

    final metadata = await ProVideoEditor.instance.getMetadata(
      EditorVideo.file(localPath),
    );
    if (!mounted) return;
    _videoDuration = metadata.duration;
    _startStripGeneration(localPath);

    final controller = DivineVideoPlayerController(useTexture: true);
    await controller.initialize();
    if (!mounted) {
      await controller.dispose();
      return;
    }
    await controller.setSource(VideoClip.file(localPath));
    if (mounted) await controller.seekTo(_selectedPosition);
    if (mounted) {
      setState(() {
        _controller = controller;
        _playerReady = true;
        _seekEpoch++;
        _isSeeking = false;
        _pendingSeekPosition = null;
      });
    }
  }

  Future<void> _startStripGeneration(String videoPath) async {
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final pixelRatio = view.devicePixelRatio;
    final screenWidth = view.physicalSize.width / pixelRatio;

    final slotCount = ((screenWidth - 32) / _stripThumbWidth).ceil().clamp(
      1,
      100,
    );
    final durationMs = _videoDuration.inMilliseconds;

    // One timestamp per slot, evenly distributed across the video duration.
    // These are passed as priorityTimestamps so the first batch already
    // covers every slot — no remapping as later batches arrive.
    final slotTimestamps = List<Duration>.generate(
      slotCount,
      // (i + 0.5) targets the slot's midpoint so the priority frame is
      // visually centered in the thumbnail.
      (i) => Duration(
        milliseconds: ((i + 0.5) * durationMs / slotCount).round().clamp(
          0,
          durationMs,
        ),
      ),
    );

    // thumbsPerSecond drives how many density thumbnails the service adds
    // on top of the priority set. Setting it to slotCount / durationSec
    // (minimum 1) keeps the total as close to slotCount as possible,
    // avoiding large numbers of thumbnails that will never be displayed.
    final durationSec = _videoDuration.inSeconds.clamp(1, 99999);
    final thumbsPerSecond = (slotCount / durationSec).ceil().clamp(1, 20);

    _stripSubscription =
        VideoThumbnailService.generateStripThumbnails(
          videoPath: videoPath,
          clipId: widget.clip.id,
          duration: _videoDuration,
          outputSize: Size(
            _stripThumbWidth * pixelRatio,
            _stripHeight * pixelRatio,
          ),
          thumbsPerSecond: thumbsPerSecond,
          priorityTimestamps: slotTimestamps,
          batchSize: 10,
        ).listen((thumbnails) {
          for (final t in thumbnails) {
            _allStripThumbnailPaths.add(t.path);
          }
          if (mounted) {
            setState(() => _stripThumbnails = thumbnails);
          }
        });
  }

  Future<void> _seekTo(Duration position) async {
    if (!_playerReady) return;
    _selectedPosition = position;
    if (mounted) setState(() {});

    if (_isSeeking) {
      _pendingSeekPosition = position;
      return;
    }

    _isSeeking = true;
    final epoch = _seekEpoch;
    try {
      await _controller?.seekTo(position);
      if (_seekEpoch != epoch) {
        _pendingSeekPosition = null;
        return;
      }

      while (_pendingSeekPosition != null && mounted) {
        final pending = _pendingSeekPosition!;
        _pendingSeekPosition = null;
        await _controller?.seekTo(pending);
        if (_seekEpoch != epoch) {
          _pendingSeekPosition = null;
          break;
        }
      }
    } finally {
      if (_seekEpoch == epoch) {
        _isSeeking = false;
      }
    }
  }

  Future<void> _confirm() async {
    if (_isConfirming) return;
    setState(() => _isConfirming = true);

    var didSucceed = false;
    try {
      final videoPath = await widget.clip.video.safeFilePath();
      if (videoPath.isNotEmpty) {
        final result = await VideoThumbnailService.extractThumbnail(
          videoPath: videoPath,
          targetTimestamp: _selectedPosition,
        );
        if (result != null && mounted) {
          if (widget.clip.video.networkUrl != null) {
            // Published video — return the local path to the caller.
            // The Blossom upload and republish happen when the user presses Update.
            Navigator.of(context).pop(result.path);
            return;
          } else {
            // Draft video — update via videoEditorProvider.
            ref
                .read(videoEditorProvider.notifier)
                .updateCover(
                  thumbnailPath: result.path,
                  thumbnailTimestamp: _selectedPosition,
                );
            didSucceed = true;
          }
        }
      }
    } catch (e, stackTrace) {
      Log.error(
        'Failed to extract cover thumbnail',
        name: 'VideoMetadataCoverScreen',
        error: e,
        stackTrace: stackTrace,
      );
    }

    if (!mounted) return;
    if (didSucceed) {
      SemanticsService.sendAnnouncement(
        View.of(context),
        context.l10n.videoMetadataEditCoverSuccessAnnouncement,
        Directionality.of(context),
      );
      context.pop();
      return;
    }

    // Stay on screen so the user can retry. Surface the failure.
    final message = context.l10n.videoMetadataEditCoverFailedSnackbar;
    SemanticsService.sendAnnouncement(
      View.of(context),
      message,
      Directionality.of(context),
    );
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(DivineSnackbarContainer.snackBar(message));
    setState(() => _isConfirming = false);
  }

  @override
  void dispose() {
    unawaited(_disposeStripResources());
    unawaited(_controller?.dispose());
    super.dispose();
  }

  /// Cancels the strip generation stream and deletes every thumbnail file
  /// the service ever produced for this screen instance. Awaiting the
  /// cancel before deleting ensures any in-flight batch has been flushed
  /// into [_allStripThumbnailPaths] first.
  Future<void> _disposeStripResources() async {
    final subscription = _stripSubscription;
    _stripSubscription = null;
    if (subscription != null) {
      await subscription.cancel();
    }
    for (final path in _allStripThumbnailPaths) {
      File(path).delete().ignore();
    }
    _allStripThumbnailPaths.clear();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: VideoEditorConstants.uiOverlayStyle,
      child: SafeArea(
        child: Scaffold(
          backgroundColor: VineTheme.backgroundCamera,
          body: Stack(
            fit: .expand,
            children: [
              Column(
                crossAxisAlignment: .stretch,
                spacing: 8,
                children: [
                  Expanded(
                    child: Stack(
                      fit: .expand,
                      children: [
                        RepaintBoundary(
                          child: _VideoArea(
                            clip: widget.clip,
                            thumbnailUrl: widget.thumbnailUrl,
                            controller: _playerReady ? _controller : null,
                          ),
                        ),

                        if (_controller == null || !_controller!.isInitialized)
                          const Center(child: BrandedLoadingIndicator()),
                      ],
                    ),
                  ),
                  _BottomArea(
                    clip: widget.clip,
                    thumbnail: (
                      file: widget.clip.thumbnailPath != null
                          ? File(widget.clip.thumbnailPath!)
                          : null,
                      networkUrl: widget.thumbnailUrl,
                    ),
                    stripThumbnails: _stripThumbnails,
                    clipDuration: _videoDuration,
                    selectedPosition: _selectedPosition,
                    onSeek: _seekTo,
                  ),
                ],
              ),
              _TopBar(
                isConfirming: _isConfirming,
                onClose: () => context.pop(),
                onConfirm: _confirm,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VideoArea extends StatefulWidget {
  const _VideoArea({
    required this.clip,
    required this.controller,
    this.thumbnailUrl,
  });

  final DivineVideoClip clip;
  final DivineVideoPlayerController? controller;
  final String? thumbnailUrl;

  @override
  State<_VideoArea> createState() => _VideoAreaState();
}

class _VideoAreaState extends State<_VideoArea> {
  StreamSubscription<DivineVideoPlayerState>? _sub;
  double _videoAR = 0;

  @override
  void initState() {
    super.initState();
    _subscribeToController(widget.controller);
  }

  @override
  void didUpdateWidget(_VideoArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _sub?.cancel();
      _subscribeToController(widget.controller);
    }
  }

  void _subscribeToController(DivineVideoPlayerController? controller) {
    _videoAR = controller?.state.aspectRatio ?? 0;
    _sub = controller?.stateStream.listen((state) {
      final ar = state.aspectRatio;
      if (ar > 0 && ar != _videoAR) {
        setState(() => _videoAR = ar);
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Widget _buildPlaceholder() {
    final networkUrl = widget.thumbnailUrl;
    if (networkUrl != null) {
      return VineCachedImage(imageUrl: networkUrl);
    }
    final localPath = widget.clip.thumbnailPath;
    if (localPath != null) {
      return Image.file(File(localPath), fit: BoxFit.cover);
    }
    return const ColoredBox(color: VineTheme.onSurfaceMuted);
  }

  @override
  Widget build(BuildContext context) {
    final videoAR = _videoAR > 0
        ? _videoAR
        : widget.clip.targetAspectRatio.value;
    final isSquare = widget.clip.targetAspectRatio.value == 1.0;
    final player = ClipRRect(
      borderRadius: isSquare
          ? .circular(12)
          : const .vertical(bottom: .circular(32)),
      child: FittedBox(
        fit: isSquare ? BoxFit.contain : BoxFit.cover,
        child: SizedBox(
          width: 1000 * videoAR,
          height: 1000,
          child: DivineVideoPlayer(
            controller: widget.controller,
            placeholder: _buildPlaceholder(),
          ),
        ),
      ),
    );
    return Hero(
      tag: VideoEditorConstants.heroMetaPreviewId,
      createRectTween: (begin, end) => RectTween(begin: begin, end: end),
      child: AspectRatio(
        aspectRatio: widget.clip.targetAspectRatio.value,
        child: isSquare ? Center(child: player) : player,
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.isConfirming,
    required this.onClose,
    required this.onConfirm,
  });

  final bool isConfirming;
  final VoidCallback onClose;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: .topCenter,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const .all(16),
          child: Row(
            spacing: 16,
            children: [
              Semantics(
                label: context.l10n.videoMetadataEditCoverCloseSemanticLabel,
                button: true,
                child: DivineIconButton(
                  icon: .x,
                  type: .ghostSecondary,
                  size: .small,
                  onPressed: onClose,
                ),
              ),
              Expanded(
                child: Text(
                  context.l10n.videoMetadataEditCoverTitle,
                  style: VineTheme.titleMediumFont(),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Semantics(
                label: context.l10n.videoMetadataEditCoverConfirmSemanticLabel,
                button: true,
                child: isConfirming
                    ? const SizedBox(
                        width: 40,
                        height: 40,
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: VineTheme.primary,
                            ),
                          ),
                        ),
                      )
                    : DivineIconButton(
                        icon: .check,
                        size: .small,
                        onPressed: onConfirm,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomArea extends StatelessWidget {
  const _BottomArea({
    required this.clip,
    required this.thumbnail,
    required this.stripThumbnails,
    required this.clipDuration,
    required this.selectedPosition,
    required this.onSeek,
  });

  final DivineVideoClip clip;
  final ({File? file, String? networkUrl})? thumbnail;
  final List<StripThumbnail> stripThumbnails;
  final Duration clipDuration;
  final Duration selectedPosition;
  final ValueChanged<Duration> onSeek;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const .fromLTRB(16, 0, 16, 12),
      child: ClipRRect(
        borderRadius: .circular(4),
        child: _ThumbnailStrip(
          clip: clip,
          thumbnail: thumbnail,
          stripThumbnails: stripThumbnails,
          clipDuration: clipDuration,
          selectedPosition: selectedPosition,
          onSeek: onSeek,
        ),
      ),
    );
  }
}

class _ThumbnailStrip extends StatefulWidget {
  const _ThumbnailStrip({
    required this.clip,
    required this.thumbnail,
    required this.stripThumbnails,
    required this.clipDuration,
    required this.selectedPosition,
    required this.onSeek,
  });

  final DivineVideoClip clip;
  final ({File? file, String? networkUrl})? thumbnail;
  final List<StripThumbnail> stripThumbnails;
  final Duration clipDuration;
  final Duration selectedPosition;
  final ValueChanged<Duration> onSeek;

  @override
  State<_ThumbnailStrip> createState() => _ThumbnailStripState();
}

class _ThumbnailStripState extends State<_ThumbnailStrip> {
  static const double _cursorWidth = 36;
  static const Duration _semanticSeekStep = Duration(milliseconds: 500);

  List<StripThumbnail>? _cachedThumbnails;
  int? _cachedCount;
  List<String?> _cachedPaths = const [];

  void _updateSlotCache(int count) {
    if (widget.stripThumbnails == _cachedThumbnails && count == _cachedCount) {
      return;
    }
    _cachedThumbnails = widget.stripThumbnails;
    _cachedCount = count;
    _cachedPaths = List<String?>.generate(
      count,
      (i) => _thumbnailForSlot(i, count),
    );
  }

  Duration _positionFromDx(double dx, double stripWidth) {
    final fraction = (dx / stripWidth).clamp(0.0, 1.0);
    final ms = (fraction * widget.clipDuration.inMilliseconds).round();
    return Duration(milliseconds: ms);
  }

  double _dxFromPosition(Duration position, double stripWidth) {
    if (widget.clipDuration <= Duration.zero) return 0;
    final fraction =
        position.inMilliseconds / widget.clipDuration.inMilliseconds;
    return (fraction * stripWidth).clamp(0.0, stripWidth);
  }

  Duration _clampPosition(Duration position) {
    final maxMs = widget.clipDuration.inMilliseconds;
    return Duration(
      milliseconds: position.inMilliseconds.clamp(0, maxMs),
    );
  }

  void _seekBySemanticsDelta(Duration delta) {
    final target = _clampPosition(widget.selectedPosition + delta);
    widget.onSeek(target);
  }

  /// Maps a visual slot index to the best [StripThumbnail] path for that
  /// time window (mirrors the logic in the timeline strip tiles).
  String? _thumbnailForSlot(int slotIndex, int slotCount) {
    if (widget.stripThumbnails.isEmpty) return null;
    final durationMs = widget.clipDuration.inMilliseconds;
    if (durationMs <= 0) return widget.stripThumbnails.first.path;

    final slotStartMs = durationMs * slotIndex / slotCount;
    final slotEndMs = durationMs * (slotIndex + 1) / slotCount;
    final slotCenterMs = (slotStartMs + slotEndMs) / 2;

    var lo = 0;
    var hi = widget.stripThumbnails.length;
    while (lo < hi) {
      final mid = (lo + hi) ~/ 2;
      if (widget.stripThumbnails[mid].timestamp.inMilliseconds < slotStartMs) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }

    String? bestPath;
    var bestDist = double.infinity;
    for (var i = lo; i < widget.stripThumbnails.length; i++) {
      final tsMs = widget.stripThumbnails[i].timestamp.inMilliseconds;
      if (tsMs >= slotEndMs) break;
      final dist = (tsMs - slotCenterMs).abs();
      if (dist < bestDist) {
        bestDist = dist;
        bestPath = widget.stripThumbnails[i].path;
      }
    }
    return bestPath;
  }

  @override
  Widget build(BuildContext context) {
    final increasedPosition = _clampPosition(
      widget.selectedPosition + _semanticSeekStep,
    );
    final decreasedPosition = _clampPosition(
      widget.selectedPosition - _semanticSeekStep,
    );

    return Semantics(
      label: context.l10n.videoMetadataEditCoverStripSemanticLabel,
      slider: true,
      value: TimeFormatter.formatMinutesSeconds(widget.selectedPosition),
      increasedValue: TimeFormatter.formatMinutesSeconds(increasedPosition),
      decreasedValue: TimeFormatter.formatMinutesSeconds(decreasedPosition),
      onIncrease: () => _seekBySemanticsDelta(_semanticSeekStep),
      onDecrease: () => _seekBySemanticsDelta(-_semanticSeekStep),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stripWidth = constraints.maxWidth;
          final count = (stripWidth / _stripThumbWidth).ceil().clamp(1, 500);
          _updateSlotCache(count);
          final slotWidth = stripWidth / count;
          final cursorDx = _dxFromPosition(
            widget.selectedPosition,
            stripWidth,
          );

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => widget.onSeek(
              _positionFromDx(d.localPosition.dx, stripWidth),
            ),
            onHorizontalDragUpdate: (d) => widget.onSeek(
              _positionFromDx(d.localPosition.dx, stripWidth),
            ),
            child: SizedBox(
              width: stripWidth,
              height: _stripHeight,
              child: Stack(
                fit: .expand,
                children: [
                  SizedBox(
                    width: stripWidth,
                    child: Row(
                      children: [
                        for (var i = 0; i < count; i++)
                          SizedBox(
                            width: slotWidth,
                            height: _stripHeight,
                            child: _SlotImage(
                              thumbnail: widget.thumbnail,
                              stripThumbnailPath: _cachedPaths[i],
                            ),
                          ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 0,
                    bottom: 0,
                    left: (cursorDx - _cursorWidth / 2).clamp(
                      0,
                      stripWidth - _cursorWidth,
                    ),
                    child: IgnorePointer(
                      child: Container(
                        width: _cursorWidth,
                        decoration: ShapeDecoration(
                          shape: RoundedRectangleBorder(
                            side: const BorderSide(
                              width: 2,
                              color: VineTheme.onSurface,
                            ),
                            borderRadius: .circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SlotImage extends StatelessWidget {
  const _SlotImage({required this.thumbnail, this.stripThumbnailPath});

  final ({File? file, String? networkUrl})? thumbnail;
  final String? stripThumbnailPath;

  @override
  Widget build(BuildContext context) {
    final fallback = thumbnail?.networkUrl != null
        ? ExcludeSemantics(
            child: VineCachedImage(
              imageUrl: thumbnail!.networkUrl!,
              placeholder: (_, _) => const ColoredBox(
                color: VineTheme.surfaceContainerHigh,
              ),
              errorWidget: (_, _, _) => const ColoredBox(
                color: VineTheme.surfaceContainerHigh,
              ),
            ),
          )
        : thumbnail?.file != null
        ? Image.file(
            thumbnail!.file!,
            fit: .cover,
            excludeFromSemantics: true,
          )
        : const ColoredBox(
            color: VineTheme.surfaceContainerHigh,
          );

    if (stripThumbnailPath == null) return fallback;

    return Image.file(
      File(stripThumbnailPath!),
      fit: BoxFit.cover,
      gaplessPlayback: true,
      excludeFromSemantics: true,
      errorBuilder: (_, _, _) => fallback,
    );
  }
}
