import 'dart:async';

import 'package:camera_macos_plus/widgets/camera_macos_raw_view.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/video_recorder_provider.dart';

/// Camera preview widget for macOS with gesture and lifecycle handling.
class VideoRecorderMacosPreview extends ConsumerStatefulWidget {
  const VideoRecorderMacosPreview({super.key});

  @override
  ConsumerState<VideoRecorderMacosPreview> createState() =>
      _VideoRecorderMacosPreviewState();
}

class _VideoRecorderMacosPreviewState
    extends ConsumerState<VideoRecorderMacosPreview>
    with WidgetsBindingObserver {
  TapDownDetails? _tapDownDetails;
  final ValueNotifier<bool> _isInBackgroundNotifier = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _isInBackgroundNotifier.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    unawaited(
      ref.read(videoRecorderProvider.notifier).handleAppLifecycleState(state),
    );

    switch (state) {
      case .hidden:
      case .detached:
      case .paused:
      case .inactive:
        _isInBackgroundNotifier.value = true;
      case .resumed:
        _isInBackgroundNotifier.value = false;
    }
  }

  /// Handle tap gesture on preview for focus and exposure.
  ///
  /// Converts tap position to normalized coordinates and sets both
  /// focus and exposure points simultaneously.
  Future<void> _handleTapDown(
    TapDownDetails details,
    BoxConstraints constraints,
  ) async {
    final notifier = ref.read(videoRecorderProvider.notifier);

    final offset = Offset(
      details.localPosition.dx / constraints.maxWidth,
      details.localPosition.dy / constraints.maxHeight,
    );
    await Future.wait([
      notifier.setFocusPoint(offset),
      notifier.setExposurePoint(offset),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(videoRecorderProvider.notifier);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return GestureDetector(
          behavior: .opaque,
          onScaleStart: notifier.handleScaleStart,
          onScaleUpdate: notifier.handleScaleUpdate,
          onTapDown: (details) => _tapDownDetails = details,
          onTap: () {
            if (_tapDownDetails != null) {
              _handleTapDown(_tapDownDetails!, constraints);
            }
          },
          child: ValueListenableBuilder(
            valueListenable: _isInBackgroundNotifier,
            builder: (_, isInBackground, _) {
              if (isInBackground) return const SizedBox.shrink();
              return const CameraMacOSRawView();
            },
          ),
        );
      },
    );
  }
}
