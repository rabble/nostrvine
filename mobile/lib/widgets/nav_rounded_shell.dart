import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/widgets.dart';

/// Paints the bottom-nav color behind rounded shell corners.
class NavRoundedShell extends StatelessWidget {
  const NavRoundedShell({
    required this.child,
    this.innerColor,
    super.key,
  });

  final Widget child;

  /// Surface painted inside the rounded corners. Defaults to the content
  /// surface of the active appearance mode.
  final Color? innerColor;

  @override
  Widget build(BuildContext context) => ColoredBox(
    // The nav itself stays on the dark brand green in both appearance
    // modes, so only the inner content surface follows the palette.
    color: VineTheme.navGreen,
    child: ClipRRect(
      borderRadius: const BorderRadius.vertical(
        bottom: Radius.circular(VineTheme.shellCornerRadius),
      ),
      child: ColoredBox(
        color: innerColor ?? context.vineColors.surface,
        child: child,
      ),
    ),
  );
}
