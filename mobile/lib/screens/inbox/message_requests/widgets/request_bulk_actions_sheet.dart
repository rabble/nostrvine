// ABOUTME: Bottom sheet with bulk actions for message requests.
// ABOUTME: Provides "Mark all requests as read" and "Remove all requests".

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
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
            iconPath: 'assets/icon/checks.svg',
            label: 'Mark all requests as read',
            onTap: () => context.pop(RequestBulkAction.markAllRead),
          ),
          _ActionTile(
            iconPath: 'assets/icon/trash.svg',
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
    required this.iconPath,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
    this.showDivider = true,
  });

  final String iconPath;
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
              SvgPicture.asset(
                iconPath,
                width: 24,
                height: 24,
                colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
              ),
              Expanded(
                child: Text(
                  label,
                  style: VineTheme.titleMediumFont(
                    fontSize: 16,
                    height: 24 / 16,
                    color: color,
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
