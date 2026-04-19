/// Shared defaults for auto-advance detection and timing.
///
/// These thresholds are used both by native (`FeedAutoAdvanceCompletionListener`)
/// and web (`WebVideoFeed`) completion detection so the behaviour matches across
/// platforms.
abstract final class FeedAutoAdvanceDefaults {
  /// Position considered "near the start" when detecting a loop crossing.
  ///
  /// A looping player must drop back to at least this position for the crossing
  /// to register, which guards against spurious completions from seeks.
  static const Duration startThreshold = Duration(seconds: 1);

  /// Position considered "near the end" — once the player crosses this mark
  /// the detector arms for a loop boundary crossing.
  ///
  /// Vines cap at 6s, so 1s leaves enough runway on the shortest reasonable
  /// clip to separate "still playing" from "looping".
  static const Duration endThreshold = Duration(seconds: 1);
}

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

  if (hasMore && isLoadingMore) {
    return FeedAutoAdvanceInstruction.noop;
  }

  return FeedAutoAdvanceInstruction.wrap;
}
