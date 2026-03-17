// ABOUTME: Video metadata editing screen for post details, title, description,
// ABOUTME: tags and expiration with updated visual hierarchy

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/providers/video_publish_provider.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_app_bar.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_bottom_bar.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_clip_preview.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_collaborators_input.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_content_warning_selector.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_expiration_selector.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_inspired_by_input.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_tags_input.dart';

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
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  final FocusNode _titleFocusNode = FocusNode();
  final FocusNode _descriptionFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Clear any stale error/completed state from a previous publish attempt
      // so the overlay doesn't block the new publish flow.
      ref.read(videoPublishProvider.notifier).clearError();

      final editorProvider = ref.read(videoEditorProvider);
      _titleController.text = editorProvider.title;
      _descriptionController.text = editorProvider.description;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _titleFocusNode.dispose();
    _descriptionFocusNode.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Cancel video render when user navigates back
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        unawaited(ref.read(videoEditorProvider.notifier).cancelRenderVideo());
      },
      // Dismiss keyboard when tapping outside input fields
      child: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Scaffold(
          backgroundColor: VineTheme.surfaceContainerHigh,
          appBar: const VideoMetadataAppBar(),
          body: Column(
            spacing: 12,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: .min,
                    crossAxisAlignment: .stretch,
                    children: [
                      // Video preview at top
                      const Padding(
                        padding: EdgeInsets.only(top: 8, bottom: 16),
                        child: VideoMetadataClipPreview(),
                      ),

                      // Form fields
                      _FormData(
                        titleController: _titleController,
                        descriptionController: _descriptionController,
                        titleFocusNode: _titleFocusNode,
                        descriptionFocusNode: _descriptionFocusNode,
                      ),
                    ],
                  ),
                ),
              ),
              // Post button at bottom
              const SafeArea(top: false, child: VideoMetadataBottomBar()),
            ],
          ),
        ),
      ),
    );
  }
}

/// A subtle divider line for separating metadata sections.
class _Divider extends StatelessWidget {
  /// Creates a divider widget.
  const _Divider({
    this.enablePaddingTop = false,
    this.enablePaddingBottom = false,
  });

  final bool enablePaddingTop;
  final bool enablePaddingBottom;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: .only(
        top: enablePaddingTop ? 12 : 0.0,
        bottom: enablePaddingBottom ? 12 : 0,
      ),
      child: const Divider(
        thickness: 0,
        height: 1,
        color: VineTheme.outlineDisabled,
      ),
    );
  }
}

/// Form fields for video metadata (title, description, tags, expiration).
class _FormData extends ConsumerWidget {
  /// Creates a form data widget.
  const _FormData({
    required this.titleController,
    required this.descriptionController,
    required this.titleFocusNode,
    required this.descriptionFocusNode,
  });

  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final FocusNode titleFocusNode;
  final FocusNode descriptionFocusNode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisSize: .min,
      crossAxisAlignment: .stretch,
      children: [
        const _MetadataLimitWarning(),

        // Title input field
        DivineTextField(
          controller: titleController,
          // TODO(l10n): Replace with context.l10n when localization is
          // added.
          labelText: 'Title',
          focusNode: titleFocusNode,
          textInputAction: .next,
          minLines: 1,
          maxLines: 5,
          onChanged: (value) {
            ref.read(videoEditorProvider.notifier).updateMetadata(title: value);
          },
          onSubmitted: (_) => descriptionFocusNode.requestFocus(),
        ),
        const _Divider(),

        // Description input field
        DivineTextField(
          controller: descriptionController,
          // TODO(l10n): Replace with context.l10n when localization is
          // added.
          labelText: 'Description',
          focusNode: descriptionFocusNode,
          keyboardType: .multiline,
          textInputAction: .newline,
          minLines: 1,
          maxLines: 10,
          onChanged: (value) {
            ref
                .read(videoEditorProvider.notifier)
                .updateMetadata(description: value);
          },
        ),
        const _Divider(enablePaddingBottom: true),

        // Hashtags input
        const VideoMetadataTagsInput(),
        const _Divider(enablePaddingTop: true),

        // Expiration time selector
        const VideoMetadataExpirationSelector(),
        const _Divider(),

        // Content Warning labels
        const VideoMetadataContentWarningSelector(),
        const _Divider(),

        // Collaborators
        const VideoMetadataCollaboratorsInput(),
        const _Divider(),

        // Inspired By
        const VideoMetadataInspiredByInput(),
        const _Divider(),

        const SizedBox(height: 48),
      ],
    );
  }
}

/// Warning banner displayed when metadata size exceeds the 64KB limit.
class _MetadataLimitWarning extends ConsumerWidget {
  /// Creates a metadata limit warning widget.
  const _MetadataLimitWarning();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final limitReached = ref.watch(
      videoEditorProvider.select((s) => s.metadataLimitReached),
    );
    if (!limitReached) return const SizedBox.shrink();

    return Container(
      margin: const .all(16),
      padding: const .all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF4A1C00),
        border: Border.all(
          color: VineTheme.contentWarningAmber.withValues(alpha: 0.6),
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: VineTheme.contentWarningAmber,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              // TODO(l10n): Replace with context.l10n when localization is
              // added.
              '64KB limit reached. Remove some content to continue.',
              style: VineTheme.bodyFont(
                color: VineTheme.contentWarningAmber,
                fontSize: 14,
                fontWeight: .w600,
                height: 1.43,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
