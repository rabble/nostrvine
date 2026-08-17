// ABOUTME: Drives the developer clip-recovery section: scan, claim, import.

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/models/clip_recovery.dart';
import 'package:openvine/services/clip_recovery_service.dart';

part 'clip_recovery_state.dart';

/// Drives the Developer Options clip-recovery section.
///
/// Every action re-scans afterwards, so the report on screen always reflects
/// what is left to recover rather than what was there before the action.
class ClipRecoveryCubit extends Cubit<ClipRecoveryState>
    with CloseGuardedEmit<ClipRecoveryState> {
  /// Creates a cubit backed by [service].
  ClipRecoveryCubit({required ClipRecoveryService service})
    : _service = service,
      super(const ClipRecoveryState());

  final ClipRecoveryService _service;

  /// Scans for rows under other owners and unreferenced files on disk.
  Future<void> scan() async {
    emit(state.copyWith(status: ClipRecoveryStatus.scanning));
    try {
      final report = await _service.scanRecoverableClips();
      emitIfOpen(
        state.copyWith(
          status: ClipRecoveryStatus.scanned,
          report: report,
          hasReport: true,
        ),
      );
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emitIfOpen(state.copyWith(status: ClipRecoveryStatus.failure));
    }
  }

  /// Restamps [group]'s rows onto the signed-in account, then re-scans.
  Future<void> claimOwnerGroup(ClipOwnerGroup group) async {
    emit(state.copyWith(status: ClipRecoveryStatus.claiming));
    try {
      final claimed = await _service.claimOwnerGroup(group);
      final report = await _service.scanRecoverableClips();
      emitIfOpen(
        state.copyWith(
          status: ClipRecoveryStatus.claimed,
          report: report,
          lastRecoveredCount: claimed,
          hasReport: true,
        ),
      );
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emitIfOpen(state.copyWith(status: ClipRecoveryStatus.failure));
    }
  }

  /// Rebuilds a library row for [file], then re-scans.
  ///
  /// One file at a time on purpose: the listing shows a preview per row, and
  /// restoring the whole scan would take back recordings the operator looked
  /// at and decided against.
  Future<void> importOrphanFile(OrphanClipFile file) =>
      _importOrphanFiles([file]);

  Future<void> _importOrphanFiles(List<OrphanClipFile> files) async {
    if (files.isEmpty) return;

    emit(state.copyWith(status: ClipRecoveryStatus.importing));
    try {
      final imported = await _service.importOrphanFiles(files);
      // The service logs a file it could not rebuild and carries on, so an
      // empty result is a failure it swallowed rather than a successful import
      // of nothing. Reporting "recovered 0" for it would read as success —
      // and since a rebuild is always one file at a time, empty means *the*
      // file the operator picked did not come back.
      final report = await _service.scanRecoverableClips();
      emitIfOpen(
        state.copyWith(
          status: imported.isEmpty
              ? ClipRecoveryStatus.failure
              : ClipRecoveryStatus.imported,
          report: report,
          lastRecoveredCount: imported.length,
          hasReport: true,
        ),
      );
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emitIfOpen(state.copyWith(status: ClipRecoveryStatus.failure));
    }
  }
}
