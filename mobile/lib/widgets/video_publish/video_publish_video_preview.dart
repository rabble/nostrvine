// ABOUTME: Video preview widget for video publish screen
// ABOUTME: Displays the video being published with video player

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/platform_io.dart';
import 'package:openvine/providers/video_publish_provider.dart';
import 'package:video_player/video_player.dart';

/// Video preview widget displaying the video to be published.
class VideoPublishVideoPreview extends ConsumerStatefulWidget {
  /// Creates a video publish video widget.
  const VideoPublishVideoPreview({super.key});

  @override
  ConsumerState<VideoPublishVideoPreview> createState() =>
      _VideoPublishVideoState();
}

class _VideoPublishVideoState extends ConsumerState<VideoPublishVideoPreview> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    // Initialize after first frame to ensure provider is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_initializeVideoPlayer());
    });

    // Listen to play/pause state changes
    ref
      ..listenManual(videoPublishProvider.select((state) => state.isPlaying), (
        previous,
        next,
      ) async {
        if (_controller != null && _isInitialized) {
          if (next && !_controller!.value.isPlaying) {
            await _controller!.play();
          } else if (!next && _controller!.value.isPlaying) {
            await _controller!.pause();
          }
        }
      })
      // Listen to mute state changes
      ..listenManual(videoPublishProvider.select((state) => state.isMuted), (
        previous,
        next,
      ) async {
        if (_controller != null && _isInitialized) {
          await _controller!.setVolume(next ? 0.0 : 1.0);
        }
      });
  }

  Future<void> _initializeVideoPlayer() async {
    final editedVideo = ref.read(videoPublishProvider).clip?.video;
    final videoPath = await editedVideo?.safeFilePath();

    if (videoPath == null) {
      debugPrint('⚠️ No edited video path available');
      return;
    }

    _controller = VideoPlayerController.file(File(videoPath));
    await _controller?.initialize();
    if (!mounted) return;

    // Set duration in provider
    ref
        .read(videoPublishProvider.notifier)
        .setDuration(_controller!.value.duration);

    // Add listener for position updates
    _controller?.addListener(_onVideoPositionChange);

    await _controller?.setLooping(true);
    if (!mounted) return;
    await _controller?.play();

    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  void _onVideoPositionChange() {
    if (_controller != null && mounted) {
      ref
          .read(videoPublishProvider.notifier)
          .updatePosition(_controller!.value.position);
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_onVideoPositionChange);
    unawaited(_controller?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final aspectRatio = ref.watch(
      videoPublishProvider.select((s) => s.clip?.aspectRatio),
    );

    return SafeArea(
      child: ClipRRect(
        clipBehavior: .hardEdge,
        borderRadius: .circular(16),
        child: AspectRatio(
          aspectRatio: aspectRatio?.value ?? 1,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: _isInitialized && _controller != null
                ? FittedBox(
                    child: SizedBox(
                      width: _controller!.value.size.width,
                      height: _controller!.value.size.height,
                      child: VideoPlayer(_controller!),
                    ),
                  )
                : ColoredBox(
                    color: Colors.grey.shade800,
                    child: const Center(
                      child: CircularProgressIndicator(color: Colors.white54),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
