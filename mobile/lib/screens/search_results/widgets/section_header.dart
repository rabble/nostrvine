import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';

/// Section header with a title and optional trailing chevron.
///
/// Used in the "All" search results view to separate People, Tags,
/// Lists, and Videos sections.
class SectionHeader extends StatelessWidget {
  const SectionHeader({required this.title, super.key, this.onTap});

  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      label: title,
      button: onTap != null,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: DecoratedBox(
          // 1 px outline-disabled hairline above and below each section
          // header, matching the Figma list-divider treatment.
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: VineTheme.outlineDisabled, width: 0),
              bottom: BorderSide(color: VineTheme.outlineDisabled, width: 0),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: VineTheme.titleMediumFont().copyWith(
                      color: VineTheme.whiteText,
                    ),
                  ),
                ),
                if (onTap != null)
                  const DivineIcon(
                    icon: DivineIconName.caretRight,
                    color: VineTheme.vineGreen,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
