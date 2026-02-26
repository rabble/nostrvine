import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_fonts/google_fonts.dart';
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
      // TODO(l10n): Replace with context.l10n when localization is added.
      title: const Text('Expiration'),
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
              // TODO(l10n): Replace with context.l10n when localization is added.
              Text(
                'Expiration',
                style: GoogleFonts.inter(
                  color: const Color(0xBFFFFFFF),
                  fontSize: 11,
                  fontWeight: .w600,
                  height: 1.45,
                  letterSpacing: 0.50,
                ),
              ),
              // Current selection with chevron icon
              Row(
                mainAxisAlignment: .spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      currentOption.description,
                      style: VineTheme.titleFont(
                        fontSize: 17,
                        color: const Color(0xF2FFFFFF),
                        letterSpacing: 0.15,
                      ),
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
                        child: SvgPicture.asset(
                          'assets/icon/caret_right.svg',
                          colorFilter: const ColorFilter.mode(
                            VineTheme.tabIndicatorGreen,
                            .srcIn,
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
