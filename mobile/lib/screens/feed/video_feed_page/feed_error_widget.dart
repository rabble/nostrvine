// ABOUTME: Feed error state widget — shown when the home feed fails to load,
// ABOUTME: with a localized message, optional detail, and a retry action.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/blocs/video_feed/video_feed_bloc.dart';
import 'package:openvine/l10n/l10n.dart';

/// Error state for the home video feed: a warning icon, a localized failure
/// message, the optional underlying [error] detail, and a retry button.
class FeedErrorWidget extends StatelessWidget {
  const FeedErrorWidget({required this.onRetry, this.error, super.key});

  final VideoFeedError? error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const DivineIcon(
            icon: DivineIconName.warningCircle,
            color: VineTheme.error,
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.feedFailedToLoadVideos,
            style: const TextStyle(color: VineTheme.whiteText, fontSize: 18),
          ),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: const TextStyle(color: VineTheme.lightText),
            ),
          ],
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => unawaited(onRetry()),
            child: Text(context.l10n.feedRetry),
          ),
        ],
      ),
    );
  }
}
