// ABOUTME: Options modal for comment actions (e.g., delete)
// ABOUTME: Shows as bottom sheet with confirmation dialog for destructive actions

import 'package:flutter/material.dart';

/// Modal bottom sheet displaying options for a comment.
///
/// Currently supports:
/// - Delete comment (with confirmation dialog)
///
/// Returns `true` if delete was confirmed, `null` otherwise.
class CommentOptionsModal extends StatelessWidget {
  const CommentOptionsModal({super.key});

  /// Shows the options modal and returns the result.
  ///
  /// Returns `true` if delete was confirmed, `null` if cancelled.
  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const CommentOptionsModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Semantics(
              identifier: 'comment_options_drag_handle',
              label: 'Drag to resize options panel',
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Options',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Divider(color: Colors.grey, height: 1),
            Semantics(
              identifier: 'delete_comment_option',
              button: true,
              label: 'Delete comment',
              child: ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text(
                  'Delete Comment',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () => _showDeleteConfirmation(context),
              ),
            ),
            const Divider(color: Colors.grey, height: 1),
            Semantics(
              identifier: 'cancel_comment_options',
              button: true,
              label: 'Cancel and close options',
              child: ListTile(
                leading: const Icon(Icons.close, color: Colors.white70),
                title: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white70),
                ),
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _showDeleteConfirmation(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2E),
        title: const Text(
          'Delete Comment',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to delete this comment? This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          Semantics(
            identifier: 'cancel_delete_comment_button',
            button: true,
            label: 'Cancel delete',
            child: TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ),
          Semantics(
            identifier: 'confirm_delete_comment_button',
            button: true,
            label: 'Confirm delete comment',
            child: TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      Navigator.of(context).pop(true);
    }
  }
}
