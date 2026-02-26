// ABOUTME: Closed captions toggle button for video feed overlay.
// ABOUTME: Shows CC icon when video has subtitles, toggles visibility state.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:openvine/providers/subtitle_providers.dart';

/// CC action button that toggles subtitle overlay visibility.
///
/// Only renders when [video] has subtitle data available.
/// Tapping toggles the [subtitleVisibilityProvider] for this video.
class CcActionButton extends ConsumerWidget {
  const CcActionButton({required this.video, super.key});

  final VideoEvent video;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!video.hasSubtitles) return const SizedBox.shrink();

    final isActive = ref.watch(subtitleVisibilityProvider);

    return Semantics(
      identifier: 'cc_button',
      container: true,
      explicitChildNodes: true,
      button: true,
      label: isActive ? 'Hide subtitles' : 'Show subtitles',
      child: IconButton(
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints.tightFor(width: 48, height: 48),
        style: IconButton.styleFrom(
          highlightColor: Colors.transparent,
          splashFactory: NoSplash.splashFactory,
        ),
        onPressed: () {
          ref.read(subtitleVisibilityProvider.notifier).toggle();
        },
        icon: Icon(
          Icons.closed_caption,
          size: 32,
          color: isActive ? VineTheme.vineGreen : Colors.white,
          shadows: const [Shadow(blurRadius: 15)],
        ),
      ),
    );
  }
}
