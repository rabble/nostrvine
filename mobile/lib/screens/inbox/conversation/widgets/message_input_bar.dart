// ABOUTME: Text input bar for composing and sending messages.
// ABOUTME: Matches Figma "commenting v2" component with send button.
// ABOUTME: Selection context menu adds wrap/unwrap actions for inline
// ABOUTME: markdown (bold / italic / strike / code) — #4621.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/l10n/l10n.dart';

/// Markdown delimiters the selection toolbar can wrap selected text
/// with. Kept package-private so the bar's tests can target the
/// individual handlers by delimiter.
@visibleForTesting
const String boldDelimiter = '**';
@visibleForTesting
const String italicDelimiter = '_';
@visibleForTesting
const String strikeDelimiter = '~~';
@visibleForTesting
const String codeDelimiter = '`';

/// Message input bar at the bottom of the conversation screen.
///
/// Features a text field with surfaceContainer background, 20px radius,
/// and a green send button that appears when text is entered.
class MessageInputBar extends StatefulWidget {
  const MessageInputBar({
    required this.onSend,
    this.isSending = false,
    super.key,
  });

  final ValueChanged<String> onSend;
  final bool isSending;

  @override
  State<MessageInputBar> createState() => _MessageInputBarState();
}

class _MessageInputBarState extends State<MessageInputBar> {
  final _controller = TextEditingController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onTextChanged)
      ..dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = _controller.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isEmpty || widget.isSending) return;
    widget.onSend(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: VineTheme.surfaceBackground,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: SafeArea(
        top: false,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          decoration: BoxDecoration(
            color: VineTheme.surfaceContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            // Anchor send button to pill bottom as the field grows.
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Text input
              Expanded(
                // Field honours font scaling (#4620): no withNoTextScaling.
                child: TextField(
                  controller: _controller,
                  style: VineTheme.bodyLargeFont(),
                  cursorColor: VineTheme.primary,
                  keyboardType: TextInputType.multiline,
                  // Return = newline; send via button only (#4620).
                  textInputAction: TextInputAction.newline,
                  minLines: 1,
                  maxLines: 5,
                  contextMenuBuilder: _buildContextMenu,
                  decoration: InputDecoration(
                    hintText: context.l10n.dmMessageInputHint,
                    hintStyle: VineTheme.bodyLargeFont(
                      color: VineTheme.onSurfaceMuted,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              // Send button
              if (_hasText)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 4, bottom: 4),
                  child: GestureDetector(
                    onTap: _handleSend,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: VineTheme.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: widget.isSending
                          ? const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: VineTheme.surfaceBackground,
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : const Center(
                              child: DivineIcon(
                                icon: DivineIconName.arrowUp,
                                color: VineTheme.surfaceBackground,
                                size: 20,
                              ),
                            ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Selection toolbar with the platform's default items (cut / copy /
  /// paste / select all) plus four markdown formatting actions when
  /// the user has a non-empty selection. Each action wraps the
  /// selection with the corresponding markdown delimiter, or unwraps
  /// it if the selection is already enclosed by that delimiter.
  Widget _buildContextMenu(
    BuildContext context,
    EditableTextState editableTextState,
  ) {
    final items = <ContextMenuButtonItem>[];
    final selection = editableTextState.textEditingValue.selection;
    if (selection.isValid && !selection.isCollapsed) {
      final l10n = context.l10n;
      items.addAll([
        ContextMenuButtonItem(
          label: l10n.dmFormatBold,
          onPressed: () => _wrapSelection(editableTextState, boldDelimiter),
        ),
        ContextMenuButtonItem(
          label: l10n.dmFormatItalic,
          onPressed: () => _wrapSelection(editableTextState, italicDelimiter),
        ),
        ContextMenuButtonItem(
          label: l10n.dmFormatStrikethrough,
          onPressed: () => _wrapSelection(editableTextState, strikeDelimiter),
        ),
        ContextMenuButtonItem(
          label: l10n.dmFormatCode,
          onPressed: () => _wrapSelection(editableTextState, codeDelimiter),
        ),
      ]);
    }
    items.addAll(editableTextState.contextMenuButtonItems);
    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: editableTextState.contextMenuAnchors,
      buttonItems: items,
    );
  }

  /// Wraps the current selection in [editableTextState] with
  /// [delimiter] on both sides — or, if the selection is already
  /// surrounded by that delimiter, unwraps it. Updates the underlying
  /// controller via [EditableTextState.userUpdateTextEditingValue] so
  /// the platform's undo / redo stack tracks the change.
  void _wrapSelection(EditableTextState state, String delimiter) {
    final value = state.textEditingValue;
    final selection = value.selection;
    if (!selection.isValid || selection.isCollapsed) return;

    final text = value.text;
    final start = selection.start;
    final end = selection.end;
    final selected = text.substring(start, end);

    final before = text.substring(0, start);
    final after = text.substring(end);

    final hasDelimiterBefore =
        start >= delimiter.length &&
        text.substring(start - delimiter.length, start) == delimiter;
    final hasDelimiterAfter =
        end + delimiter.length <= text.length &&
        text.substring(end, end + delimiter.length) == delimiter;

    final TextEditingValue newValue;
    if (hasDelimiterBefore && hasDelimiterAfter) {
      // Unwrap: drop the surrounding delimiters, keep selection on
      // the original content.
      final newText =
          before.substring(0, before.length - delimiter.length) +
          selected +
          after.substring(delimiter.length);
      newValue = TextEditingValue(
        text: newText,
        selection: TextSelection(
          baseOffset: start - delimiter.length,
          extentOffset: end - delimiter.length,
        ),
      );
    } else {
      // Wrap: insert delimiters around the selection, then keep the
      // (now-wrapped) text selected so a second tap can unwrap.
      final newText = '$before$delimiter$selected$delimiter$after';
      newValue = TextEditingValue(
        text: newText,
        selection: TextSelection(
          baseOffset: start + delimiter.length,
          extentOffset: end + delimiter.length,
        ),
      );
    }

    state
      ..userUpdateTextEditingValue(newValue, SelectionChangedCause.toolbar)
      ..hideToolbar();
  }
}
