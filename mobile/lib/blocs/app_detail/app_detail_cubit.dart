// ABOUTME: Cubit that resolves a single app directory entry
// ABOUTME: by slug, for the app detail screen.

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nostr_app_bridge_repository/nostr_app_bridge_repository.dart';

part 'app_detail_state.dart';

/// Resolves an [NostrAppDirectoryEntry] by slug.
class AppDetailCubit extends Cubit<AppDetailState> {
  /// Creates the cubit.
  ///
  /// If [initialEntry] is non-null the cubit emits
  /// [AppDetailLoaded] immediately without a network call.
  AppDetailCubit({
    required String slug,
    required NostrAppDirectoryService directoryService,
    NostrAppDirectoryEntry? initialEntry,
  }) : _slug = slug,
       _directoryService = directoryService,
       super(
         initialEntry != null
             ? AppDetailLoaded(initialEntry)
             : const AppDetailLoading(),
       );

  final String _slug;
  final NostrAppDirectoryService _directoryService;

  /// Fetches the entry from the directory service.
  Future<void> load() async {
    if (state is AppDetailLoaded) return;
    try {
      final apps = await _directoryService.fetchApprovedApps();
      for (final app in apps) {
        if (app.slug == _slug) {
          emit(AppDetailLoaded(app));
          return;
        }
      }
      emit(const AppDetailNotFound());
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emit(const AppDetailNotFound());
    }
  }
}
