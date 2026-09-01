// ABOUTME: Cubit for the list detail manage-posts mode: tracks which posts
// ABOUTME: are selected and removes them from the list one by one.

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/blocs/curated_list_manage_posts/curated_list_manage_posts_state.dart';
import 'package:openvine/services/curated_list_service.dart';

export 'package:openvine/blocs/curated_list_manage_posts/curated_list_manage_posts_state.dart';

/// Drives the manage-posts mode of the curated list detail screen.
///
/// One instance lives for one manage-mode session: created when the owner
/// enters the mode, closed when they leave it, so the [CuratedListService]
/// captured here cannot outlive the auth session it was read under.
class CuratedListManagePostsCubit extends Cubit<CuratedListManagePostsState>
    with CloseGuardedEmit<CuratedListManagePostsState> {
  /// Creates the cubit for one manage-mode session on [listId].
  CuratedListManagePostsCubit({
    required CuratedListService service,
    required String listId,
  }) : _service = service,
       _listId = listId,
       super(const CuratedListManagePostsState());

  final CuratedListService _service;
  final String _listId;

  /// Toggle whether [videoEventId] is selected for removal.
  ///
  /// Ignored while a removal is running so the batch stays what the user
  /// confirmed.
  void togglePost(String videoEventId) {
    if (state.status == CuratedListManagePostsStatus.removing) return;
    final next = Set<String>.from(state.selectedVideoIds);
    if (!next.add(videoEventId)) {
      next.remove(videoEventId);
    }
    emit(
      state.copyWith(
        status: CuratedListManagePostsStatus.selecting,
        selectedVideoIds: next,
      ),
    );
  }

  /// Remove every selected post from the list, one at a time.
  ///
  /// [CuratedListService.removeVideoFromList] serializes mutations per list,
  /// so the loop awaits each call rather than firing them concurrently. Ends
  /// in [CuratedListManagePostsStatus.success] when no selected post remains
  /// in the list, or [CuratedListManagePostsStatus.failure] when any does.
  Future<void> removeSelected() async {
    if (state.status != CuratedListManagePostsStatus.selecting ||
        state.selectedVideoIds.isEmpty) {
      return;
    }

    emit(state.copyWith(status: CuratedListManagePostsStatus.removing));

    final selected = Set<String>.from(state.selectedVideoIds);
    for (final videoEventId in selected) {
      try {
        await _service.removeVideoFromList(_listId, videoEventId);
      } catch (e, stackTrace) {
        // Expected domain/network failure — surfaced via status, not
        // Crashlytics, per the reportable-error decision matrix.
        addError(e, stackTrace);
      }
    }

    // The returned bool is ambiguous: a failed publish has already committed
    // the removal locally and queued a republish, so counting it as failed
    // would contradict the refreshed grid. Membership after the batch is the
    // truth the user sees — derive the counts from it. A missing list means
    // nothing is left to hold the posts.
    final remaining =
        _service.getListById(_listId)?.videoEventIds.toSet() ??
        const <String>{};
    final failed = selected.where(remaining.contains).length;
    final removed = selected.length - failed;

    emitIfOpen(
      state.copyWith(
        status: failed > 0
            ? CuratedListManagePostsStatus.failure
            : CuratedListManagePostsStatus.success,
        selectedVideoIds: const {},
        removedCount: removed,
        failedCount: failed,
      ),
    );
  }
}
