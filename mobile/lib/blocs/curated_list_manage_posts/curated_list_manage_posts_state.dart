// ABOUTME: State for CuratedListManagePostsCubit backing the list detail
// ABOUTME: manage-posts mode: tile selection plus batch-removal outcome.

import 'package:equatable/equatable.dart';

/// Lifecycle status for the manage-posts mode of a curated list.
enum CuratedListManagePostsStatus {
  /// The user is picking posts; nothing has been removed yet.
  selecting,

  /// A batch removal is running. Selection is frozen.
  removing,

  /// The last batch removal removed every selected post.
  success,

  /// The last batch removal failed for at least one post.
  failure,
}

/// State emitted by `CuratedListManagePostsCubit`.
class CuratedListManagePostsState extends Equatable {
  /// Creates an immutable state snapshot.
  const CuratedListManagePostsState({
    this.status = CuratedListManagePostsStatus.selecting,
    this.selectedVideoIds = const {},
    this.removedCount = 0,
    this.failedCount = 0,
  });

  /// Where the manage-posts flow currently is.
  final CuratedListManagePostsStatus status;

  /// Event ids of the posts the user has toggled on.
  final Set<String> selectedVideoIds;

  /// Posts removed by the last batch removal.
  final int removedCount;

  /// Posts the last batch removal could not remove.
  final int failedCount;

  /// Copy with the given fields replaced.
  CuratedListManagePostsState copyWith({
    CuratedListManagePostsStatus? status,
    Set<String>? selectedVideoIds,
    int? removedCount,
    int? failedCount,
  }) {
    return CuratedListManagePostsState(
      status: status ?? this.status,
      selectedVideoIds: selectedVideoIds ?? this.selectedVideoIds,
      removedCount: removedCount ?? this.removedCount,
      failedCount: failedCount ?? this.failedCount,
    );
  }

  @override
  List<Object?> get props => [
    status,
    selectedVideoIds,
    removedCount,
    failedCount,
  ];
}
