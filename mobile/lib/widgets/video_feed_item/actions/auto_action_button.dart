import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/l10n/l10n.dart';

/// Feed-scoped Auto advance rail control.
class AutoActionButton extends StatelessWidget {
  const AutoActionButton({
    required this.isEnabled,
    required this.onPressed,
    super.key,
  });

  final bool isEnabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final iconColor = isEnabled ? VineTheme.vineGreen : VineTheme.whiteText;

    return Semantics(
      identifier: 'auto_button',
      container: true,
      explicitChildNodes: true,
      button: true,
      label: isEnabled
          ? context.l10n.videoActionDisableAutoAdvance
          : context.l10n.videoActionEnableAutoAdvance,
      child: IconButton(
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints.tightFor(width: 48, height: 48),
        style: IconButton.styleFrom(
          highlightColor: VineTheme.transparent,
          splashFactory: NoSplash.splashFactory,
        ),
        onPressed: onPressed,
        icon: DecoratedBox(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: VineTheme.backgroundColor.withValues(alpha: 0.15),
                blurRadius: 15,
                spreadRadius: 1,
              ),
            ],
          ),
          child: SizedBox(
            width: 30,
            height: 20,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  child: DivineIcon(
                    icon: DivineIconName.play,
                    size: 20,
                    color: iconColor,
                  ),
                ),
                Positioned(
                  left: 10,
                  top: 0,
                  child: DivineIcon(
                    icon: DivineIconName.play,
                    size: 20,
                    color: iconColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
