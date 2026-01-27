// ABOUTME: Video metadata editing screen for post details, title, description, tags and expiration
// ABOUTME: Implements Figma design 1:1 with custom widget classes

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_bottom_bar.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_clip_preview.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_expiration_selector.dart';
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
            Scaffold(
              backgroundColor: const Color(0xFF000A06),
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                leading: IconButton(
                  padding: const .all(8),
                  icon: SizedBox(
                    width: 32,
                    height: 32,
                    child: SvgPicture.asset(
                      'assets/icon/CaretLeft.svg',
                      colorFilter: const .mode(Colors.white, .srcIn),
                    ),
                  ),
                  onPressed: () => context.pop(),
                  tooltip: 'Back',
                ),
                title: Text(
                  'Post details',
                  style: GoogleFonts.bricolageGrotesque(
                    color: VineTheme.onSurface,
                    fontSize: 18,
                    fontWeight: .w800,
                    height: 1.33,
                    letterSpacing: 0.15,
                  ),
                ),
              ),
              body: LayoutBuilder(
                builder: (_, constraints) {
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Column(
                        mainAxisAlignment: .spaceBetween,
                        children: [
                          // Metadata form section
                          Column(
                            mainAxisSize: .min,
                            crossAxisAlignment: .stretch,
                            children: [
                              // Video preview at top
                              const VideoMetadataClipPreview(),

                              // Form fields
                              _FormData(
                                titleController: _titleController,
                                descriptionController: _descriptionController,
                                titleFocusNode: _titleFocusNode,
                                descriptionFocusNode: _descriptionFocusNode,
                              ),
                            ],
                          ),
                          // Post button at bottom
                          const SafeArea(
                            top: false,
                            child: VideoMetadataBottomBar(),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const VideoMetadataUploadStatus(),
          ],
        ),
      ),
    );
  }
}

/// A subtle divider line for separating metadata sections.
class _Divider extends StatelessWidget {
  /// Creates a divider widget.
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const Divider(thickness: 0, height: 1, color: Color(0xFF001A12));
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
        // Title input field
        DivineTextField(
          controller: titleController,
          // TODO(l10n): Replace with context.l10n when localization is added.
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
          // TODO(l10n): Replace with context.l10n when localization is added.
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
        const _Divider(),

        // Hashtags input
        const VideoMetadataTagsInput(),
        const _Divider(),

        // 64KB limit warning (shown only if exceeded)
        const _MetadataLimitWarning(),

        // Expiration time selector
        const VideoMetadataExpirationSelector(),
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
      padding: const .all(16),
      color: const Color(0xFF4A1C00),
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
              // TODO(l10n): Replace with context.l10n when localization is added.
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
