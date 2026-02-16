// ABOUTME: Video metadata editing screen for post details, title, description,
// ABOUTME: tags and expiration with updated visual hierarchy

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_bottom_bar.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_clip_preview.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_expiration_selector.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_collaborators_input.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_inspired_by_input.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_tags_input.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_upload_status.dart';

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
        child: Stack(
          children: [
            const Positioned.fill(child: _BackgroundGradient()),
            Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                leading: Hero(
                  tag: VideoEditorConstants.heroBackButtonId,
                  child: IconButton(
                    padding: const .all(8),
                    icon: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0x33000000),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: VineTheme.outlineVariant),
                      ),
                      child: SizedBox(
                        width: 36,
                        height: 36,
                        child: Center(
                          child: SvgPicture.asset(
                            'assets/icon/CaretLeft.svg',
                            colorFilter: const .mode(Colors.white, .srcIn),
                          ),
                        ),
                      ),
                    ),
                    onPressed: () => context.pop(),
                    tooltip: 'Back',
                  ),
                ),
                title: Text(
                  'Post details',
                  style: VineTheme.titleMediumFont(color: VineTheme.onSurface),
                ),
              ),
              body: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                      child: _FormData(
                        titleController: _titleController,
                        descriptionController: _descriptionController,
                        titleFocusNode: _titleFocusNode,
                        descriptionFocusNode: _descriptionFocusNode,
                      ),
                    ),
                  ),
                  // Post button at bottom
                  const SafeArea(top: false, child: VideoMetadataBottomBar()),
                ],
              ),
            ),
            const VideoMetadataUploadStatus(),
          ],
        ),
      ),
    );
  }
}

class _BackgroundGradient extends StatelessWidget {
  const _BackgroundGradient();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF062117),
            VineTheme.surfaceContainerHigh,
            const Color(0xFF000704),
          ],
        ),
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
      crossAxisAlignment: .stretch,
      children: [
        const _FormHeader(),
        const SizedBox(height: 20),
        const _SectionCard(child: VideoMetadataClipPreview()),
        const SizedBox(height: 16),
        _SectionCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
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
                    ref
                        .read(videoEditorProvider.notifier)
                        .updateMetadata(title: value);
                  },
                  onSubmitted: (_) => descriptionFocusNode.requestFocus(),
                ),
                const SizedBox(height: 12),

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
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const _SectionCard(child: VideoMetadataTagsInput()),
        const SizedBox(height: 16),
        const _MetadataLimitWarning(),
        const _SectionCard(child: VideoMetadataExpirationSelector()),
        const SizedBox(height: 12),
        const _SectionCard(child: VideoMetadataCollaboratorsInput()),
        const SizedBox(height: 12),
        const _SectionCard(child: VideoMetadataInspiredByInput()),
      ],
    );
  }
}

class _FormHeader extends StatelessWidget {
  const _FormHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xAA032017),
        border: Border.all(color: VineTheme.outlineVariant),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ready to publish?',
            style: VineTheme.titleSmallFont(color: VineTheme.onSurface),
          ),
          const SizedBox(height: 4),
          Text(
            'Add context and credits so people can discover your post.',
            style: VineTheme.bodyMediumFont(color: VineTheme.onSurfaceMuted),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xC0032017),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: VineTheme.outlineVariant),
      ),
      child: child,
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
      margin: const EdgeInsets.only(bottom: 16),
      padding: const .all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF4A1C00),
        border: Border.all(
          color: const Color(0xFFFFB84D).withValues(alpha: 0.6),
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Color(0xFFFFB84D),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              // TODO(l10n): Replace with context.l10n when localization is
              // added.
              '64KB limit reached. Remove some content to continue.',
              style: VineTheme.bodyFont(
                color: const Color(0xFFFFB84D),
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
