import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/models/nostr_app_directory_entry.dart';
import 'package:openvine/services/nostr_app_directory_service.dart';

part 'apps_directory_state.dart';

class AppsDirectoryCubit extends Cubit<AppsDirectoryState> {
  AppsDirectoryCubit({required NostrAppDirectoryService directoryService})
    : _directoryService = directoryService,
      super(const AppsDirectoryState());

  final NostrAppDirectoryService _directoryService;

  Future<void> load() async {
    emit(state.copyWith(status: AppsDirectoryStatus.loading));
    try {
      final apps = await _directoryService.fetchApprovedApps();
      emit(AppsDirectoryState(status: AppsDirectoryStatus.loaded, apps: apps));
    } catch (_) {
      emit(state.copyWith(status: AppsDirectoryStatus.failure));
    }
  }

  Future<void> refresh() async {
    await load();
  }
}
