// ABOUTME: Paginated result wrapper returned by NotificationRepository.
// ABOUTME: Contains enriched, grouped NotificationItems plus cursor metadata.

import 'package:equatable/equatable.dart';
import 'package:models/models.dart';

/// A page of enriched, grouped notifications returned by the repository.
class NotificationPage extends Equatable {
  /// Creates a notification page.
  const NotificationPage({
    required this.items,
    required this.unreadCount,
    this.nextCursor,
    this.hasMore = false,
  });

  /// Empty page used as a default / error fallback.
  static const empty = NotificationPage(items: [], unreadCount: 0);

  /// The enriched, grouped notification items for this page.
  final List<NotificationItem> items;

  /// Total unread notifications reported by the server.
  final int unreadCount;

  /// Cursor for fetching the next page, if available.
  final String? nextCursor;

  /// Whether more pages are available.
  final bool hasMore;

  @override
  List<Object?> get props => [items, unreadCount, nextCursor, hasMore];
}
