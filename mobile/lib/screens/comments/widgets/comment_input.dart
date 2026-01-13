// ABOUTME: Main comment input widget at bottom of comments sheet
// ABOUTME: Text field with send button for posting new top-level comments

import 'package:flutter/material.dart';
import 'package:openvine/theme/vine_theme.dart';

/// Input widget for posting new top-level comments.
///
/// Positioned at the bottom of the comments sheet with keyboard-aware padding.
/// Features:
/// - Background container with rounded corners
/// - Conditional send button (hidden when empty)
/// - Reply indicator positioned at bottom inside container
/// - Multiline support with constraints
class CommentInput extends StatefulWidget {
  const CommentInput({
    required this.controller,
    required this.isPosting,
    required this.onSubmit,
    this.onChanged,
    this.replyToDisplayName,
    this.onCancelReply,
    this.focusNode,
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

  /// Display name of the user being replied to (null if not a reply).
  final String? replyToDisplayName;

  /// Callback when the cancel reply button is pressed.
  final VoidCallback? onCancelReply;

  /// Focus node for the text field to allow programmatic focus.
  final FocusNode? focusNode;

  @override
  State<CommentInput> createState() => _CommentInputState();
}

class _CommentInputState extends State<CommentInput> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _hasText = widget.controller.text.trim().isNotEmpty;
  }

  void _handleTextChanged(String text) {
    final hasText = text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() {
        _hasText = hasText;
      });
    }
    widget.onChanged?.call(text);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding =
        MediaQuery.of(context).viewInsets.bottom +
        MediaQuery.of(context).padding.bottom +
        8;

    final isReplying = widget.replyToDisplayName != null;

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: bottomPadding,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: VineTheme.iconButtonBackground,
          borderRadius: BorderRadius.circular(20),
        ),
        constraints: BoxConstraints(minHeight: 48),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(child: _buildTextField()),
                  if (isReplying)
                    GestureDetector(
                      onTap: widget.onCancelReply,
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: 16,
                          right: 16,
                          bottom: 8,
                        ),
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                'Re: ${widget.replyToDisplayName}',
                                style: VineTheme.bodyFont(
                                  fontSize: 12,
                                  color: VineTheme.tabIndicatorGreen,
                                  height: 16 / 12,
                                  fontWeight: FontWeight.w400,
                                ).copyWith(letterSpacing: 0.4),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 20,
                              height: 20,
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.close,
                                size: 16,
                                color: VineTheme.tabIndicatorGreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            if (_hasText) ...[const SizedBox(width: 8), _buildSendButton()],
          ],
        ),
      ),
    );
  }

  Widget _buildTextField() {
    final isReplying = widget.replyToDisplayName != null;
    return Padding(
      padding: EdgeInsets.only(left: 16, bottom: 14, top: 14),
      child: Semantics(
        identifier: 'comment_text_field',
        textField: true,
        label: isReplying ? 'Reply input' : 'Comment input',
        hint: isReplying ? 'Add a reply' : 'Add a comment',
        child: TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          onChanged: _handleTextChanged,
          onTapOutside: (_) => FocusScope.of(context).unfocus(),
          enableInteractiveSelection: true,
          style: VineTheme.bodyFont(
            fontSize: 16,
            color: VineTheme.onSurface,
            height: 20 / 16,
          ),
          cursorColor: VineTheme.tabIndicatorGreen,
          decoration: InputDecoration(
            hintText: 'Add comment...',
            hintStyle: VineTheme.bodyFont(
              fontSize: 16,
              color: const Color.fromARGB(128, 228, 219, 219),
            ),
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
            isDense: true,
          ),
          maxLines: isReplying ? 5 : null,
          minLines: isReplying ? 1 : null,
          textAlignVertical: isReplying ? null : TextAlignVertical.center,
        ),
      ),
    );
  }

  Widget _buildSendButton() {
    return Semantics(
      identifier: 'send_comment_button',
      button: true,
      enabled: !widget.isPosting,
      label: widget.isPosting ? 'Posting comment' : 'Send comment',
      child: Container(
        width: 40,
        height: 40,
        margin: EdgeInsets.only(right: 4, bottom: 4),
        decoration: BoxDecoration(
          color: VineTheme.tabIndicatorGreen,
          borderRadius: BorderRadius.circular(17),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 2,
              offset: const Offset(0.5, 0.5),
            ),
          ],
        ),
        child: IconButton(
          onPressed: widget.isPosting ? null : widget.onSubmit,
          padding: EdgeInsets.zero,
          icon: widget.isPosting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.arrow_upward, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}
