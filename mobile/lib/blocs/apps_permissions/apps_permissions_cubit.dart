// ABOUTME: Cubit that loads and revokes persisted app
// ABOUTME: permission grants for the current user.

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nostr_app_bridge_repository/nostr_app_bridge_repository.dart';

part 'apps_permissions_state.dart';

/// Manages the list of persisted permission grants.
class AppsPermissionsCubit extends Cubit<AppsPermissionsState> {
  /// Creates the cubit.
  AppsPermissionsCubit({
    required NostrAppGrantStore grantStore,
    required String? currentUserPubkey,
  }) : _grantStore = grantStore,
       _currentUserPubkey = currentUserPubkey,
       super(const AppsPermissionsState());

  final NostrAppGrantStore _grantStore;
  final String? _currentUserPubkey;

  /// Loads grants for the current user.
  Future<void> loadGrants() async {
    emit(
      state.copyWith(
        status: AppsPermissionsStatus.loading,
      ),
    );

    final pubkey = _currentUserPubkey;
    if (pubkey == null || pubkey.isEmpty) {
      emit(
        state.copyWith(
          status: AppsPermissionsStatus.loaded,
          grants: const [],
        ),
      );
      return;
    }

    final grants = _grantStore.listGrants(userPubkey: pubkey);
    emit(
      state.copyWith(
        status: AppsPermissionsStatus.loaded,
        grants: grants,
      ),
    );
  }

  /// Revokes a single grant and reloads the list.
  Future<void> revokeGrant(NostrAppGrant grant) async {
    final pubkey = _currentUserPubkey;
    if (pubkey == null || pubkey.isEmpty) return;

    await _grantStore.revokeGrant(
      userPubkey: pubkey,
      appId: grant.appId,
      origin: grant.origin,
      capability: grant.capability,
    );

    final grants = _grantStore.listGrants(userPubkey: pubkey);
    emit(
      state.copyWith(
        status: AppsPermissionsStatus.loaded,
        grants: grants,
      ),
    );
  }
}
