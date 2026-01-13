// ABOUTME: Main comment input widget at bottom of comments sheet
// ABOUTME: Text field with send button for posting new top-level comments

import 'package:flutter/material.dart';
import 'package:openvine/theme/vine_theme.dart';

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
  Widget build(BuildContext context) {
    final bottomPadding =
        MediaQuery.of(context).viewInsets.bottom +
        MediaQuery.of(context).padding.bottom +
        16;

    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 16,
        top: 16,
        bottom: bottomPadding,
      ),
      decoration: const BoxDecoration(
        color: VineTheme.surfaceBackground,
        border: Border(
          top: BorderSide(color: VineTheme.outlineVariant, width: 1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
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
                style: VineTheme.bodyFont(
                  fontSize: 16,
                  color: VineTheme.onSurface,
                ),
                decoration: InputDecoration(
                  hintText: 'Add comment...',
                  hintStyle: VineTheme.bodyFont(
                    fontSize: 16,
                    color: VineTheme.onSurfaceMuted,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                maxLines: null,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Semantics(
            identifier: 'send_comment_button',
            button: true,
            enabled: !isPosting,
            label: isPosting ? 'Posting comment' : 'Send comment',
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: VineTheme.tabIndicatorGreen,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 4,
                  ),
                ],
              ),
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
                    : const Icon(
                        Icons.arrow_upward,
                        color: Colors.white,
                        size: 24,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
