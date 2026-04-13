// ABOUTME: Text input bar for composing and sending messages.
// ABOUTME: Matches Figma "commenting v2" component with send button.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';

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
      decoration: const BoxDecoration(
        color: VineTheme.surfaceBackground,
        border: Border(
          top: BorderSide(color: VineTheme.outlineDisabled, width: 2),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: SafeArea(
        top: false,
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: VineTheme.surfaceContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              // Text input
              Expanded(
                child: MediaQuery.withNoTextScaling(
                  child: TextField(
                    controller: _controller,
                    style: VineTheme.bodyLargeFont(),
                    cursorColor: VineTheme.primary,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _handleSend(),
                    decoration: InputDecoration(
                      hintText: 'Say something...',
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
              ),
              // Send button
              if (_hasText)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 4),
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
}
