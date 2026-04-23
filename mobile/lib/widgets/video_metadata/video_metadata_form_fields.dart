import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_collaborators_input.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_content_warning_selector.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_expiration_selector.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_inspired_by_input.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_limit_warning_banner.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_tags_input.dart';

class VideoMetadataFormFields extends ConsumerStatefulWidget {
  const VideoMetadataFormFields({
    super.key,
    this.enableTags = true,
    this.enableExpiration = true,
    this.enableContentWarning = true,
    this.enableCollaborators = true,
    this.enableInspiredBy = true,
  });

  final bool enableTags;
  final bool enableExpiration;
  final bool enableContentWarning;
  final bool enableCollaborators;
  final bool enableInspiredBy;

  @override
  ConsumerState<VideoMetadataFormFields> createState() =>
      _VideoMetadataFormFieldsState();
}

class _VideoMetadataFormFieldsState
    extends ConsumerState<VideoMetadataFormFields> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _titleFocusNode = FocusNode();
  final _descriptionFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final editorState = ref.read(videoEditorProvider);
      _titleController.text = editorState.title;
      _descriptionController.text = editorState.description;
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
    return Column(
      mainAxisSize: .min,
      crossAxisAlignment: .stretch,
      children: [
        const VideoMetadataLimitWarningBanner(),

        // Title input field
        DivineTextField(
          controller: _titleController,
          labelText: context.l10n.videoMetadataTitleLabel,
          focusNode: _titleFocusNode,
          textInputAction: .next,
          minLines: 1,
          maxLines: 5,
          onChanged: (value) {
            ref.read(videoEditorProvider.notifier).updateMetadata(title: value);
          },
          onSubmitted: (_) => _descriptionFocusNode.requestFocus(),
        ),
        const _Divider(),

        // Description input field
        DivineTextField(
          controller: _descriptionController,
          labelText: context.l10n.videoMetadataDescriptionLabel,
          focusNode: _descriptionFocusNode,
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

        if (widget.enableTags) ...[
          const _Divider(enablePaddingBottom: true),
          const VideoMetadataTagsInput(),
        ],

        if (widget.enableExpiration) ...[
          _Divider(enablePaddingTop: widget.enableTags),
          const VideoMetadataExpirationSelector(),
        ],

        if (widget.enableContentWarning) ...[
          const _Divider(),
          const VideoMetadataContentWarningSelector(),
        ],

        if (widget.enableCollaborators) ...[
          const _Divider(),
          const VideoMetadataCollaboratorsInput(),
        ],

        if (widget.enableInspiredBy) ...[
          const _Divider(),
          const VideoMetadataInspiredByInput(),
        ],

        const _Divider(),
        const SizedBox(height: 48),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
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
