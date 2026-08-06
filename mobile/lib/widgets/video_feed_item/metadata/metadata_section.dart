// ABOUTME: Reusable section wrapper for the metadata expanded sheet.
// ABOUTME: Renders a labeled section with bottom divider matching Figma spec.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';

/// A labeled section in the metadata expanded sheet.
///
/// Each section has:
/// - A bottom border in the semantic `outlineDisabled` color
/// - 16px padding on all sides
/// - A small label in the semantic `onSurfaceVariant` color
/// - 16px gap between label and content
///
/// Sections conditionally render: pass `null` to [child] or wrap the
/// entire widget in a conditional check to hide sections with no data.
///
/// Pass [onInfoPressed] to append an info icon to the header and make the
/// whole header row tappable — for sections whose content needs explaining.
class MetadataSection extends StatelessWidget {
  const MetadataSection({
    required this.label,
    required this.child,
    this.onInfoPressed,
    this.infoLabel,
    super.key,
  }) : assert(
         (onInfoPressed == null) == (infoLabel == null),
         'infoLabel is required whenever onInfoPressed is set, so the info '
         'affordance is never announced as an unlabeled button',
       );

  /// Section header label (e.g. "Creator", "Tags", "Collaborators").
  final String label;

  /// Section content widget.
  final Widget child;

  /// Opens an explainer for this section. When null, no info icon renders.
  final VoidCallback? onInfoPressed;

  /// Screen-reader label and tooltip for the info affordance.
  ///
  /// Describes the explainer it opens ("What do these checks mean?"), not
  /// the icon.
  final String? infoLabel;

  @override
  Widget build(BuildContext context) {
    final labelText = Text(
      label,
      style: VineTheme.labelSmallFont(
        color: context.vineColors.onSurfaceVariant,
      ),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: context.vineColors.outlineDisabled),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 16,
          children: [
            if (onInfoPressed == null)
              labelText
            else
              _SectionHeaderWithInfo(
                onPressed: onInfoPressed!,
                infoLabel: infoLabel!,
                child: labelText,
              ),
            child,
          ],
        ),
      ),
    );
  }
}

/// Section header whose full width is the tap target for an explainer.
///
/// The tap target is the whole header row rather than the 20 dp icon alone,
/// which is what keeps it comfortably hittable without inflating the header
/// to 48 dp — that would push the Figma-specified 16 px label-to-content gap
/// out of spec for every section using this header.
class _SectionHeaderWithInfo extends StatelessWidget {
  const _SectionHeaderWithInfo({
    required this.onPressed,
    required this.infoLabel,
    required this.child,
  });

  final VoidCallback onPressed;
  final String infoLabel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: infoLabel,
      child: GestureDetector(
        onTap: onPressed,
        behavior: HitTestBehavior.opaque,
        child: Tooltip(
          message: infoLabel,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ExcludeSemantics(child: child),
              DivineIcon(
                icon: DivineIconName.info,
                size: 20,
                color: context.vineColors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
