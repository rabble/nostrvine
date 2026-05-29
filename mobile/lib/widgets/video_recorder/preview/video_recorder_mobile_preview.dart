import 'package:divine_camera/divine_camera.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/video_recorder/video_recorder_bloc.dart';

/// Camera preview widget for mobile platforms with touch gestures.
class VideoRecorderMobilePreview extends StatelessWidget {
  const VideoRecorderMobilePreview({required this.enableTapToFocus, super.key});

  final bool enableTapToFocus;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<VideoRecorderBloc>();

    return CameraPreviewWidget(
      onScaleStart: (details) => bloc.add(VideoRecorderScaleStarted(details)),
      onScaleUpdate: (details) => bloc.add(VideoRecorderScaleUpdated(details)),
      onTap: enableTapToFocus
          ? (localPosition, normalizedPosition) {
              // setFocusPoint already combines AF + AE metering.
              // No need to call setExposurePoint separately.
              bloc.add(VideoRecorderFocusPointSet(normalizedPosition));
            }
          : null,
      loadingWidget: Container(color: const Color(0xFF141414)),
    );
  }
}
