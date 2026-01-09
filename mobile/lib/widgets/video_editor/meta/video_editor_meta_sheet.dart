// ABOUTME: Bottom sheet widget for editing video metadata.
// ABOUTME: Provides input fields for title, description, and topics.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/models/video_editor/video_editor_meta.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/utils/video_editor_utils.dart';
import 'package:openvine/widgets/divine_icon_button.dart';
import 'package:openvine/widgets/video_editor/meta/video_editor_meta_input.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Bottom sheet widget for editing video metadata.
///
/// Displays form fields for video title, description, and topics with
/// Material 3 styling and rounded top corners.
class VideoEditorMetaSheet extends ConsumerStatefulWidget {
  /// Creates a video metadata editing sheet.
  const VideoEditorMetaSheet({super.key, this.draftId});

  final String? draftId;

  @override
  ConsumerState<VideoEditorMetaSheet> createState() =>
      _VideoEditorMetaSheetState();
}

class _VideoEditorMetaSheetState extends ConsumerState<VideoEditorMetaSheet> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _topicsController = TextEditingController();
  final List<String> _topics = [];

  /// TODO(@hm21): The current design didn't inclucde "AudioReuse" and expiring
  /// posts => Not required anymore??

  /// Per-video audio sharing override (null = not loaded)
  bool? _allowAudioReuse;
  Duration? _expireTime;

  @override
  void initState() {
    super.initState();
    _loadDraft();

    _titleController.addListener(_handleMetaChanges);
    _descriptionController.addListener(_handleMetaChanges);

    Log.info(
      '📝 VideoEditorMetaSheet: Initialized',
      category: LogCategory.video,
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _topicsController.dispose();

    super.dispose();

    Log.info('📝 VideoEditorMetaSheet: Disposed', category: LogCategory.video);
  }

  Future<void> _loadDraft() async {
    try {
      if (widget.draftId == null) return;

      final prefs = await SharedPreferences.getInstance();
      final draftService = DraftStorageService(prefs);
      final draft = await draftService.getDraftById(widget.draftId!);
      if (draft == null) {
        if (context.mounted) {
          context.pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Draft not found'),
              backgroundColor: Colors.red,
            ),
          );
        }
        throw StateError('Draft ${widget.draftId} not found');
      }

      // Load the global audio sharing preference as default
      final audioSharingService = ref.read(
        audioSharingPreferenceServiceProvider,
      );
      final defaultAudioSharing = audioSharingService.isAudioSharingEnabled;

      if (!mounted) return;

      setState(() {
        _allowAudioReuse = defaultAudioSharing;
      });

      // Populate form with draft data
      _titleController.text = draft.title;
      _descriptionController.text = draft.description;

      // Convert hashtags list back to individual tags
      // (not space-separated like VinePreviewScreenPure)
      _topics
        ..clear()
        ..addAll(draft.hashtags);

      Log.info(
        '📝 VideoEditorMetaSheet: Loaded draft ${draft.id}, '
        'audio sharing default: $defaultAudioSharing',
        category: LogCategory.video,
      );
    } catch (e) {
      Log.error('📝 Failed to load draft: $e', category: LogCategory.video);
    }
  }

  void _addHashtag() {
    final trimmed = _topicsController.text.trim().toLowerCase();
    _topicsController.clear();

    if (trimmed.isNotEmpty && !_topics.contains(trimmed)) {
      _topics.add(trimmed);
      _handleMetaChanges();
      setState(() {});
    }
  }

  void _removeHashtag(String hashtag) {
    _topics.remove(hashtag);
    setState(() {});
  }

  void _handleMetaChanges() {
    final meta = VideoEditorMeta(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      hashtags: _topics,
      allowAudioReuse: _allowAudioReuse ?? false,
      expireTime: _expireTime,
    );

    ref.read(videoEditorProvider.notifier).setMetadata(meta);
  }

  @override
  Widget build(BuildContext context) {
    final totalDuration = ref.watch(
      clipManagerProvider.select((p) => p.totalDuration.toVideoTime()),
    );
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: .min,
          crossAxisAlignment: .stretch,
          spacing: 16,
          children: [
            // Top bar with title and more button
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Untitled video',
                        style: TextStyle(
                          fontFamily: 'BricolageGrotesque',
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          height: 24 / 18,
                          letterSpacing: 0.15,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        totalDuration,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w400,
                          fontSize: 14,
                          height: 20 / 14,
                          letterSpacing: 0.25,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                DivineIconButton(
                  iconPath: 'assets/icon/more_horiz.svg',
                  onTap: () {},
                  backgroundColor: Colors.black,
                  semanticLabel: '',
                ),
              ],
            ),

            /// SizedBox will create a double gap.
            const SizedBox.shrink(),

            // Title field
            VideoEditorMetaInput(
              label: 'Title',
              placeholder: 'Add a title...',
              controller: _titleController,
              maxLines: 1,
              textCapitalization: .sentences,
              keyboardType: .text,
              textInputAction: .next,
            ),

            // Description field
            VideoEditorMetaInput(
              label: 'Description',
              placeholder: 'Add a Description...',
              controller: _descriptionController,
              minLines: 1,
              maxLines: 4,
              keyboardType: .text,
              textInputAction: .next,
            ),

            // Topics field with add button
            Row(
              spacing: 16,
              children: [
                Expanded(
                  child: VideoEditorMetaInput(
                    label: 'Topics',
                    placeholder: 'Add a Topic...',
                    controller: _topicsController,
                    textCapitalization: .sentences,
                    textInputAction: .done,
                    onSubmitted: (_) => _addHashtag(),
                  ),
                ),
                DivineIconButton(
                  iconPath: 'assets/icon/add.svg',
                  onTap: _addHashtag,
                  backgroundColor: const Color(0xFF000000),
                ),
              ],
            ),

            ?_buildTopics(),
          ],
        ),
      ),
    );
  }

  Widget? _buildTopics() {
    if (_topics.isEmpty) return null;

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: _topics
          .map(
            (hashtag) => Chip(
              label: Text('#$hashtag'),
              labelStyle: const TextStyle(color: Colors.white),
              backgroundColor: VineTheme.vineGreen,
              deleteIcon: const Icon(
                Icons.close,
                color: Colors.white,
                size: 18,
              ),
              onDeleted: () => _removeHashtag(hashtag),
            ),
          )
          .toList(),
    );
  }
}
