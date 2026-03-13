// ABOUTME: Custom app bar for conversation detail screen.
// ABOUTME: Shows back button, user name/handle, and options button.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';

/// Top app bar for the conversation detail screen.
///
/// Displays a back button, the other user's display name and handle,
/// and a trailing options button. Styled to match the Figma spec with
/// surfaceContainer icon buttons + outlineMuted borders.
class ConversationAppBar extends StatelessWidget {
  const ConversationAppBar({
    required this.displayName,
    required this.handle,
    required this.onBack,
    required this.onOptions,
    super.key,
  });

  final String displayName;
  final String handle;
  final VoidCallback onBack;
  final VoidCallback onOptions;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: VineTheme.surfaceBackground,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Leading: back button
              Padding(
                padding: const EdgeInsets.all(4),
                child: _IconButton(
                  icon: DivineIconName.caretLeft,
                  onTap: onBack,
                ),
              ),
              const SizedBox(width: 8),
              // Title: name + handle
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        displayName,
                        style: VineTheme.titleMediumFont(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (handle.isNotEmpty)
                        Text(
                          handle,
                          style: VineTheme.bodySmallFont(
                            color: VineTheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ),
              // Trailing: options button
              Padding(
                padding: const EdgeInsets.all(4),
                child: _IconButton(
                  icon: DivineIconName.dotsThreeVertical,
                  onTap: onOptions,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Icon button matching the Figma "icon button" pattern:
/// surfaceContainer bg, outlineMuted 2px border, 16px radius, 8px padding.
class _IconButton extends StatelessWidget {
  const _IconButton({required this.icon, required this.onTap});

  final DivineIconName icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: VineTheme.surfaceContainer,
          border: Border.all(color: VineTheme.outlineMuted, width: 2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: DivineIcon(icon: icon, color: VineTheme.whiteText),
      ),
    );
  }
}
