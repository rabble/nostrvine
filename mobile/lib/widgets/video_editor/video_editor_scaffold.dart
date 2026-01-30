import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/clip_manager_provider.dart';

/// A scaffold widget that provides the standard layout for the video editor.
///
/// This widget arranges the video editor UI into three main sections:
/// - A main editor area that displays the video with proper aspect ratio
/// - Overlay controls positioned on top of the video
/// - A bottom bar for additional controls (e.g., timeline, tools)
class VideoEditorScaffold extends ConsumerWidget {
  /// Creates a [VideoEditorScaffold].
  const VideoEditorScaffold({
    super.key,
    required this.overlayControls,
    required this.bottomBar,
    required this.editor,
  });

  /// Controls displayed as an overlay on top of the video editor.
  ///
  /// Typically contains playback controls, trim handles, or other
  /// interactive elements that need to be positioned over the video.
  final Widget overlayControls;

  /// The bottom bar widget displayed below the video editor.
  ///
  /// Usually contains the timeline, tool selection, or other
  /// editing controls.
  final Widget bottomBar;

  /// The main video editor widget that displays the video content.
  ///
  /// This widget is sized to maintain the video's aspect ratio and
  /// is wrapped in a [FittedBox] with [BoxFit.cover].
  final Widget editor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clip = ref.watch(clipManagerProvider.select((s) => s.clips.first));

    return Scaffold(
      backgroundColor: VineTheme.surfaceContainerHigh,
      body: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (_, constraints) {
                return ClipRRect(
                  borderRadius: const .vertical(bottom: .circular(32)),
                  child: Stack(
                    clipBehavior: .none,
                    fit: .expand,
                    children: [
                      FittedBox(
                        fit: .cover,
                        child: SizedBox(
                          width:
                              constraints.maxHeight /
                              clip.targetAspectRatio.value,
                          height: constraints.maxHeight,
                          child: editor,
                        ),
                      ),
                      overlayControls,
                    ],
                  ),
                );
              },
            ),
          ),
          bottomBar,
        ],
      ),
    );
  }
}
