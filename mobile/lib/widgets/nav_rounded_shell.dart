import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/widgets.dart';

/// Paints the bottom-nav color behind rounded shell corners.
class NavRoundedShell extends StatelessWidget {
  const NavRoundedShell({
    required this.child,
    this.innerColor = VineTheme.surfaceBackground,
    super.key,
  });

  final Widget child;
  final Color innerColor;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: VineTheme.navGreen,
    child: ClipRRect(
      borderRadius: const BorderRadius.vertical(
        bottom: Radius.circular(VineTheme.shellCornerRadius),
      ),
      child: ColoredBox(color: innerColor, child: child),
    ),
  );
}
