// ABOUTME: Full-screen overlay showing video render progress and error states
// ABOUTME: Displays spinner during rendering and error message with retry on failure

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:pro_video_editor/core/models/video/progress_model.dart';
import 'package:pro_video_editor/core/platform/platform_interface.dart';

/// Full-screen overlay showing video render progress and error states.
///
/// Displays:
/// - Processing indicator with progress bar during rendering
/// - Error message with dismiss button on failure
class VideoClipEditorRenderStatus extends ConsumerWidget {
  /// Creates a video clip editor render status overlay.
  const VideoClipEditorRenderStatus({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(
      videoEditorProvider.select(
        (s) => (
          isProcessing: s.isProcessing,
          renderErrorMessage: s.renderErrorMessage,
        ),
      ),
    );

    final isVisible = state.isProcessing || state.renderErrorMessage != null;

    return Material(
      type: MaterialType.transparency,
      child: AnimatedOpacity(
        opacity: isVisible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        child: isVisible
            ? ColoredBox(
                color: const Color.fromARGB(200, 0, 0, 0),
                child: Center(
                  child: state.renderErrorMessage != null
                      ? _ErrorDialog(errorMessage: state.renderErrorMessage!)
                      : const _RenderingDialog(),
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

/// Dialog showing rendering progress.
class _RenderingDialog extends ConsumerWidget {
  const _RenderingDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get first clip ID to track render progress
    final clipId = ref.watch(
      clipManagerProvider.select((s) => s.clips.firstOrNull?.id),
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A2A2A), Color(0xFF1A1A1A)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.4),
            blurRadius: 30,
            spreadRadius: 5,
            offset: Offset(0, 10),
          ),
        ],
        border: Border.all(color: const Color(0x1A000000)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 20,
        children: [
          // Progress indicator
          if (clipId != null)
            RepaintBoundary(
              child: StreamBuilder<ProgressModel>(
                stream: ProVideoEditor.instance.progressStreamById(clipId),
                builder: (context, snapshot) {
                  final progress = snapshot.data?.progress ?? 0;
                  return SizedBox(
                    width: 64,
                    height: 64,
                    child: PartialCircleSpinner(progress: progress),
                  );
                },
              ),
            )
          else
            const SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                strokeWidth: 4,
                valueColor: AlwaysStoppedAnimation<Color>(VineTheme.vineGreen),
              ),
            ),
          // Status text
          const Text(
            // TODO(l10n): Replace with context.l10n when localization is added.
            'Rendering video...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Dialog showing render error with dismiss button.
class _ErrorDialog extends ConsumerWidget {
  const _ErrorDialog({required this.errorMessage});

  final String errorMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A2A2A), Color(0xFF1A1A1A)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.4),
            blurRadius: 30,
            spreadRadius: 5,
            offset: Offset(0, 10),
          ),
        ],
        border: Border.all(color: const Color(0x1A000000)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 20,
        children: [
          // Error icon
          const Icon(Icons.error_outline, color: Colors.red, size: 48),
          // Error message
          Text(
            errorMessage,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
            textAlign: TextAlign.center,
          ),
          // Dismiss button
          TextButton(
            onPressed: () =>
                ref.read(videoEditorProvider.notifier).clearRenderError(),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              backgroundColor: VineTheme.vineGreen.withAlpha(38),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            // TODO(l10n): Replace with context.l10n when localization is added.
            child: const Text(
              'Dismiss',
              style: TextStyle(
                color: VineTheme.vineGreen,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
