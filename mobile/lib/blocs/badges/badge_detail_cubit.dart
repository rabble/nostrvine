// ABOUTME: Cubit for one badge's detail page: definition, awardees, awarding
// ABOUTME: and revoking recipients, and accepting or removing the viewer's award.

import 'package:badge_repository/badge_repository.dart';
import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/blocs/close_guard.dart';

part 'badge_detail_state.dart';

/// Loads and mutates a single badge.
class BadgeDetailCubit extends Cubit<BadgeDetailState>
    with CloseGuardedEmit<BadgeDetailState> {
  /// Creates the cubit for the badge at [coordinate].
  BadgeDetailCubit({
    required BadgeRepository repository,
    required ContentBlocklistRepository contentBlocklistRepository,
    required BadgeCoordinate coordinate,
  }) : _repository = repository,
       _contentBlocklistRepository = contentBlocklistRepository,
       super(BadgeDetailState(coordinate: coordinate));

  final BadgeRepository _repository;
  final ContentBlocklistRepository _contentBlocklistRepository;

  /// Loads the badge, showing the loading state.
  Future<void> load() async {
    emit(
      state.copyWith(
        status: BadgeDetailStatus.loading,
        actionStatus: BadgeDetailActionStatus.idle,
      ),
    );
    await _load();
  }

  /// Reloads the badge without clearing what is already on screen.
  Future<void> refresh() => _load();

  /// Awards this badge to [recipientPubkeys].
  ///
  /// Does not reload afterwards: the award screen owns this cubit purely to
  /// publish, and pops the moment it completes. Reloading first would spend
  /// two relay round trips per recipient building a detail the route throws
  /// away — the screen underneath refreshes itself on return.
  Future<void> award(List<String> recipientPubkeys) {
    return _runAction(
      BadgeDetailActionStatus.awarding,
      () => _repository.awardBadge(
        coordinate: state.coordinate,
        recipientPubkeys: recipientPubkeys,
      ),
      reload: false,
    );
  }

  /// Pins the viewer's award to their profile badge list.
  Future<void> acceptAward() {
    final award = state.detail?.viewerAward;
    if (award == null) return Future<void>.value();
    return _runAction(
      BadgeDetailActionStatus.accepting,
      () => _repository.acceptAward(award),
    );
  }

  /// Requests deletion of the badge and the awards issued for it.
  ///
  /// Unlike the other actions this does not reload afterwards — the badge is
  /// gone, and the view pops.
  Future<void> deleteBadge() async {
    emit(state.copyWith(actionStatus: BadgeDetailActionStatus.deleting));
    try {
      await _repository.deleteBadge(state.coordinate);
      emitIfOpen(state.copyWith(actionStatus: BadgeDetailActionStatus.deleted));
    } on BadgePublishException catch (error, stackTrace) {
      addError(error, stackTrace);
      emitIfOpen(
        state.copyWith(
          actionStatus: error.outcome.rejectedBy.isEmpty
              ? BadgeDetailActionStatus.failure
              : BadgeDetailActionStatus.deleteRejected,
        ),
      );
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emitIfOpen(state.copyWith(actionStatus: BadgeDetailActionStatus.failure));
    }
  }

  /// Removes the viewer's award from their profile badge list.
  Future<void> removeAward() {
    final award = state.detail?.viewerAward;
    if (award == null) return Future<void>.value();
    return _runAction(
      BadgeDetailActionStatus.removing,
      () => _repository.removeAward(award),
    );
  }

  /// Takes this badge back from [recipientPubkey].
  ///
  /// Reloads afterwards so the revoked row disappears.
  Future<void> revokeAward(String recipientPubkey) {
    return _runAction(
      BadgeDetailActionStatus.revoking,
      () => _repository.revokeAward(
        coordinate: state.coordinate,
        recipientPubkey: recipientPubkey,
      ),
      recipient: recipientPubkey,
      completedStatus: BadgeDetailActionStatus.revoked,
      // Revoking a just-published award is the case the issue exists for,
      // and it is the one a relay is most likely to refuse — same refusal,
      // same advice as a refused badge deletion.
      rejectionStatus: BadgeDetailActionStatus.deleteRejected,
      rejectionEventKind: EventKind.eventDeletion,
    );
  }

  /// Loads the current pubkeys claiming this badge.
  Future<Set<String>> loadClaimantPubkeys() {
    return _repository.loadClaimantPubkeys(state.coordinate);
  }

  /// Blocks the provided badge claimants in one blocklist update.
  Future<void> blockClaimants(Set<String> pubkeys) {
    if (pubkeys.isEmpty) return Future<void>.value();
    return _runAction(
      BadgeDetailActionStatus.blockingClaimants,
      () => _contentBlocklistRepository.blockUsers(pubkeys),
      reload: false,
    );
  }

  Future<void> _load() async {
    try {
      final detail = await _repository.loadBadgeDetail(state.coordinate);
      emitIfOpen(
        state.copyWith(
          status: BadgeDetailStatus.loaded,
          // Same as the catch below: a reload clears the previous action's
          // outcome rather than leaving a stale failure note on screen. An
          // in-flight action keeps its status — it still gates the buttons —
          // and so does `deleted`, which pops the route.
          actionStatus: state.hasSettledAction
              ? BadgeDetailActionStatus.idle
              : state.actionStatus,
          detail: detail,
        ),
      );
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emitIfOpen(
        state.copyWith(
          status: BadgeDetailStatus.failure,
          actionStatus: BadgeDetailActionStatus.idle,
        ),
      );
    }
  }

  /// Runs [action], optionally reloading the badge once it lands.
  ///
  /// [recipient] names the awardee an action targets, so the UI can show the
  /// work on that row rather than across the whole list.
  ///
  /// [completedStatus] and [rejectionStatus] let one action carry its own
  /// outcome where the UI has something better to say than the shared
  /// [BadgeDetailActionStatus.completed] / [BadgeDetailActionStatus.failure]
  /// — the latter only when a relay refused the publish outright. When an
  /// action publishes several events, [rejectionEventKind] restricts that
  /// message to the relevant stage.
  Future<void> _runAction(
    BadgeDetailActionStatus actionStatus,
    Future<void> Function() action, {
    bool reload = true,
    String? recipient,
    BadgeDetailActionStatus completedStatus = BadgeDetailActionStatus.completed,
    BadgeDetailActionStatus? rejectionStatus,
    int? rejectionEventKind,
  }) async {
    emit(
      state.copyWith(actionStatus: actionStatus, actionRecipient: recipient),
    );
    try {
      await action();
      if (!reload) {
        emitIfOpen(state.copyWith(actionStatus: completedStatus));
        return;
      }
      final detail = await _repository.loadBadgeDetail(state.coordinate);
      emitIfOpen(
        state.copyWith(
          status: BadgeDetailStatus.loaded,
          actionStatus: completedStatus,
          detail: detail,
        ),
      );
    } on BadgePublishException catch (error, stackTrace) {
      addError(error, stackTrace);
      emitIfOpen(
        state.copyWith(
          actionStatus:
              rejectionStatus != null &&
                  error.outcome.rejectedBy.isNotEmpty &&
                  (rejectionEventKind == null ||
                      error.eventKind == rejectionEventKind)
              ? rejectionStatus
              : BadgeDetailActionStatus.failure,
        ),
      );
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emitIfOpen(state.copyWith(actionStatus: BadgeDetailActionStatus.failure));
    }
  }
}
