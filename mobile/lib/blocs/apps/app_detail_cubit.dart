import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/models/nostr_app_directory_entry.dart';
import 'package:openvine/services/nostr_app_directory_service.dart';

part 'app_detail_state.dart';

class AppDetailCubit extends Cubit<AppDetailState> {
  AppDetailCubit({
    required NostrAppDirectoryService? directoryService,
    required String slug,
    NostrAppDirectoryEntry? initialEntry,
  }) : _directoryService = directoryService,
       _slug = slug,
       _initialEntry = initialEntry,
       super(const AppDetailState());

  final NostrAppDirectoryService? _directoryService;
  final String _slug;
  final NostrAppDirectoryEntry? _initialEntry;

  Future<void> load() async {
    final initialEntry = _initialEntry;
    if (initialEntry != null) {
      emit(AppDetailState(status: AppDetailStatus.loaded, app: initialEntry));
      return;
    }
    final directoryService = _directoryService;
    if (directoryService == null) {
      emit(const AppDetailState(status: AppDetailStatus.notFound));
      return;
    }

    emit(state.copyWith(status: AppDetailStatus.loading));
    try {
      final apps = await directoryService.fetchApprovedApps();
      for (final app in apps) {
        if (app.slug == _slug) {
          emit(AppDetailState(status: AppDetailStatus.loaded, app: app));
          return;
        }
      }
    } catch (_) {
      emit(const AppDetailState(status: AppDetailStatus.notFound));
      return;
    }

    emit(const AppDetailState(status: AppDetailStatus.notFound));
  }
}
