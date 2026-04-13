part of 'share_action_button.dart';

// ---------------------------------------------------------------------------
// Message input (shown when a recipient is selected)
// ---------------------------------------------------------------------------

class _MessageInput extends StatelessWidget {
  const _MessageInput({
    required this.controller,
    required this.recipient,
    required this.isSending,
    required this.onSend,
  });

  final TextEditingController controller;
  final ShareableUser recipient;
  final bool isSending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              spacing: 8,
              children: [
                UserAvatar(
                  imageUrl: recipient.picture,
                  name: recipient.displayName,
                  size: 24,
                ),
                Text(
                  context.l10n.shareSendingTo(
                    recipient.displayName ?? context.l10n.shareUserFallback,
                  ),
                  style: const TextStyle(
                    color: VineTheme.secondaryText,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Row(
            spacing: 8,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  style: const TextStyle(
                    color: VineTheme.whiteText,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: context.l10n.shareMessageHint,
                    hintStyle: const TextStyle(color: VineTheme.secondaryText),
                    filled: true,
                    fillColor: VineTheme.containerLow,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 16,
                    ),
                  ),
                  maxLines: 4,
                  minLines: 1,
                  maxLength: 500,
                  buildCounter:
                      (
                        context, {
                        required currentLength,
                        required isFocused,
                        required maxLength,
                      }) => null,
                ),
              ),
              _SendButton(isSending: isSending, onTap: onSend),
            ],
          ),
        ],
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.isSending, required this.onTap});

  final bool isSending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isSending ? null : onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isSending
              ? VineTheme.vineGreen.withValues(alpha: 0.5)
              : VineTheme.vineGreen,
          shape: BoxShape.circle,
        ),
        child: isSending
            ? const Padding(
                padding: EdgeInsets.all(10),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: VineTheme.onPrimary,
                ),
              )
            : const Icon(
                Icons.arrow_upward,
                size: 22,
                color: VineTheme.onPrimary,
              ),
      ),
    );
  }
}
