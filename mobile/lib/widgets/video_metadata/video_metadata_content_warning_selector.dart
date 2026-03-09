// ABOUTME: Widget for selecting NIP-32 content warning labels on videos
// ABOUTME: Multi-select bottom sheet with checkboxes for all ContentLabel values

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_fonts/google_fonts.dart';
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

    final result = await _ContentWarningMultiSelect.show(
      context: context,
      selected: current,
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
        ? warnings.map((label) => label.displayName).join(', ')
        : 'None';
    final iconColor = isSet
        ? const Color(0xFFFFB84D)
        : VineTheme.tabIndicatorGreen;

    return Semantics(
      button: true,
      label: 'Select content warnings',
      child: InkWell(
        onTap: () => _selectContentWarnings(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            spacing: 8,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Content Warning',
                style: GoogleFonts.inter(
                  color: const Color(0xBFFFFFFF),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  height: 1.45,
                  letterSpacing: 0.5,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      displayText,
                      style: VineTheme.titleFont(
                        fontSize: 17,
                        color: const Color(0xF2FFFFFF),
                        letterSpacing: 0.15,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: const Color(0x8C032017),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: VineTheme.outlineVariant),
                    ),
                    child: Center(
                      child: SizedBox(
                        height: 18,
                        width: 18,
                        child: isSet
                            ? Icon(
                                Icons.warning_amber_rounded,
                                size: 18,
                                color: iconColor,
                              )
                            : SvgPicture.asset(
                                'assets/icon/caret_right.svg',
                                colorFilter: ColorFilter.mode(
                                  iconColor,
                                  BlendMode.srcIn,
                                ),
                              ),
                      ),
                    ),
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
  const _ContentWarningMultiSelect({required this.selected});

  final Set<ContentLabel> selected;

  /// Show the multi-select bottom sheet and return selected labels.
  ///
  /// Returns `null` if dismissed without saving.
  static Future<Set<ContentLabel>?> show({
    required BuildContext context,
    required Set<ContentLabel> selected,
  }) {
    return showModalBottomSheet<Set<ContentLabel>>(
      context: context,
      backgroundColor: VineTheme.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (_) => _ContentWarningMultiSelect(selected: selected),
    );
  }

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

  void _clearAll() {
    setState(_selected.clear);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: VineTheme.onSurfaceMuted,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Content Warnings',
                    style: VineTheme.titleFont(fontSize: 18),
                  ),
                  if (_selected.isNotEmpty)
                    TextButton(
                      onPressed: _clearAll,
                      child: const Text(
                        'Clear All',
                        style: TextStyle(color: VineTheme.vineGreen),
                      ),
                    ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Select all that apply to your content',
                style: TextStyle(color: VineTheme.secondaryText, fontSize: 13),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: ContentLabel.values.length,
                itemBuilder: (context, index) {
                  final label = ContentLabel.values[index];
                  final isChecked = _selected.contains(label);
                  return CheckboxListTile(
                    value: isChecked,
                    onChanged: (_) => _toggle(label),
                    title: Text(
                      label.displayName,
                      style: const TextStyle(
                        color: VineTheme.whiteText,
                        fontSize: 15,
                      ),
                    ),
                    activeColor: VineTheme.vineGreen,
                    checkColor: VineTheme.whiteText,
                    controlAffinity: ListTileControlAffinity.leading,
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(_selected),
                    child: const Text('Done'),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
