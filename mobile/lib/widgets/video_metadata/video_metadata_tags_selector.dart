// ABOUTME: Bottom-sheet widget for searching and managing video hashtags
// ABOUTME: Matches the UserPickerSheet pattern: rounded search field + list rows

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hashtag_repository/hashtag_repository.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_selection_tile.dart';

/// Opens the tags picker as a full-screen modal bottom sheet.
///
/// Returns the updated [Set<String>] of tags, or `null` if dismissed.
Future<Set<String>?> showVideoMetadataTagsSelector(
  BuildContext context, {
  required Set<String> initialTags,
}) {
  return VineBottomSheet.show<Set<String>>(
    context: context,
    initialChildSize: 1,
    maxChildSize: 1,
    minChildSize: 0.8,
    showDragHandle: false,
    showHeader: false,
    buildScrollBody: (scrollController) => _TagsPickerSheet(
      initialTags: initialTags,
      scrollController: scrollController,
    ),
  );
}

/// Tile widget that shows the current tags and opens the picker sheet on tap.
class VideoMetadataTagsSelector extends ConsumerWidget {
  /// Creates a video metadata tags selector.
  const VideoMetadataTagsSelector({super.key});

  Future<void> _openSheet(BuildContext context, WidgetRef ref) async {
    FocusManager.instance.primaryFocus?.unfocus();

    final current = ref.read(
      videoEditorProvider.select((s) => s.tags),
    );

    final result = await showVideoMetadataTagsSelector(
      context,
      initialTags: current,
    );

    if (result != null && context.mounted) {
      ref.read(videoEditorProvider.notifier).updateMetadata(tags: result);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tags = ref.watch(
      videoEditorProvider.select((s) => s.tags),
    );

    return VideoMetadataSelectionTile(
      onTap: () => _openSheet(context, ref),
      semanticsLabel: context.l10n.videoMetadataTagsLabel,
      labelText: context.l10n.videoMetadataTagsLabel,
      value: tags.isEmpty ? '' : tags.join(', '),
    );
  }
}

// ─── Sheet ─────────────────────────────────────────────────────────────────

class _TagsPickerSheet extends ConsumerStatefulWidget {
  const _TagsPickerSheet({
    required this.initialTags,
    this.scrollController,
  });

  final Set<String> initialTags;
  final ScrollController? scrollController;

  @override
  ConsumerState<_TagsPickerSheet> createState() => _TagsPickerSheetState();
}

class _TagsPickerSheetState extends ConsumerState<_TagsPickerSheet> {
  late Set<String> _tags;
  late final HashtagRepository _hashtagRepository;
  final _searchController = TextEditingController();
  String _query = '';
  List<String> _suggestions = [];
  Timer? _debounceTimer;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tags = Set.of(widget.initialTags);
    _hashtagRepository = ref.read(hashtagRepositoryProvider);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    setState(() => _query = query);
    _debounceTimer?.cancel();
    if (query.isEmpty) {
      setState(() {
        _suggestions = [];
        _isLoading = false;
      });
      return;
    }
    _debounceTimer = Timer(const Duration(milliseconds: 350), () async {
      if (!mounted) return;
      setState(() => _isLoading = true);
      final results = await _hashtagRepository.searchHashtags(query: query);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _suggestions = results
            .where(
              (t) => !_tags.any((a) => a.toLowerCase() == t.toLowerCase()),
            )
            .toList();
      });
    });
  }

  void _addTag(String raw) {
    final tag = raw.replaceAll(RegExp('[^a-zA-Z0-9]'), '');
    if (tag.isEmpty) return;
    setState(() {
      _tags.add(tag);
      _suggestions.removeWhere((s) => s.toLowerCase() == tag.toLowerCase());
    });
  }

  void _removeTag(String tag) => setState(() => _tags.remove(tag));

  bool get _canAddQuery {
    if (_query.isEmpty) return false;
    final sanitized = _query.replaceAll(RegExp('[^a-zA-Z0-9]'), '');
    if (sanitized.isEmpty) return false;
    return !_tags.any((t) => t.toLowerCase() == sanitized.toLowerCase());
  }

  static const _searchInputBorderRadius = 20.0;

  @override
  Widget build(BuildContext context) {
    final sanitizedQuery = _query.replaceAll(RegExp('[^a-zA-Z0-9]'), '');
    final hintText = context.l10n.videoMetadataTagsPickerSearchHint;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        VineBottomSheetHeader(
          showDivider: false,
          leadingAction: DivineIconButton(
            icon: .x,
            type: .secondary,
            size: .small,
            onPressed: context.pop,
          ),
          title: Text(
            context.l10n.videoMetadataTags,
            style: VineTheme.titleMediumFont(),
          ),
          trailingAction: DivineIconButton(
            icon: .check,
            size: .small,
            onPressed: () => context.pop(_tags),
          ),
        ),

        // Search field — same style as UserPickerSheet
        Semantics(
          textField: true,
          label: hintText,
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            decoration: BoxDecoration(
              color: VineTheme.surfaceContainer,
              borderRadius: BorderRadius.circular(_searchInputBorderRadius),
            ),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.done,
              autofocus: true,
              autocorrect: false,
              enableSuggestions: false,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]')),
              ],
              onSubmitted: _addTag,
              cursorColor: VineTheme.vineGreen,
              style: VineTheme.bodyLargeFont(color: VineTheme.onSurface),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: VineTheme.bodyLargeFont(
                  color: VineTheme.onSurfaceMuted,
                ),
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(left: 16, right: 8),
                  child: DivineIcon(
                    icon: DivineIconName.search,
                    color: VineTheme.onSurfaceMuted,
                  ),
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(_searchInputBorderRadius),
                  borderSide: const BorderSide(
                    color: VineTheme.primary,
                    width: 2,
                  ),
                ),
                disabledBorder: InputBorder.none,
                filled: false,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
          ),
        ),

        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: _tags.isNotEmpty
              ? ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 128),
                  child: SingleChildScrollView(
                    padding: const .only(bottom: 16),
                    child: _SelectedTagsChipRow(
                      tags: _tags.toList()..sort(),
                      onRemove: _removeTag,
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
        if (_tags.isNotEmpty)
          const Divider(
            height: 1,
            thickness: 1,
            color: VineTheme.outlineDisabled,
          )
        else if (_query.isEmpty)
          const _EmptyState(),

        AnimatedOpacity(
          opacity: _isLoading ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: const LinearProgressIndicator(
            backgroundColor: Colors.transparent,
            color: VineTheme.primary,
            minHeight: 2,
          ),
        ),

        Expanded(
          child: Builder(
            builder: (context) {
              final resultTags = [
                if (_canAddQuery) sanitizedQuery,
                ..._suggestions.where(
                  (s) => s.toLowerCase() != sanitizedQuery.toLowerCase(),
                ),
              ];

              if (_query.isEmpty) {
                return const SizedBox.shrink();
              }

              if (resultTags.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: Text(
                      context.l10n.videoMetadataTagsPickerNoResults,
                      style: VineTheme.bodyMediumFont(
                        color: VineTheme.onSurfaceMuted,
                      ),
                    ),
                  ),
                );
              }

              return SingleChildScrollView(
                controller: widget.scrollController,
                padding: EdgeInsets.only(
                  top: 16,
                  left: 16,
                  right: 16,
                  bottom: MediaQuery.paddingOf(context).bottom + 16,
                ),
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (final tag in resultTags)
                      _SuggestionChip(
                        key: ValueKey(tag),
                        label: tag,
                        onTap: () => _addTag(tag),
                      ),
                  ],
                ),
              );
            },
          ),
        ),

        SizedBox(height: MediaQuery.viewInsetsOf(context).bottom),
      ],
    );
  }
}

/// Chip for a search-result hashtag — tap to add it to the selection.
class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({
    required this.label,
    required this.onTap,
    super.key,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: context.l10n.videoMetadataTagsPickerAddTag(label),
      child: GestureDetector(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: VineTheme.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: .ellipsis,
                    style: VineTheme.titleSmallFont(color: VineTheme.onSurface),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(
                  left: 8,
                  right: 12,
                  top: 8,
                  bottom: 8,
                ),
                child: DivineIcon(
                  icon: .plus,
                  size: 16,
                  color: VineTheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Column(
        mainAxisAlignment: .center,
        spacing: 16,
        children: [
          const DivineIcon(
            icon: .search,
            size: 40,
            color: VineTheme.onSurfaceMuted,
          ),
          Text(
            context.l10n.videoMetadataTagsPickerEmptyHint,
            style: VineTheme.bodyMediumFont(color: VineTheme.onSurfaceMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _SelectedTagsChipRow extends StatelessWidget {
  const _SelectedTagsChipRow({
    required this.tags,
    required this.onRemove,
  });

  final List<String> tags;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          for (final tag in tags)
            _TagChip(
              key: ValueKey(tag),
              label: tag,
              onRemove: () => onRemove(tag),
            ),
        ],
      ),
    );
  }
}

class _TagChip extends StatefulWidget {
  const _TagChip({
    required this.label,
    required this.onRemove,
    super.key,
  });

  final String label;
  final VoidCallback onRemove;

  @override
  State<_TagChip> createState() => _TagChipState();
}

class _TagChipState extends State<_TagChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  bool _isRemoving = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    final curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );
    _fadeAnimation = curved;
    _scaleAnimation = Tween<double>(begin: 0.75, end: 1.0).animate(curved);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleRemove() async {
    if (_isRemoving) return;
    _isRemoving = true;
    await _controller.reverse();
    widget.onRemove();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: VineTheme.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
                child: Text(
                  widget.label,
                  style: VineTheme.titleSmallFont(color: VineTheme.onSurface),
                ),
              ),
              Semantics(
                button: true,
                label: context.l10n.videoMetadataDeleteTagHint(widget.label),
                child: GestureDetector(
                  onTap: _handleRemove,
                  child: const Padding(
                    padding: EdgeInsets.only(
                      left: 8,
                      right: 12,
                      top: 8,
                      bottom: 8,
                    ),
                    child: DivineIcon(
                      icon: .x,
                      size: 16,
                      color: VineTheme.onSurface,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
