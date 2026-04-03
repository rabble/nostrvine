// ABOUTME: Cubit that resolves a NostrAppDirectoryEntry by
// ABOUTME: app ID for the sandbox route screen.

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nostr_app_bridge_repository/nostr_app_bridge_repository.dart';

part 'sandbox_route_state.dart';

/// Resolves an [NostrAppDirectoryEntry] by app ID.
class SandboxRouteCubit extends Cubit<SandboxRouteState> {
  /// Creates the cubit.
  ///
  /// If [initialApp] is non-null the cubit emits
  /// [SandboxRouteResolved] immediately.
  SandboxRouteCubit({
    required String appId,
    required NostrAppDirectoryService directoryService,
    NostrAppDirectoryEntry? initialApp,
  }) : _appId = appId,
       _directoryService = directoryService,
       super(
         initialApp != null
             ? SandboxRouteResolved(initialApp)
             : const SandboxRouteLoading(),
       );

  final String _appId;
  final NostrAppDirectoryService _directoryService;

  /// Fetches the entry from the directory service.
  Future<void> load() async {
    if (state is SandboxRouteResolved) return;
    try {
      final apps = await _directoryService.fetchApprovedApps();
      for (final app in apps) {
        if (app.id == _appId) {
          emit(SandboxRouteResolved(app));
          return;
        }
      }
      emit(const SandboxRouteNotFound());
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emit(const SandboxRouteNotFound());
    }
  }
}
