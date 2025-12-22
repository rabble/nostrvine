// ABOUTME: Reply input widget for responding to specific comments
// ABOUTME: Inline text field with send button, shown when user taps Reply

import 'package:flutter/material.dart';

/// Input widget for posting replies to specific comments.
///
/// Similar to [CommentInput] but styled for inline display within a comment
/// thread.
class CommentsReplyInput extends StatelessWidget {
  const CommentsReplyInput({
    required this.controller,
    required this.isPosting,
    required this.onSubmit,
    super.key,
  });

  /// Text editing controller for the reply input field.
  final TextEditingController controller;

  /// Whether a reply is currently being posted.
  final bool isPosting;

  /// Callback when the send button is pressed.
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(left: 44, top: 8),
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: Colors.grey[900],
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            enableInteractiveSelection: true,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Write a reply...',
              hintStyle: TextStyle(color: Colors.white54),
              border: InputBorder.none,
            ),
            maxLines: null,
          ),
        ),
        IconButton(
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
      ],
    ),
  );
}
