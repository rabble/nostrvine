// ABOUTME: Bottom sheet shown when a background video upload fails.
// ABOUTME: Displays error reason with retry and save-to-drafts actions.

import 'dart:io';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/background_publish/background_publish_bloc.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/screens/library_screen.dart';
import 'package:openvine/screens/video_metadata/video_metadata_preview_screen.dart';
import 'package:openvine/services/video_publish/video_publish_service.dart';

/// Shows a bottom sheet when a background upload fails.
///
/// Offers the user two options:
/// - **Try Again** retries the upload via [BackgroundPublishRetryRequested].
/// - **Save to Drafts** removes the upload from the active queue while the
///   draft remains in the library for later publishing.
///
/// Dismissing the sheet without choosing an action has the same effect as
/// saving to drafts.
Future<void> showUploadFailureSheet(
  BuildContext context,
  BackgroundUpload upload,
) async {
  final result = await VineBottomSheet.show<String>(
    context: context,
    scrollable: false,
    isDismissible: false,
    enableDrag: false,
    children: [
      _UploadFailureSheetContent(
        upload: upload,
        onRetry: () => Navigator.of(context).pop('retry'),
        onSaveToDrafts: () => Navigator.of(context).pop('save_drafts'),
      ),
    ],
  );

  if (!context.mounted) return;

  final messenger = ScaffoldMessenger.maybeOf(context);

  switch (result) {
    case 'retry':
      context.read<BackgroundPublishBloc>().add(
        BackgroundPublishRetryRequested(draftId: upload.draft.id),
      );
      // TODO(l10n): Replace with context.l10n when localization is added.
      messenger?.showSnackBar(
        DivineSnackbarContainer.snackBar('Retrying upload…'),
      );
    case 'save_drafts':
      // Explicit save: remove from queue, draft stays in library
      context.read<BackgroundPublishBloc>().add(
        BackgroundPublishVanished(draftId: upload.draft.id),
      );
      // TODO(l10n): Replace with context.l10n when localization is added.
      messenger?.showSnackBar(
        DivineSnackbarContainer.snackBar(
          'Saved to drafts',
          actionLabel: 'View',
          onActionPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            context.push(LibraryScreen.draftsPath);
          },
        ),
      );
    case _:
      // Sheet was popped externally (e.g. during route transition).
      // Save to drafts silently so the user's content is preserved.
      context.read<BackgroundPublishBloc>().add(
        BackgroundPublishVanished(draftId: upload.draft.id),
      );
  }
}

class _UploadFailureSheetContent extends StatelessWidget {
  const _UploadFailureSheetContent({
    required this.upload,
    required this.onRetry,
    required this.onSaveToDrafts,
  });

  final BackgroundUpload upload;
  final VoidCallback onRetry;
  final VoidCallback onSaveToDrafts;

  @override
  Widget build(BuildContext context) {
    final errorMessage = switch (upload.result) {
      PublishError(:final userMessage) => userMessage,
      _ => null,
    };

    final draft = upload.draft;
    final clip = draft.clips.isNotEmpty ? draft.clips.first : null;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 8),
            _DraftPreview(clip: clip),

            const SizedBox(height: 16),
            Text(
              // TODO(l10n): Replace with context.l10n when localization is added.
              'Upload Failed',
              style: VineTheme.headlineSmallFont(),
              textAlign: TextAlign.center,
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                errorMessage,
                style: VineTheme.bodyLargeFont(
                  color: VineTheme.onSurfaceVariant,
                ),
                textAlign: .center,
              ),
            ],

            const SizedBox(height: 32),
            DivineButton(
              expanded: true,
              label: 'Try Again',
              onPressed: onRetry,
            ),

            const SizedBox(height: 12),
            DivineButton(
              expanded: true,
              type: .secondary,
              label: 'Save to Drafts',
              onPressed: onSaveToDrafts,
            ),
          ],
        ),
      ),
    );
  }
}

class _DraftPreview extends StatefulWidget {
  const _DraftPreview({this.clip});

  final DivineVideoClip? clip;

  @override
  State<_DraftPreview> createState() => _DraftPreviewState();
}

class _DraftPreviewState extends State<_DraftPreview> {
  late final bool _hasThumb;

  @override
  void initState() {
    super.initState();
    final path = widget.clip?.thumbnailPath;
    _hasThumb = path != null && File(path).existsSync();
  }

  void _openPreview() {
    final clip = widget.clip;
    if (clip == null) return;

    Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) =>
            VideoMetadataPreviewScreen(clip: clip, previewOnly: true),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const previewHeight = 160.0;
    final aspectRatio = widget.clip?.targetAspectRatio.value ?? 9 / 16;
    final previewWidth = previewHeight * aspectRatio;

    return GestureDetector(
      onTap: _hasThumb ? _openPreview : null,
      child: ClipRRect(
        borderRadius: .circular(12),
        child: SizedBox(
          height: previewHeight,
          width: previewWidth,
          child: _hasThumb
              ? Image.file(File(widget.clip!.thumbnailPath!), fit: BoxFit.cover)
              : SvgPicture.asset(
                  'assets/stickers/alert.svg',
                  height: 132,
                  width: 132,
                ),
        ),
      ),
    );
  }
}
