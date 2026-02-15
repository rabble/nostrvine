import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'package:pooled_video_player/src/controllers/player_pool.dart';
import 'package:pooled_video_player/src/models/video_item.dart';

/// Builder for the video layer.
typedef SingleVideoBuilder =
    Widget Function(
      BuildContext context,
      VideoController videoController,
      Player player,
    );

/// Builder for the error state.
typedef SingleErrorBuilder =
    Widget Function(
      BuildContext context,
      VoidCallback onRetry,
    );

/// State of the single video player.
enum SingleVideoState {
  /// Loading/buffering.
  loading,

  /// Ready for playback.
  ready,

  /// An error occurred.
  error,
}

/// A single video player that uses the shared [PlayerPool].
///
/// Use this for detail pages where you want to play a single video
/// while still sharing the pool with feeds for memory efficiency.
class SingleVideoPlayer extends StatefulWidget {
  /// Creates a single video player.
  ///
  /// If [pool] is not provided, uses [PlayerPool.instance].
  const SingleVideoPlayer({
    required this.video,
    required this.videoBuilder,
    this.pool,
    this.loadingBuilder,
    this.errorBuilder,
    this.autoPlay = true,
    super.key,
  });

  /// The shared player pool. If null, uses [PlayerPool.instance].
  final PlayerPool? pool;

  /// The video to play.
  final VideoItem video;

  /// Builder for the video layer.
  final SingleVideoBuilder videoBuilder;

  /// Builder for the loading state.
  final WidgetBuilder? loadingBuilder;

  /// Builder for the error state.
  final SingleErrorBuilder? errorBuilder;

  /// Whether to auto-play when ready.
  final bool autoPlay;

  @override
  State<SingleVideoPlayer> createState() => _SingleVideoPlayerState();
}

class _SingleVideoPlayerState extends State<SingleVideoPlayer> {
  late PlayerPool _effectivePool;
  PooledPlayer? _pooledPlayer;
  SingleVideoState _state = SingleVideoState.loading;
  StreamSubscription<bool>? _bufferSubscription;

  @override
  void initState() {
    super.initState();
    _effectivePool = widget.pool ?? PlayerPool.instance;
    unawaited(_loadVideo());
  }

  @override
  void didUpdateWidget(SingleVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.video.url != oldWidget.video.url) {
      unawaited(_loadVideo());
    }
  }

  Future<void> _loadVideo() async {
    setState(() => _state = SingleVideoState.loading);

    try {
      final pooledPlayer = await _effectivePool.getPlayer(widget.video.url);

      if (!mounted) return;

      _pooledPlayer = pooledPlayer;

      // Open media
      await pooledPlayer.player.open(
        Media(widget.video.url),
        play: false,
      );
      await pooledPlayer.player.setPlaylistMode(PlaylistMode.single);

      if (!mounted) return;

      // Set up buffer subscription
      unawaited(_bufferSubscription?.cancel());
      _bufferSubscription = pooledPlayer.player.stream.buffering.listen((
        isBuffering,
      ) {
        if (!isBuffering && _state == SingleVideoState.loading) {
          _onBufferReady();
        }
      });

      // Start buffering (muted initially)
      await pooledPlayer.player.setVolume(0);
      await pooledPlayer.player.play();

      // Check if already buffered
      if (!pooledPlayer.player.state.buffering) {
        _onBufferReady();
      }
    } on Exception {
      if (mounted) {
        setState(() => _state = SingleVideoState.error);
      }
    }
  }

  void _onBufferReady() {
    if (!mounted) return;
    if (_state == SingleVideoState.ready) return;

    final player = _pooledPlayer?.player;
    if (player == null) return;

    unawaited(_bufferSubscription?.cancel());
    _bufferSubscription = null;

    if (widget.autoPlay) {
      unawaited(player.setVolume(100));
    } else {
      unawaited(player.pause());
      unawaited(player.setVolume(100));
    }

    setState(() => _state = SingleVideoState.ready);
  }

  @override
  void reassemble() {
    super.reassemble();
    // During hot reload, stop native playback to prevent
    // "Callback invoked after it has been deleted" crash.
    unawaited(_bufferSubscription?.cancel());
    _bufferSubscription = null;
    _effectivePool.stopAll();
    _state = SingleVideoState.loading;
    _pooledPlayer = null;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_loadVideo());
      }
    });
  }

  @override
  void dispose() {
    unawaited(_bufferSubscription?.cancel());
    // Player stays in pool - LRU will handle cleanup
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    switch (_state) {
      case SingleVideoState.loading:
        return widget.loadingBuilder?.call(context) ??
            const _DefaultLoadingState();

      case SingleVideoState.error:
        return widget.errorBuilder?.call(context, _loadVideo) ??
            _DefaultErrorState(onRetry: _loadVideo);

      case SingleVideoState.ready:
        final pooledPlayer = _pooledPlayer;
        if (pooledPlayer == null) {
          return widget.loadingBuilder?.call(context) ??
              const _DefaultLoadingState();
        }
        return widget.videoBuilder(
          context,
          pooledPlayer.videoController,
          pooledPlayer.player,
        );
    }
  }
}

class _DefaultLoadingState extends StatelessWidget {
  const _DefaultLoadingState();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Colors.black,
      child: Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}

class _DefaultErrorState extends StatelessWidget {
  const _DefaultErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.white70, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Failed to load video',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, color: Colors.white),
              label: const Text(
                'Tap to retry',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
