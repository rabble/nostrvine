// ABOUTME: Bottom bar widget for video recorder screen
// ABOUTME: Contains mode selector wheel and library button

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/video_recorder_provider.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_library_button.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_mode_selector.dart';

/// Bottom bar with record button and camera controls.
class VideoRecorderBottomBar extends ConsumerWidget {
  /// Creates a video recorder bottom bar widget.
  const VideoRecorderBottomBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(videoRecorderProvider.notifier);

    final state = ref.watch(
      videoRecorderProvider.select(
        (p) => (
          isRecording: p.isRecording,
          recorderMode: p.recorderMode,
        ),
      ),
    );

    return SafeArea(
      top: false,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 220),
        opacity: state.isRecording ? 0 : 1,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Stack(
            children: [
              Align(
                child: VideoRecorderModeSelectorWheel(
                  selectedMode: state.recorderMode,
                  onModeChanged: notifier.setRecorderMode,
                ),
              ),
              const Align(
                alignment: .centerLeft,
                child: VideoRecorderLibraryButton(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
