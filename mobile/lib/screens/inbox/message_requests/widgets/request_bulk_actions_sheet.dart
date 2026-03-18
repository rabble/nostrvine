// ABOUTME: Bottom sheet with bulk actions for message requests.
// ABOUTME: Provides "Mark all requests as read" and "Remove all requests".

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Result of the bulk actions sheet.
enum RequestBulkAction { markAllRead, removeAll }

/// Shows a bottom sheet with bulk actions for message requests.
///
/// Returns the chosen [RequestBulkAction] or `null` if dismissed.
class RequestBulkActionsSheet {
  static Future<RequestBulkAction?> show(BuildContext context) {
    return VineBottomSheet.show<RequestBulkAction>(
      context: context,
      scrollable: false,
      expanded: false,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ActionTile(
            icon: DivineIconName.checks,
            label: 'Mark all requests as read',
            onTap: () => context.pop(RequestBulkAction.markAllRead),
          ),
          _ActionTile(
            icon: DivineIconName.trash,
            label: 'Remove all requests',
            isDestructive: true,
            showDivider: false,
            onTap: () => context.pop(RequestBulkAction.removeAll),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
    this.showDivider = true,
  });

  final DivineIconName icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? VineTheme.error : VineTheme.onSurface;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: showDivider
              ? const Border(
                  bottom: BorderSide(color: VineTheme.outlineDisabled),
                )
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Row(
            spacing: 16,
            children: [
              DivineIcon(icon: icon, color: color),
              Expanded(
                child: Text(
                  label,
                  style: VineTheme.titleMediumFont(color: color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
