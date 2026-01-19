// ABOUTME: Widget that displays the current upload/publish status as overlay
// ABOUTME: Shows progress indicators and status messages centered on screen

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/video_publish/video_publish_state.dart';
import 'package:openvine/providers/video_publish_provider.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:openvine/widgets/video_publish/status/video_publish_progress_bar.dart';
import 'package:openvine/widgets/video_publish/status/video_publish_status_icon.dart';

/// Displays the current upload/publish status as a full-screen overlay.
class VideoPublishUploadStatus extends ConsumerWidget {
  const VideoPublishUploadStatus({super.key});

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

    return AnimatedOpacity(
      opacity: publishState == .idle ? 0.0 : 1.0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      child: publishState == .idle
          ? const SizedBox.shrink()
          : ColoredBox(
              color: const Color.fromARGB(176, 0, 0, 0),
              child: Center(
                child: Container(
                  margin: const .symmetric(horizontal: 32),
                  padding: const .all(32),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: .topLeft,
                      end: .bottomRight,
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
                    spacing: 20,
                    mainAxisSize: .min,
                    children: [
                      VideoPublishStatusIcon(publishState: publishState),
                      Text(
                        _getStatusMessage(publishState, state.errorMessage),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: .w600,
                          letterSpacing: 0.3,
                        ),
                        textAlign: .center,
                      ),
                      if (publishState == .uploading)
                        const VideoPublishProgressBar()
                      else if (publishState == .error)
                        TextButton(
                          onPressed: () => ref
                              .read(videoPublishProvider.notifier)
                              .clearError(),
                          style: TextButton.styleFrom(
                            padding: const .symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            backgroundColor: VineTheme.vineGreen.withAlpha(38),
                            shape: RoundedRectangleBorder(
                              borderRadius: .circular(12),
                            ),
                          ),
                          child: const Text(
                            // TODO(l10n): Replace with context.l10n when localization is added.
                            'Dismiss',
                            style: TextStyle(
                              color: VineTheme.vineGreen,
                              fontWeight: .w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
