import 'package:app_update_repository/app_update_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'app_update_event.dart';
part 'app_update_state.dart';

/// Manages update check lifecycle and exposes state to UI.
///
/// Delegates all caching, dismissal, and escalation logic
/// to [AppUpdateRepository].
class AppUpdateBloc extends Bloc<AppUpdateEvent, AppUpdateState> {
  /// Creates an [AppUpdateBloc].
  AppUpdateBloc({required AppUpdateRepository repository})
    : _repository = repository,
      super(const AppUpdateState()) {
    on<AppUpdateCheckRequested>(_onCheckRequested);
    on<AppUpdateDismissed>(_onDismissed);
  }

  final AppUpdateRepository _repository;

  Future<void> _onCheckRequested(
    AppUpdateCheckRequested event,
    Emitter<AppUpdateState> emit,
  ) async {
    emit(state.copyWith(status: AppUpdateStatus.checking));

    final result = await _repository.checkForUpdate();

    // null means check was skipped (first install or within 24h TTL).
    if (result == null) {
      emit(state.copyWith(status: AppUpdateStatus.initial));
      return;
    }

    // Normalize empty downloadUrl (from UpdateCheckResult.none) to null.
    final downloadUrl = result.downloadUrl.isEmpty ? null : result.downloadUrl;

    emit(
      AppUpdateState(
        status: AppUpdateStatus.resolved,
        urgency: result.urgency,
        latestVersion: result.latestVersion,
        downloadUrl: downloadUrl,
        releaseHighlights: result.releaseHighlights,
        releaseNotesUrl: result.releaseNotesUrl,
      ),
    );
  }

  Future<void> _onDismissed(
    AppUpdateDismissed event,
    Emitter<AppUpdateState> emit,
  ) async {
    if (state.latestVersion != null) {
      await _repository.dismissUpdate(state.latestVersion!);
    }
    emit(state.copyWith(urgency: UpdateUrgency.none));
  }
}
