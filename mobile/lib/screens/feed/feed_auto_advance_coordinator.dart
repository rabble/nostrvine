import 'package:flutter/foundation.dart';
import 'package:openvine/screens/feed/feed_auto_advance_cubit.dart';
import 'package:openvine/screens/feed/feed_auto_advance_policy.dart';

/// The minimal feed snapshot the auto-advance orchestration needs.
///
/// Both `VideoFeedBloc` and `FullscreenFeedBloc` expose the same underlying
/// shape (index + item count + has-more + loading-more) under slightly
/// different names; they are mapped into this record at the call site so the
/// coordinator can be screen-agnostic.
@immutable
class FeedAutoAdvanceSnapshot {
  const FeedAutoAdvanceSnapshot({
    required this.currentIndex,
    required this.itemCount,
    required this.hasMore,
    required this.isLoadingMore,
  });

  final int currentIndex;
  final int itemCount;
  final bool hasMore;
  final bool isLoadingMore;
}

/// Handles a completed play when Auto is active.
///
/// Reads [cubit]'s current state, consults [decideFeedAutoAdvance], and either
/// advances via [animateToPage], queues a pagination advance, wraps to the
/// start, or no-ops.
void handleFeedAutoAdvanceCompleted({
  required FeedAutoAdvanceCubit cubit,
  required FeedAutoAdvanceSnapshot snapshot,
  required void Function(int index) animateToPage,
  required VoidCallback requestLoadMore,
}) {
  if (!cubit.state.isEffectivelyActive) return;

  final instruction = decideFeedAutoAdvance(
    currentIndex: snapshot.currentIndex,
    itemCount: snapshot.itemCount,
    hasMore: snapshot.hasMore,
    isLoadingMore: snapshot.isLoadingMore,
  );

  switch (instruction) {
    case FeedAutoAdvanceInstruction.next:
      cubit.clearPendingPaginationAdvance();
      animateToPage(snapshot.currentIndex + 1);
    case FeedAutoAdvanceInstruction.paginate:
      cubit.markPendingPaginationAdvance();
      requestLoadMore();
    case FeedAutoAdvanceInstruction.wrap:
      cubit.clearPendingPaginationAdvance();
      animateToPage(0);
    case FeedAutoAdvanceInstruction.noop:
      break;
  }
}

/// After a pagination load settles, flushes the queued auto-advance if there
/// is one. If more items arrived, jumps to the next; if the feed is truly
/// exhausted, wraps to the start.
void continueFeedAutoAdvanceAfterPagination({
  required FeedAutoAdvanceCubit cubit,
  required FeedAutoAdvanceSnapshot snapshot,
  required void Function(int index) animateToPage,
}) {
  if (!cubit.state.pendingPaginationAdvance || snapshot.isLoadingMore) {
    return;
  }

  if (snapshot.currentIndex < snapshot.itemCount - 1) {
    cubit.clearPendingPaginationAdvance();
    animateToPage(snapshot.currentIndex + 1);
    return;
  }

  if (!snapshot.hasMore) {
    cubit.clearPendingPaginationAdvance();
    animateToPage(0);
  }
}
