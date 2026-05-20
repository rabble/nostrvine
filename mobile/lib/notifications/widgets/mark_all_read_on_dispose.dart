// ABOUTME: Stateful wrapper that calls NotificationRepository.markAllAsRead
// ABOUTME: when its subtree is unmounted (user leaves the notifications view).

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:notification_repository/notification_repository.dart';
import 'package:unified_logger/unified_logger.dart';

/// Wraps a notifications subtree so that all currently-visible notifications
/// are marked as read when the user leaves the screen.
///
/// The wrapper holds a reference to the [NotificationRepository] and fires
/// `markAllAsRead()` once in [dispose]. The call is fire-and-forget — the
/// repository optimistically flips the snapshot before awaiting the API,
/// so the badge and feed reset to zero immediately and any rollback
/// happens on the still-alive repository even after this widget is gone.
class MarkAllReadOnDispose extends StatefulWidget {
  /// Creates a [MarkAllReadOnDispose].
  const MarkAllReadOnDispose({
    required this.repository,
    required this.child,
    super.key,
  });

  /// The notification repository whose `markAllAsRead()` will be invoked
  /// when this widget is disposed.
  final NotificationRepository repository;

  /// The subtree whose unmount triggers `markAllAsRead()`.
  final Widget child;

  @override
  State<MarkAllReadOnDispose> createState() => _MarkAllReadOnDisposeState();
}

class _MarkAllReadOnDisposeState extends State<MarkAllReadOnDispose> {
  @override
  void dispose() {
    // Call the repository directly here because it outlives the bloc teardown;
    // dispatching a bloc event from dispose would race the bloc closing.
    unawaited(
      widget.repository.markAllAsRead().catchError((Object e, StackTrace s) {
        Log.warning(
          'markAllAsRead on notifications leave failed: $e',
          name: 'MarkAllReadOnDispose',
          category: LogCategory.ui,
        );
      }),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
