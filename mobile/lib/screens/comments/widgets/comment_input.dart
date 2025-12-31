// ABOUTME: Main comment input widget at bottom of comments sheet
// ABOUTME: Text field with send button for posting new top-level comments

import 'package:flutter/material.dart';

/// Input widget for posting new top-level comments.
///
/// Positioned at the bottom of the comments sheet with keyboard-aware padding.
class CommentInput extends StatelessWidget {
  const CommentInput({
    required this.controller,
    required this.isPosting,
    required this.onSubmit,
    this.onChanged,
    super.key,
  });

  /// Text editing controller for the input field.
  final TextEditingController controller;

  /// Whether a comment is currently being posted.
  final bool isPosting;

  /// Callback when the send button is pressed.
  final VoidCallback onSubmit;

  /// Callback when the text changes.
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.only(
      left: 16,
      right: 16,
      top: 8,
      bottom: MediaQuery.of(context).viewInsets.bottom + 8,
    ),
    decoration: BoxDecoration(
      color: Colors.grey[900],
      border: Border(top: BorderSide(color: Colors.grey[800]!)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Semantics(
            identifier: 'comment_text_field',
            textField: true,
            label: 'Comment input',
            hint: 'Add a comment',
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              onTapOutside: (_) => FocusScope.of(context).unfocus(),
              enableInteractiveSelection: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Add a comment...',
                hintStyle: TextStyle(color: Colors.white54),
                border: InputBorder.none,
              ),
              maxLines: null,
            ),
          ),
        ),
        Semantics(
          identifier: 'send_comment_button',
          button: true,
          enabled: !isPosting,
          label: isPosting ? 'Posting comment' : 'Send comment',
          child: IconButton(
            onPressed: isPosting ? null : onSubmit,
            icon: isPosting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send, color: Colors.white),
          ),
        ),
      ],
    ),
  );
}
