// ABOUTME: Video metadata editing screen for post details, title, description,
// ABOUTME: tags and expiration with updated visual hierarchy

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_recorder/video_recorder_mode.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/providers/video_publish_provider.dart';
import 'package:openvine/widgets/video_metadata/modes/capture/video_metadata_capture_stack.dart';
import 'package:openvine/widgets/video_metadata/modes/classic/video_metadata_classic_stack.dart';

/// The user's choice on the "C2PA signing failed" prompt.
enum _C2paMissingChoice { regenerate, postAnyway }

/// Screen for editing video metadata including title, description, tags, and
/// expiration settings.
class VideoMetadataScreen extends ConsumerStatefulWidget {
  /// Creates a video metadata editing screen.
  const VideoMetadataScreen({super.key});

  /// Route name for this screen.
  static const routeName = 'video-metadata';

  /// Path for this route.
  static const path = '/video-metadata';

  @override
  ConsumerState<VideoMetadataScreen> createState() =>
      _VideoMetadataScreenState();
}

class _VideoMetadataScreenState extends ConsumerState<VideoMetadataScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Clear any stale error/completed state from a previous publish attempt
      // so the overlay doesn't block the new publish flow.
      ref.read(videoPublishProvider.notifier).clearError();
    });
  }

  Future<void> _promptC2paMissing() async {
    final l10n = context.l10n;
    final choice = await VineBottomSheetPrompt.show<_C2paMissingChoice>(
      context: context,
      sticker: .alert,
      title: l10n.videoMetadataC2paMissingTitle,
      subtitle: l10n.videoMetadataC2paMissingBody,
      primaryButtonText: l10n.videoMetadataC2paMissingRegenerate,
      onPrimaryPressed: () =>
          Navigator.of(context).pop(_C2paMissingChoice.regenerate),
      secondaryButtonText: l10n.videoMetadataC2paMissingPostAnyway,
      onSecondaryPressed: () =>
          Navigator.of(context).pop(_C2paMissingChoice.postAnyway),
    );
    if (!mounted) return;

    final notifier = ref.read(videoEditorProvider.notifier);
    switch (choice) {
      case _C2paMissingChoice.regenerate:
        // Only the C2PA credential failed — re-sign the existing render
        // instead of re-encoding the whole video (#6058).
        unawaited(notifier.retryC2paSigning());
      case _C2paMissingChoice.postAnyway:
      case null:
        // Dismissed or accepted: proceed without provenance.
        notifier.acknowledgeC2paSigningFailure();
    }
  }

  @override
  Widget build(BuildContext context) {
    // When the render finishes without a C2PA content credential (signing
    // configured but failed), let the user regenerate or knowingly post
    // without provenance (#6058).
    ref.listen(videoEditorProvider.select((s) => s.c2paSigningFailed), (
      previous,
      next,
    ) {
      if (next && previous != true) {
        unawaited(_promptC2paMissing());
      }
    });

    // The recorder bloc is screen-scoped and this screen is a separate route,
    // so read the mode the recorder persisted rather than the (absent) bloc.
    final recorderMode = VideoRecorderMode.fromName(
      ref
          .watch(sharedPreferencesProvider)
          .getString(VideoRecorderMode.persistenceKey),
    );

    // Cancel video render when user navigates back
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        unawaited(ref.read(videoEditorProvider.notifier).cancelRenderVideo());
      },
      // Dismiss keyboard when tapping outside input fields
      child: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: switch (recorderMode) {
          // Lip-sync shares capture's editor + metadata flow.
          .capture || .lipSync => const VideoMetadataCaptureStack(),
          .classic => const VideoMetadataClassicStack(),
          // Deliberately unreachable: upload mode has no record button, so no
          // clips can be created and the user cannot navigate to the metadata
          // screen while in this mode. Required only for switch exhaustiveness.
          .upload => const SizedBox.shrink(),
        },
      ),
    );
  }
}
