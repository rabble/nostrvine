// ABOUTME: Empty state widget for comments section
// ABOUTME: Shows message when no comments exist, with special notice for classic vines

import 'package:flutter/material.dart';
import 'package:openvine/theme/vine_theme.dart';

/// Empty state widget displayed when there are no comments.
///
/// Shows a special "Classic Vine" notice for archived videos where
/// original comments haven't been imported yet.
class CommentsEmptyState extends StatelessWidget {
  const CommentsEmptyState({required this.isClassicVine, super.key});

  /// Whether this video is a classic vine from the archive.
  /// Shows additional context about pending comment import.
  final bool isClassicVine;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isClassicVine) ...[
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.shade900.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.orange.shade700.withValues(alpha: 0.5),
              ),
            ),
            child: Column(
              children: [
                Icon(Icons.history, color: Colors.orange.shade300, size: 32),
                const SizedBox(height: 12),
                Text(
                  'Classic Vine',
                  style: TextStyle(
                    color: Colors.orange.shade300,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "We're still working on importing old comments "
                  "from the archive. They're not ready yet.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'No comments yet',
              textAlign: TextAlign.center,
              style: VineTheme.titleFont(
                fontSize: 22,
                color: VineTheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Get the party started!',
              textAlign: TextAlign.center,
              style: VineTheme.bodyFont(
                fontSize: 14,
                color: Color(0xBFFFFFFF), // rgba(255,255,255,0.75)
              ).copyWith(height: 20 / 14, letterSpacing: 0.25),
            ),
          ],
        ),
      ],
    ),
  );
}
