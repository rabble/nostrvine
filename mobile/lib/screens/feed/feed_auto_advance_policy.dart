/// Decision output for what a feed should do after a completed play.
enum FeedAutoAdvanceInstruction { next, paginate, wrap, noop }

/// Chooses the next auto-advance action for the current feed state.
FeedAutoAdvanceInstruction decideFeedAutoAdvance({
  required int currentIndex,
  required int itemCount,
  required bool hasMore,
  required bool isLoadingMore,
}) {
  if (itemCount == 0) {
    return FeedAutoAdvanceInstruction.noop;
  }

  if (currentIndex < itemCount - 1) {
    return FeedAutoAdvanceInstruction.next;
  }

  if (hasMore && !isLoadingMore) {
    return FeedAutoAdvanceInstruction.paginate;
  }

  return FeedAutoAdvanceInstruction.wrap;
}
