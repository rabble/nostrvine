import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/models/nostr_app_directory_entry.dart';
import 'package:openvine/services/nostr_app_directory_service.dart';

part 'sandbox_route_state.dart';

class SandboxRouteCubit extends Cubit<SandboxRouteState> {
  SandboxRouteCubit({
    required NostrAppDirectoryService? directoryService,
    required String appId,
    NostrAppDirectoryEntry? initialApp,
  }) : _directoryService = directoryService,
       _appId = appId,
       _initialApp = initialApp,
       super(const SandboxRouteState());

  final NostrAppDirectoryService? _directoryService;
  final String _appId;
  final NostrAppDirectoryEntry? _initialApp;

  Future<void> load() async {
    final initialApp = _initialApp;
    if (initialApp != null) {
      emit(
        SandboxRouteState(
          status: SandboxRouteStatus.resolved,
          app: initialApp,
        ),
      );
      return;
    }
    final directoryService = _directoryService;
    if (directoryService == null) {
      emit(const SandboxRouteState(status: SandboxRouteStatus.missing));
      return;
    }

    emit(state.copyWith(status: SandboxRouteStatus.loading));
    try {
      final apps = await directoryService.fetchApprovedApps();
      for (final app in apps) {
        if (app.id == _appId) {
          emit(
            SandboxRouteState(
              status: SandboxRouteStatus.resolved,
              app: app,
            ),
          );
          return;
        }
      }
    } catch (_) {
      emit(const SandboxRouteState(status: SandboxRouteStatus.missing));
      return;
    }

    emit(const SandboxRouteState(status: SandboxRouteStatus.missing));
  }
}
