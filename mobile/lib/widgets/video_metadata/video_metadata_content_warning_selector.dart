// ABOUTME: Widget for selecting NIP-32 content warning labels on videos
// ABOUTME: Multi-select bottom sheet with checkboxes for all ContentLabel values

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/l10n/localized_content_label_name.dart';
import 'package:openvine/models/content_label.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_selection_tile.dart';

/// Widget for selecting content warning labels on a video.
///
/// Displays the currently selected content warnings and opens
/// a multi-select bottom sheet with all available options when tapped.
class VideoMetadataContentWarningSelector extends ConsumerWidget {
  /// Creates a video content warning selector.
  const VideoMetadataContentWarningSelector({super.key});

  /// Opens the multi-select bottom sheet for content warnings.
  Future<void> _selectContentWarnings(
    BuildContext context,
    WidgetRef ref,
  ) async {
    FocusManager.instance.primaryFocus?.unfocus();

    final current = ref.read(
      videoEditorProvider.select((state) => state.contentWarnings),
    );

    final result = await VineBottomSheet.show<Set<ContentLabel>>(
      context: context,
      maxChildSize: 1,
      initialChildSize: 0.9,
      minChildSize: 0.7,
      showHeader: false,
      showDragHandle: false,
      buildScrollBody: (scrollController) => _ContentWarningMultiSelect(
        selected: current,
        scrollController: scrollController,
      ),
    );

    if (result != null && context.mounted) {
      ref.read(videoEditorProvider.notifier).setContentWarnings(result);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final warnings = ref.watch(
      videoEditorProvider.select((state) => state.contentWarnings),
    );

    final isSet = warnings.isNotEmpty;
    final displayText = isSet
        ? warnings
              .map((label) => localizedContentLabelName(context.l10n, label))
              .join(', ')
        : '';

    return VideoMetadataSelectionTile(
      onTap: () => _selectContentWarnings(context, ref),
      semanticsLabel:
          context.l10n.videoMetadataSelectContentWarningsSemanticLabel,
      labelText: context.l10n.videoMetadataContentWarningLabel,
      value: displayText,
    );
  }
}

/// Multi-select bottom sheet for choosing content warning labels.
class _ContentWarningMultiSelect extends StatefulWidget {
  const _ContentWarningMultiSelect({
    required this.selected,
    required this.scrollController,
  });

  final Set<ContentLabel> selected;
  final ScrollController scrollController;

  @override
  State<_ContentWarningMultiSelect> createState() =>
      _ContentWarningMultiSelectState();
}

class _ContentWarningMultiSelectState
    extends State<_ContentWarningMultiSelect> {
  late Set<ContentLabel> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set.of(widget.selected);
  }

  void _toggle(ContentLabel label) {
    setState(() {
      if (_selected.contains(label)) {
        _selected.remove(label);
      } else {
        _selected.add(label);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        VineBottomSheetHeader(
          showDivider: false,
          leadingAction: DivineIconButton(
            icon: .x,
            type: .secondary,
            size: .small,
            onPressed: context.pop,
          ),
          title: const _ContentWarningHeaderTitle(),
          trailingAction: DivineIconButton(
            icon: .check,
            size: .small,
            onPressed: _selected.isNotEmpty
                ? () => context.pop(_selected)
                : null,
          ),
        ),
        const Divider(
          height: 0,
          thickness: 0,
          color: VineTheme.surfaceContainer,
        ),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.only(
              bottom: MediaQuery.paddingOf(context).bottom,
            ),
            controller: widget.scrollController,
            itemCount: ContentLabel.values.length,
            separatorBuilder: (_, _) => const Divider(
              height: 0,
              thickness: 0,
              color: VineTheme.surfaceContainer,
            ),
            itemBuilder: (_, index) {
              final label = ContentLabel.values[index];
              return _ContentLabelTile(
                label: label,
                isChecked: _selected.contains(label),
                onTap: () => _toggle(label),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ContentWarningHeaderTitle extends StatelessWidget {
  const _ContentWarningHeaderTitle();

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 6,
      children: [
        Text(context.l10n.videoMetadataContentWarnings),
        Text(
          context.l10n.videoMetadataContentWarningSelectAllThatApply,
          style: VineTheme.bodySmallFont(color: VineTheme.secondaryText),
        ),
      ],
    );
  }
}

class _ContentLabelTile extends StatelessWidget {
  const _ContentLabelTile({
    required this.label,
    required this.isChecked,
    required this.onTap,
  });

  final ContentLabel label;
  final bool isChecked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isChecked ? VineTheme.surfaceContainer : VineTheme.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  localizedContentLabelName(context.l10n, label),
                  style: VineTheme.titleMediumFont(color: VineTheme.onSurface),
                ),
              ),
              DivineSpriteCheckbox(
                state: isChecked ? .selected : .unselected,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
