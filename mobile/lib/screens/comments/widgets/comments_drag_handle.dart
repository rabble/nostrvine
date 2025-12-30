// ABOUTME: Visual drag handle indicator for bottom sheets
// ABOUTME: Provides affordance for draggable sheet interaction

import 'package:flutter/material.dart';

class CommentsDragHandle extends StatelessWidget {
  const CommentsDragHandle({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    identifier: 'comments_drag_handle',
    label: 'Drag to resize comments panel',
    child: Container(
      width: 40,
      height: 4,
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white54,
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );
}
