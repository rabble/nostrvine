// ABOUTME: Widget for selecting NIP-32 content warning labels on videos
// ABOUTME: Multi-select bottom sheet with checkboxes for all ContentLabel values

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/l10n/localized_content_label_name.dart';
import 'package:openvine/models/content_label.dart';
import 'package:openvine/providers/video_editor_provider.dart';

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
      title: Text(context.l10n.videoMetadataContentWarnings),
      maxChildSize: 1,
      initialChildSize: 0.7,
      minChildSize: 0.4,
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
              .map(
                (label) => localizedContentLabelName(context.l10n, label),
              )
              .join(', ')
        : context.l10n.contentWarningNone;

    return Semantics(
      button: true,
      label: context.l10n.videoMetadataSelectContentWarningsSemanticLabel,
      child: InkWell(
        onTap: () => _selectContentWarnings(context, ref),
        child: Padding(
          padding: const .all(16),
          child: Column(
            spacing: 8,
            crossAxisAlignment: .stretch,
            children: [
              Text(
                context.l10n.videoMetadataContentWarningLabel,
                style: VineTheme.labelSmallFont(
                  color: VineTheme.onSurfaceVariant,
                ),
              ),
              // Current selection with chevron icon
              Row(
                mainAxisAlignment: .spaceBetween,
                spacing: 8,
                children: [
                  Flexible(
                    child: Text(
                      displayText,
                      maxLines: 2,
                      overflow: .ellipsis,
                      style: VineTheme.titleMediumFont(
                        color: VineTheme.onSurface,
                      ),
                    ),
                  ),
                  DivineIcon(
                    icon: isSet ? .warning : .caretRight,
                    color: isSet
                        ? VineTheme.contentWarningAmber
                        : VineTheme.primary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              context.l10n.videoMetadataContentWarningSelectAllThatApply,
              style: VineTheme.bodySmallFont(
                color: VineTheme.secondaryText,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: widget.scrollController,
              itemCount: ContentLabel.values.length,
              itemBuilder: (context, index) {
                final label = ContentLabel.values[index];
                final isChecked = _selected.contains(label);
                return CheckboxListTile(
                  value: isChecked,
                  onChanged: (_) => _toggle(label),
                  title: Text(
                    localizedContentLabelName(
                      context.l10n,
                      label,
                    ),
                    style: VineTheme.bodyLargeFont(),
                  ),
                  activeColor: VineTheme.vineGreen,
                  checkColor: VineTheme.whiteText,
                  controlAffinity: ListTileControlAffinity.leading,
                );
              },
            ),
          ),
          Padding(
            padding: const .fromLTRB(16, 8, 16, 16),
            child: DivineButton(
              label: context.l10n.videoMetadataContentWarningDoneButton,
              expanded: true,
              type: .secondary,
              onPressed: () => Navigator.of(context).pop(_selected),
            ),
          ),
        ],
      ),
    );
  }
}
