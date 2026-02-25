// ABOUTME: Overlay widget that displays a countdown timer before recording starts
// ABOUTME: Shows large countdown numbers (3, 2, 1) with fade animation

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/video_recorder_provider.dart';

/// Fullscreen overlay displaying countdown before recording starts.
///
/// Animates in and out based on the countdown value, showing numbers 3, 2, 1.
class VideoRecorderCountdownOverlay extends ConsumerWidget {
  /// Creates a countdown overlay widget.
  const VideoRecorderCountdownOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countdownValue = ref.watch(
      videoRecorderProvider.select((p) => p.countdownValue),
    );

    final isActive = countdownValue > 0;

    return IgnorePointer(
      ignoring: !isActive,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 100),
        opacity: isActive ? 1 : 0,
        child: ColoredBox(
          color: const Color(0xB3000000),
          child: Center(
            child: Text(
              countdownValue.toString(),
              style: const TextStyle(
                color: Color(0xFFFFFFFF),
                fontSize: 114,
                fontFamily: VineTheme.fontFamilyBricolage,
                fontWeight: .w700,
                height: 1.12,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
