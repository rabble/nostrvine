// ABOUTME: Banner widget for message requests shown at top of inbox.
// ABOUTME: Shows "Message requests" label with count badge and chevron.
// ABOUTME: Only rendered when there are pending requests.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';

/// Banner row displayed at the top of the conversation list when there are
/// pending message requests from non-followed users.
///
/// Displays "Message requests" text, a red unread-count badge, and a
/// right chevron. Tapping navigates to the message requests inbox.
class MessageRequestsBanner extends StatelessWidget {
  const MessageRequestsBanner({
    required this.requestCount,
    required this.onTap,
    super.key,
  });

  /// Total number of pending message requests.
  final int requestCount;

  /// Called when the banner is tapped.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Message requests, $requestCount pending',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: VineTheme.outlineDisabled),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Message requests',
                    style: VineTheme.titleMediumFont(),
                  ),
                ),
                if (requestCount > 0) _RequestCountBadge(count: requestCount),
                const SizedBox(width: 8),
                const DivineIcon(
                  icon: DivineIconName.caretRight,
                  color: VineTheme.onSurface,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RequestCountBadge extends StatelessWidget {
  const _RequestCountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';
    return Container(
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: VineTheme.error,
        borderRadius: BorderRadius.circular(1000),
      ),
      child: Center(
        child: Text(
          label,
          style: VineTheme.labelSmallFont(color: VineTheme.onSurface),
        ),
      ),
    );
  }
}
