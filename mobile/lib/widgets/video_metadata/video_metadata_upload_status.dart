// ABOUTME: Widget that displays the current upload/publish status as overlay
// ABOUTME: Shows progress indicators and status messages centered on screen

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/video_publish/video_publish_state.dart';
import 'package:openvine/providers/video_publish_provider.dart';

/// Displays the current upload/publish status as a full-screen overlay.
///
/// Shows different states including:
/// - Initializing/preparing indicators
/// - Upload progress bar with percentage
/// - Publishing to Nostr status
/// - Success checkmark
/// - Error state with dismiss button
class VideoMetadataUploadStatus extends ConsumerWidget {
  /// Creates a video metadata upload status overlay.
  const VideoMetadataUploadStatus({super.key});

  /// Returns a user-friendly status message for the given [publishState].
  ///
  /// Uses [errorMessage] when in error state if available.
  String _getStatusMessage(
    VideoPublishState publishState,
    String? errorMessage,
  ) {
    /// TODO(l10n): Replace with context.l10n when localization is added.
    switch (publishState) {
      case .idle:
        return '';
      case .initialize:
        return 'Initializing...';
      case .preparing:
        return 'Preparing video...';
      case .uploading:
        return 'Uploading...';
      case .retryUpload:
        return 'Retrying upload...';
      case .publishToNostr:
        return 'Publishing to Nostr...';
      case .completed:
        return 'Published!';
      case .error:
        return errorMessage ?? 'Upload failed';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(
      videoPublishProvider.select(
        (s) => (
          publishState: s.publishState,
          errorMessage: s.errorMessage,
          uploadProgress: s.uploadProgress,
        ),
      ),
    );
    final publishState = state.publishState;

    return Material(
      type: .transparency,
      child: AnimatedOpacity(
        opacity: publishState == .idle ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        child: publishState == .idle
            ? const SizedBox.shrink()
            : ColoredBox(
                color: const Color.fromARGB(176, 0, 0, 0),
                child: Center(
                  child: _StatusDialog(
                    publishState: publishState,
                    statusMessage: _getStatusMessage(
                      publishState,
                      state.errorMessage,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

/// Progress bar showing video upload progress with percentage.
///
/// Displays a linear progress indicator and percentage text.
class _VideoPublishProgressBar extends ConsumerWidget {
  /// Creates a video publish progress bar.
  const _VideoPublishProgressBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(
      videoPublishProvider.select((s) => s.uploadProgress),
    );
    final percentage = (progress * 100).toStringAsFixed(0);

    return Column(
      spacing: 8,
      children: [
        ClipRRect(
          borderRadius: .circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: const Color(0xFF424242),
            valueColor: const AlwaysStoppedAnimation<Color>(
              VineTheme.vineGreen,
            ),
            minHeight: 6,
          ),
        ),
        Text(
          '$percentage%',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
      ],
    );
  }
}

/// Dialog card showing the current publish status.
///
/// Contains icon, message, and optional action (progress bar or dismiss button).
class _StatusDialog extends ConsumerWidget {
  /// Creates a status dialog.
  const _StatusDialog({
    required this.publishState,
    required this.statusMessage,
  });

  /// The current publish state.
  final VideoPublishState publishState;

  /// The status message to display.
  final String statusMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const .symmetric(horizontal: 32),
      padding: const .all(32),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: .topLeft,
          end: .bottomRight,
          colors: [Color(0xFF2A2A2A), Color(0xFF1A1A1A)],
        ),
        borderRadius: .circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.4),
            blurRadius: 30,
            spreadRadius: 5,
            offset: Offset(0, 10),
          ),
        ],
        border: .all(color: const Color(0x1A000000)),
      ),
      child: Column(
        spacing: 20,
        mainAxisSize: .min,
        children: [
          _VideoPublishStatusIcon(publishState: publishState),
          Text(
            statusMessage,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: .w600,
              letterSpacing: 0.3,
            ),
            textAlign: .center,
          ),
          if (publishState == .uploading)
            const _VideoPublishProgressBar()
          else if (publishState == .error)
            const _DismissButton(),
        ],
      ),
    );
  }
}

/// Button to dismiss an error state.
class _DismissButton extends ConsumerWidget {
  /// Creates a dismiss button.
  const _DismissButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TextButton(
      onPressed: () => ref.read(videoPublishProvider.notifier).clearError(),
      style: TextButton.styleFrom(
        padding: const .symmetric(horizontal: 24, vertical: 12),
        backgroundColor: VineTheme.vineGreen.withAlpha(38),
        shape: RoundedRectangleBorder(borderRadius: .circular(12)),
      ),
      // TODO(l10n): Replace with context.l10n when localization is added.
      child: const Text(
        'Dismiss',
        style: TextStyle(color: VineTheme.vineGreen, fontWeight: .w600),
      ),
    );
  }
}

/// Displays an icon representing the current video publish state.
class _VideoPublishStatusIcon extends StatelessWidget {
  const _VideoPublishStatusIcon({required this.publishState});

  /// The current publish state to display an icon for.
  final VideoPublishState publishState;

  @override
  Widget build(BuildContext context) {
    switch (publishState) {
      case .error:
        return const Icon(Icons.error_outline, color: Colors.red, size: 48);
      case .completed:
        return const Icon(
          Icons.check_circle,
          color: VineTheme.vineGreen,
          size: 48,
        );
      case .publishToNostr:
      case .uploading:
      case .retryUpload:
        return const SizedBox(
          width: 48,
          height: 48,
          child: CircularProgressIndicator(
            strokeWidth: 4,
            valueColor: AlwaysStoppedAnimation<Color>(VineTheme.vineGreen),
          ),
        );

      case .idle:
      case .initialize:
      case .preparing:
        return const SizedBox(
          width: 48,
          height: 48,
          child: CircularProgressIndicator(
            strokeWidth: 4,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        );
    }
  }
}
