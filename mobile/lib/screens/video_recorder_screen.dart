// ABOUTME: Video recorder screen with modern UI design
// ABOUTME: Features top search bar, camera preview with grid, and bottom controls

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/video_recorder_provider.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/utils/video_controller_cleanup.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_bottom_bar.dart';
import 'package:openvine/widgets/video_recorder/preview/video_recorder_camera_preview.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_countdown_overlay.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_top_bar.dart';

/// Video recorder screen with camera preview and recording controls.
class VideoRecorderScreen extends ConsumerStatefulWidget {
  /// Creates a video recorder screen.
  const VideoRecorderScreen({super.key});

  @override
  ConsumerState<VideoRecorderScreen> createState() =>
      _VideoRecorderScreenState();
}

class _VideoRecorderScreenState extends ConsumerState<VideoRecorderScreen>
    with WidgetsBindingObserver {
  final double _previewRadius = 16;
  VideoRecorderNotifier? _notifier;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeCamera());
    Log.info('📹 Initialized', name: 'VideoRecorderScreen', category: .video);
  }

  /// Initialize camera and handle permission failures
  Future<void> _initializeCamera() async {
    if (!mounted) return;

    _disposeVideoControllers();

    _notifier = ref.read(videoRecorderProvider.notifier);
    await _notifier!.initialize(context: context);
  }

  /// Dispose all video controllers to free resources before recording
  void _disposeVideoControllers() {
    try {
      disposeAllVideoControllers(ref);
      Log.info(
        '🗑️ Disposed all video controllers',
        name: 'VideoRecorderScreen',
        category: .video,
      );
    } catch (e) {
      Log.warning(
        '📹 Failed to dispose video controllers: $e',
        name: 'VideoRecorderScreen',
        category: .video,
      );
    }
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    await ref
        .read(videoRecorderProvider.notifier)
        .handleAppLifecycleState(state);
  }

  @override
  Future<void> dispose() async {
    unawaited(_notifier?.destroy());

    WidgetsBinding.instance.removeObserver(this);

    super.dispose();

    Log.info('📹 Disposed', name: 'VideoRecorderScreen', category: .video);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.black,
        statusBarIconBrightness: .light,
        statusBarBrightness: .dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: .expand,
          children: [
            // Camera preview
            VideoRecorderCameraPreview(previewWidgetRadius: _previewRadius),

            // Top bar with close-button, clip-duration, and confirm-button
            const VideoRecorderTopBar(),

            // Bottom controls
            VideoRecorderBottomBar(previewWidgetRadius: _previewRadius),

            // Countdown overlay
            const VideoRecorderCountdownOverlay(),
          ],
        ),
      ),
    );
  }
}
