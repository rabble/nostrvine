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
                  Flexible(
                    child: _CommentTextField(
                      controller: widget.controller,
                      focusNode: widget.focusNode,
                      isReplying: isReplying,
                      onChanged: _handleTextChanged,
                    ),
                  ),
                  if (isReplying)
                    _ReplyIndicator(
                      displayName: widget.replyToDisplayName!,
                      onCancel: widget.onCancelReply!,
                    ),
                ],
              ),
            ),

            if (_hasText) ...[
              const SizedBox(width: 8),
              _SendButton(
                isPosting: widget.isPosting,
                onSubmit: widget.onSubmit,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Text field for entering comment text.
class _CommentTextField extends StatelessWidget {
  const _CommentTextField({
    required this.controller,
    required this.isReplying,
    required this.onChanged,
    this.focusNode,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool isReplying;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 16, bottom: 14, top: 14),
      child: Semantics(
        identifier: 'comment_text_field',
        textField: true,
        label: isReplying ? 'Reply input' : 'Comment input',
        hint: isReplying ? 'Add a reply' : 'Add a comment',
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          onChanged: onChanged,
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
}

/// Send button that appears when text is entered.
class _SendButton extends StatelessWidget {
  const _SendButton({required this.isPosting, required this.onSubmit});

  final bool isPosting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'send_comment_button',
      button: true,
      enabled: !isPosting,
      label: isPosting ? 'Posting comment' : 'Send comment',
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
          onPressed: isPosting ? null : onSubmit,
          padding: EdgeInsets.zero,
          icon: isPosting
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

/// Reply indicator showing who is being replied to.
class _ReplyIndicator extends StatelessWidget {
  const _ReplyIndicator({required this.displayName, required this.onCancel});

  final String displayName;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onCancel,
      child: Padding(
        padding: EdgeInsets.only(left: 16, right: 16, bottom: 8),
        child: Row(
          children: [
            Flexible(
              child: Text(
                'Re: $displayName',
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
    );
  }
}
