import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
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
  Future<void> _selectExpiration(BuildContext context) async {
    // Dismiss keyboard before showing bottom sheet
    FocusManager.instance.primaryFocus?.unfocus();

    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: VineTheme.surfaceBackground,
      builder: (context) => const _ExpirationOptionsBottomSheet(),
    );
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
        onTap: () => _selectExpiration(context),
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
                        fontSize: 18,
                        color: const Color(0xF2FFFFFF),
                        letterSpacing: 0.15,
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 24,
                    width: 24,
                    child: SvgPicture.asset(
                      'assets/icon/caret_right.svg',
                      colorFilter: const ColorFilter.mode(
                        VineTheme.tabIndicatorGreen,
                        .srcIn,
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

/// Bottom sheet displaying all available expiration options.
class _ExpirationOptionsBottomSheet extends ConsumerWidget {
  /// Creates an expiration options bottom sheet.
  const _ExpirationOptionsBottomSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get currently selected expiration option for checkmark
    final currentOption = ref.watch(
      videoEditorProvider.select((s) => s.expiration),
    );

    return SafeArea(
      child: Column(
        mainAxisSize: .min,
        spacing: 16,
        children: [
          // Drag handle at top (fixed)
          const Padding(
            padding: .only(top: 8),
            child: VineBottomSheetDragHandle(),
          ),
          // Title (fixed)
          // TODO(l10n): Replace with context.l10n when localization is added.
          Text(
            'Expiration',
            style: GoogleFonts.bricolageGrotesque(
              fontSize: 18,
              fontWeight: .w800,
              color: Colors.white,
              height: 1.33,
              letterSpacing: 0.15,
            ),
          ),
          // Scrollable list of expiration options
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: .min,
                children: VideoMetadataExpiration.values.map((option) {
                  final isSelected = option == currentOption;

                  return ListTile(
                    selected: isSelected,
                    selectedTileColor: const Color(0xFF032017),
                    title: Text(
                      option.description,
                      style: GoogleFonts.bricolageGrotesque(
                        color: VineTheme.onSurface,
                        fontSize: 18,
                        fontWeight: .w800,
                        height: 1.33,
                        letterSpacing: 0.15,
                      ),
                    ),
                    // Show checkmark for selected option
                    trailing: isSelected
                        ? const Icon(
                            Icons.check,
                            size: 24,
                            color: Color(0xFF27C58B),
                          )
                        : null,
                    onTap: () {
                      // Update selection and close bottom sheet
                      ref
                          .read(videoEditorProvider.notifier)
                          .setExpiration(option);
                      context.pop();
                    },
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
