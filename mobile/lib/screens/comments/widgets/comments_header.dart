// ABOUTME: Header widget for the comments sheet
// ABOUTME: Shows "Comments" title with close button

import 'package:flutter/material.dart';

/// Header widget for the comments draggable sheet.
///
/// Displays a "Comments" title and a close button.
class CommentsHeader extends StatelessWidget {
  const CommentsHeader({required this.onClose, super.key});

  /// Callback when close button is pressed.
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
    child: Row(
      children: [
        const Text(
          'Comments',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        Semantics(
          identifier: 'close_comments_button',
          button: true,
          label: 'Close comments',
          child: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: onClose,
          ),
        ),
      ],
    ),
  );
}
