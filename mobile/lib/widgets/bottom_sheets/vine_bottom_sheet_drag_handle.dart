// ABOUTME: Drag handle indicator for bottom sheets
// ABOUTME: Shows a horizontal bar at the top to indicate draggable behavior

import 'package:flutter/material.dart';
import 'package:openvine/theme/vine_theme.dart';

/// Drag handle indicator shown at the top of bottom sheets.
///
/// This provides a visual affordance that the sheet can be dragged up or down.
/// Design matches Figma specifications: 48px wide, 5px height, rounded.
class VineBottomSheetDragHandle extends StatelessWidget {
  const VineBottomSheetDragHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 48,
        height: 5,
        decoration: BoxDecoration(
          color: VineTheme.onSurfaceMuted,
          borderRadius: BorderRadius.circular(100),
        ),
      ),
    );
  }
}
