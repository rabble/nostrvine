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
  /// in [CuratedListManagePostsStatus.success] when every removal succeeded,
  /// or [CuratedListManagePostsStatus.failure] when any did not.
  Future<void> removeSelected() async {
    if (state.status != CuratedListManagePostsStatus.selecting ||
        state.selectedVideoIds.isEmpty) {
      return;
    }

    emit(state.copyWith(status: CuratedListManagePostsStatus.removing));

    var removed = 0;
    var failed = 0;
    for (final videoEventId in Set<String>.from(state.selectedVideoIds)) {
      try {
        final didRemove = await _service.removeVideoFromList(
          _listId,
          videoEventId,
        );
        didRemove ? removed++ : failed++;
      } catch (e, stackTrace) {
        // Expected domain/network failure — surfaced via status, not
        // Crashlytics, per the reportable-error decision matrix.
        addError(e, stackTrace);
        failed++;
      }
    }

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
