// ABOUTME: Cubit that loads and refreshes the approved
// ABOUTME: third-party app directory for display in the UI.

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nostr_app_bridge_repository/nostr_app_bridge_repository.dart';

part 'apps_directory_state.dart';

/// Loads approved third-party apps from the directory service.
class AppsDirectoryCubit extends Cubit<AppsDirectoryState> {
  /// Creates the cubit with the given [directoryService].
  AppsDirectoryCubit({required NostrAppDirectoryService directoryService})
    : _directoryService = directoryService,
      super(const AppsDirectoryState());

  final NostrAppDirectoryService _directoryService;

  /// Fetches approved apps from the directory service.
  Future<void> loadApps() async {
    emit(state.copyWith(status: AppsDirectoryStatus.loading));
    try {
      final apps = await _directoryService.fetchApprovedApps();
      emit(state.copyWith(status: AppsDirectoryStatus.loaded, apps: apps));
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emit(state.copyWith(status: AppsDirectoryStatus.error));
    }
  }

  /// Refreshes the app list without showing a loading state.
  Future<void> refreshApps() async {
    try {
      final apps = await _directoryService.fetchApprovedApps();
      emit(state.copyWith(status: AppsDirectoryStatus.loaded, apps: apps));
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emit(state.copyWith(status: AppsDirectoryStatus.error));
    }
  }
}
