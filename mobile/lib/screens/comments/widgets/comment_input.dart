// ABOUTME: Main comment input widget at bottom of comments sheet
// ABOUTME: Text field with send button for posting new top-level comments

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/blocs/comments/comments_bloc.dart';
import 'package:openvine/screens/comments/widgets/mention_overlay.dart';

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
    required this.onSubmit,
    this.onChanged,
    this.replyToDisplayName,
    this.onCancelReply,
    this.isEditing = false,
    this.onCancelEdit,
    this.focusNode,
    this.mentionSuggestions = const [],
    this.onMentionQuery,
    this.onMentionSelected,
    super.key,
  });

  /// Text editing controller for the input field.
  final TextEditingController controller;

  /// Callback when the send button is pressed.
  final VoidCallback onSubmit;

  /// Callback when the text changes.
  final ValueChanged<String>? onChanged;

  /// Display name of the user being replied to (null if not a reply).
  final String? replyToDisplayName;

  /// Callback when the cancel reply button is pressed.
  final VoidCallback? onCancelReply;

  /// Whether the input is in edit mode.
  final bool isEditing;

  /// Callback when the cancel edit button is pressed.
  final VoidCallback? onCancelEdit;

  /// Focus node for the text field to allow programmatic focus.
  final FocusNode? focusNode;

  /// Mention suggestions for autocomplete overlay.
  final List<MentionSuggestion> mentionSuggestions;

  /// Callback fired with the query text after '@'.
  final ValueChanged<String>? onMentionQuery;

  /// Callback fired with (npub, displayName) when a mention is selected.
  final void Function(String npub, String displayName)? onMentionSelected;

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

    // Detect @mention query
    _detectMentionQuery(text);

    widget.onChanged?.call(text);
  }

  void _detectMentionQuery(String text) {
    final cursorPos = widget.controller.selection.baseOffset;
    if (cursorPos < 0) return;

    // Find the last @ before cursor
    final textBeforeCursor = text.substring(0, cursorPos);
    final atIndex = textBeforeCursor.lastIndexOf('@');

    if (atIndex >= 0) {
      // Check there's no space between @ and cursor (query is continuous)
      final query = textBeforeCursor.substring(atIndex + 1);
      if (!query.contains(' ') && !query.contains('\n')) {
        widget.onMentionQuery?.call(query);
        return;
      }
    }

    // No active mention query
    widget.onMentionQuery?.call('');
  }

  void _handleMentionSelected(String npub, String displayName) {
    final text = widget.controller.text;
    final cursorPos = widget.controller.selection.baseOffset;
    if (cursorPos < 0) return;

    final textBeforeCursor = text.substring(0, cursorPos);
    final atIndex = textBeforeCursor.lastIndexOf('@');
    if (atIndex < 0) return;

    // Replace @query with @displayName (human-readable)
    // The BLoC will convert @displayName -> nostr:npub on submit
    final mention = '@$displayName ';
    final newText =
        text.substring(0, atIndex) + mention + text.substring(cursorPos);
    widget.controller.text = newText;
    widget.controller.selection = TextSelection.collapsed(
      offset: atIndex + mention.length,
    );

    widget.onMentionSelected?.call(npub, displayName);
    widget.onChanged?.call(newText);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding =
        MediaQuery.of(context).viewInsets.bottom +
        MediaQuery.of(context).padding.bottom +
        8;

    final isReplying = widget.replyToDisplayName != null;
    final isEditing = widget.isEditing;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Mention overlay (shows above input when suggestions available)
        if (widget.mentionSuggestions.isNotEmpty)
          MentionOverlay(
            suggestions: widget.mentionSuggestions,
            onSelect: _handleMentionSelected,
          ),
        // Input container
        Container(
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
            constraints: const BoxConstraints(minHeight: 48),
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
                          isEditing: isEditing,
                          onChanged: _handleTextChanged,
                        ),
                      ),
                      if (isEditing)
                        _EditIndicator(onCancel: widget.onCancelEdit!)
                      else if (isReplying)
                        _ReplyIndicator(
                          displayName: widget.replyToDisplayName!,
                          onCancel: widget.onCancelReply!,
                        ),
                    ],
                  ),
                ),
                if (_hasText) ...[
                  const SizedBox(width: 8),
                  _SendButton(onSubmit: widget.onSubmit),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Text field for entering comment text.
class _CommentTextField extends StatelessWidget {
  const _CommentTextField({
    required this.controller,
    required this.isReplying,
    required this.onChanged,
    this.isEditing = false,
    this.focusNode,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool isReplying;
  final bool isEditing;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final semanticLabel = isEditing
        ? 'Edit input'
        : isReplying
        ? 'Reply input'
        : 'Comment input';
    final semanticHint = isEditing
        ? 'Edit comment'
        : isReplying
        ? 'Add a reply'
        : 'Add a comment';
    final hintText = isEditing ? 'Edit comment...' : 'Add comment...';
    final isMultiline = isReplying || isEditing;

    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 16, bottom: 14, top: 14),
      child: Semantics(
        identifier: 'comment_text_field',
        textField: true,
        label: semanticLabel,
        hint: semanticHint,
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          onChanged: onChanged,
          onTapOutside: (_) => FocusScope.of(context).unfocus(),
          enableInteractiveSelection: true,
          style: VineTheme.bodyLargeFont(color: VineTheme.onSurface),
          cursorColor: VineTheme.tabIndicatorGreen,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: VineTheme.bodyLargeFont(
              color: const Color.fromARGB(128, 228, 219, 219),
            ),
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
            isDense: true,
          ),
          maxLines: isMultiline ? 5 : null,
          minLines: isMultiline ? 1 : null,
          textAlignVertical: isMultiline ? null : TextAlignVertical.center,
        ),
      ),
    );
  }
}

/// Send button that appears when text is entered.
///
/// Stays visually as a sendable up-arrow at all times. Comment posting is
/// optimistic at the BLoC layer (see CommentsBloc._onSubmitted): the
/// comment lands in the list before the network call, so this button has
/// no in-flight state to surface — matching WhatsApp/Telegram-style
/// instant-send affordance.
class _SendButton extends StatelessWidget {
  const _SendButton({required this.onSubmit});

  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'send_comment_button',
      button: true,
      label: 'Send comment',
      child: Container(
        width: 40,
        height: 40,
        margin: const EdgeInsetsDirectional.only(end: 4, bottom: 4),
        decoration: BoxDecoration(
          color: VineTheme.tabIndicatorGreen,
          borderRadius: BorderRadius.circular(17),
          boxShadow: [
            BoxShadow(
              color: VineTheme.backgroundColor.withValues(alpha: 0.1),
              blurRadius: 2,
              offset: const Offset(0.5, 0.5),
            ),
          ],
        ),
        child: IconButton(
          onPressed: onSubmit,
          padding: EdgeInsets.zero,
          icon: const Icon(
            Icons.arrow_upward,
            color: VineTheme.whiteText,
            size: 20,
          ),
        ),
      ),
    );
  }
}

/// Edit indicator showing the comment is being edited.
class _EditIndicator extends StatelessWidget {
  const _EditIndicator({required this.onCancel});

  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onCancel,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(
          start: 16,
          end: 16,
          bottom: 8,
        ),
        child: Row(
          children: [
            Flexible(
              child: Text(
                'Editing',
                style: VineTheme.bodySmallFont(
                  color: VineTheme.tabIndicatorGreen,
                ),
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
        padding: const EdgeInsetsDirectional.only(
          start: 16,
          end: 16,
          bottom: 8,
        ),
        child: Row(
          children: [
            Flexible(
              child: Text(
                'Re: $displayName',
                style: VineTheme.bodySmallFont(
                  color: VineTheme.tabIndicatorGreen,
                ),
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
