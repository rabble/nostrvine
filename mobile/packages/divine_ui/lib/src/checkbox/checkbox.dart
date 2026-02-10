import 'package:divine_ui/src/theme/vine_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The state of a checkbox.
enum DivineCheckboxState {
  /// Checkbox is not selected.
  unselected,

  /// Checkbox is selected (checked).
  selected,

  /// Checkbox is in an intermediate/indeterminate state.
  intermediate,

  /// Checkbox is disabled and cannot be interacted with.
  disabled,
}

/// A 24x24 sprite-based checkbox that displays different states
/// by showing different portions of a sprite image.
class DivineSpriteCheckbox extends StatelessWidget {
  /// Creates a sprite-based checkbox.
  const DivineSpriteCheckbox({
    required this.state,
    this.animationDuration = const Duration(milliseconds: 100),
    super.key,
  });

  /// The current state of the checkbox.
  final DivineCheckboxState state;

  /// Duration for state transition animations.
  final Duration animationDuration;

  @override
  Widget build(BuildContext context) {
    // Sprite is 24x72 with three 24x24 sections stacked vertically.
    // Top (0-24): unselected, Mid (24-48): selected, Bot (48-72): intermediate
    final yOffset = switch (state) {
      DivineCheckboxState.unselected || DivineCheckboxState.disabled => 0.0,
      DivineCheckboxState.selected => -24.0,
      DivineCheckboxState.intermediate => -48.0,
    };

    final opacity = state == DivineCheckboxState.disabled ? 0.5 : 1.0;

    return AnimatedOpacity(
      opacity: opacity,
      duration: animationDuration,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6.86),
        child: SizedBox(
          width: 24,
          height: 24,
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: animationDuration,
                curve: Curves.easeInOut,
                top: yOffset,
                left: 0,
                child: SvgPicture.asset(
                  'assets/icon/checkbox-sprite.svg',
                  width: 24,
                  height: 72,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Checkbox with label - combines DivineSpriteCheckbox with a text label.
class DivineCheckbox extends StatelessWidget {
  /// Creates a checkbox with a label.
  const DivineCheckbox({
    required this.state,
    required this.label,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.animationDuration = const Duration(milliseconds: 100),
    super.key,
  });

  /// The current state of the checkbox.
  final DivineCheckboxState state;

  /// The label widget displayed next to the checkbox.
  final Widget label;

  /// How the checkbox and label are aligned vertically.
  final CrossAxisAlignment crossAxisAlignment;

  /// Duration for state transition animations.
  final Duration animationDuration;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: crossAxisAlignment,
      children: [
        DivineSpriteCheckbox(
          state: state,
          animationDuration: animationDuration,
        ),
        const SizedBox(width: 16),
        Expanded(child: label),
      ],
    );
  }
}

/// Row checkbox with animated border.
///
/// Wraps [DivineCheckbox] in an interactive container with a border
/// that changes color based on selection state.
class DivineRowCheckbox extends StatelessWidget {
  /// Creates a row checkbox with an animated border.
  const DivineRowCheckbox({
    required this.state,
    required this.onChanged,
    required this.label,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.animationDuration = const Duration(milliseconds: 100),
    super.key,
  });

  /// The current state of the checkbox.
  final DivineCheckboxState state;

  /// Called when the checkbox is tapped with the new selection state.
  final ValueChanged<bool> onChanged;

  /// The label widget displayed next to the checkbox.
  final Widget label;

  /// How the checkbox and label are aligned vertically.
  final CrossAxisAlignment crossAxisAlignment;

  /// Duration for state transition animations.
  final Duration animationDuration;

  @override
  Widget build(BuildContext context) {
    final isSelected =
        state == DivineCheckboxState.selected ||
        state == DivineCheckboxState.intermediate;

    return GestureDetector(
      onTap: () => onChanged(!isSelected),
      child: AnimatedContainer(
        duration: animationDuration,
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? VineTheme.primary : VineTheme.outlineMuted,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.all(16),
        child: DivineCheckbox(
          state: state,
          label: label,
          crossAxisAlignment: crossAxisAlignment,
          animationDuration: animationDuration,
        ),
      ),
    );
  }
}
