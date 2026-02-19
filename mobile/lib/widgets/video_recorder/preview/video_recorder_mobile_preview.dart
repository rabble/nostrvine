import 'package:divine_camera/divine_camera.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/video_recorder_provider.dart';

/// Camera preview widget for mobile platforms with touch gestures.
class VideoRecorderMobilePreview extends ConsumerWidget {
  const VideoRecorderMobilePreview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(videoRecorderProvider.notifier);

    return CameraPreviewWidget(
      onScaleStart: notifier.handleScaleStart,
      onScaleUpdate: notifier.handleScaleUpdate,
      onTap: (localPosition, normalizedPosition) async {
        // setFocusPoint already combines AF + AE metering.
        // No need to call setExposurePoint separately.
        await notifier.setFocusPoint(normalizedPosition);
      },
      loadingWidget: Container(color: const Color(0xFF141414)),
    );
  }
}
