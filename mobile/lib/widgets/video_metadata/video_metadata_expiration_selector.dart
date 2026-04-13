import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_metadata/video_metadata_expiration.dart';
import 'package:openvine/providers/video_editor_provider.dart';

/// Widget for selecting video expiration time.
///
/// Displays the currently selected expiration option and opens
/// a bottom sheet with all available options when tapped.
class VideoMetadataExpirationSelector extends ConsumerWidget {
  /// Creates a video expiration selector.
  const VideoMetadataExpirationSelector({super.key});

  /// Opens the bottom sheet for selecting expiration time.
  Future<void> _selectExpiration(BuildContext context, WidgetRef ref) async {
    // Dismiss keyboard before showing bottom sheet
    FocusManager.instance.primaryFocus?.unfocus();

    final currentOption = ref.read(
      videoEditorProvider.select((s) => s.expiration),
    );

    final result = await VineBottomSheetSelectionMenu.show(
      context: context,
      selectedValue: currentOption.name,
      title: Text(context.l10n.videoMetadataExpiration),
      options: VideoMetadataExpiration.values.map((option) {
        return VineBottomSheetSelectionOptionData(
          label: option.description,
          value: option.name,
        );
      }).toList(),
    );

    if (result != null && context.mounted) {
      final option = VideoMetadataExpiration.values.firstWhere(
        (el) => el.name == result,
        orElse: () => .notExpire,
      );
      ref.read(videoEditorProvider.notifier).setExpiration(option);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get currently selected expiration option
    final currentOption = ref.watch(
      videoEditorProvider.select((s) => s.expiration),
    );

    return Semantics(
      button: true,
      // TODO(l10n): Replace with context.l10n when localization is added.
      label: 'Select expiration time',
      child: InkWell(
        onTap: () => _selectExpiration(context, ref),
        child: Padding(
          padding: const .all(16),
          child: Column(
            spacing: 8,
            crossAxisAlignment: .stretch,
            children: [
              Text(
                // TODO(l10n): Replace with context.l10n when localization is added.
                'Expiration',
                style: VineTheme.labelSmallFont(
                  color: VineTheme.onSurfaceVariant,
                ),
              ),
              // Current selection with chevron icon
              Row(
                mainAxisAlignment: .spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      currentOption.description,
                      style: VineTheme.titleMediumFont(
                        color: VineTheme.onSurface,
                      ),
                    ),
                  ),
                  const DivineIcon(
                    icon: .caretRight,
                    color: VineTheme.primary,
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
