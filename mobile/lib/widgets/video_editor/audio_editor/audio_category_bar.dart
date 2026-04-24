import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/l10n/l10n.dart';

class AudioCategoryBar extends StatelessWidget {
  const AudioCategoryBar({
    required this.onSelect,
    required this.category,
    super.key,
  });

  final ValueChanged<AudioCategory> onSelect;
  final AudioCategory category;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: .horizontal,
      padding: const .all(16),
      child: Row(
        spacing: 8,
        children: [
          _Chip(
            onTap: () => onSelect(.diVine),
            isSelected: category == .diVine,
            label: context.l10n.videoEditorAudioCategoryDivine,
          ),
          _Chip(
            onTap: () => onSelect(.community),
            isSelected: category == .community,
            label: context.l10n.videoEditorAudioCategoryCommunity,
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.isSelected,
    required this.onTap,
    required this.label,
  });

  final VoidCallback onTap;
  final bool isSelected;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const .symmetric(horizontal: 16, vertical: 8),
          decoration: ShapeDecoration(
            color: isSelected ? VineTheme.containerLow : null,
            shape: RoundedRectangleBorder(borderRadius: .circular(16)),
          ),
          child: Text(
            label,
            style: VineTheme.titleSmallFont(
              color: isSelected
                  ? VineTheme.primary
                  : VineTheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

enum AudioCategory { diVine, community }
