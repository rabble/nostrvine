import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/widgets.dart';

/// A drag handle indicator for bottom sheets.
///
/// Displays a small horizontal bar that indicates the sheet can be dragged.
// coverage:ignore-start
class VineBottomSheetDragHandle extends StatelessWidget {
  /// Creates a bottom sheet drag handle.
  const VineBottomSheetDragHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 4,
      decoration: BoxDecoration(
        color: VineTheme.alphaLight25,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}

// coverage:ignore-end
