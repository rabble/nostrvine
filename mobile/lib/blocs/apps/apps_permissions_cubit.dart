import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/services/nostr_app_grant_store.dart';

part 'apps_permissions_state.dart';

class AppsPermissionsCubit extends Cubit<AppsPermissionsState> {
  AppsPermissionsCubit({
    required NostrAppGrantStore grantStore,
    required String? currentUserPubkey,
  }) : _grantStore = grantStore,
       _currentUserPubkey = currentUserPubkey,
       super(const AppsPermissionsState());

  final NostrAppGrantStore _grantStore;
  final String? _currentUserPubkey;

  Future<void> load() async {
    emit(state.copyWith(status: AppsPermissionsStatus.loading));
    emit(
      AppsPermissionsState(
        status: AppsPermissionsStatus.loaded,
        grants: _listGrants(),
      ),
    );
  }

  Future<void> revokeGrant(NostrAppGrant grant) async {
    final userPubkey = _currentUserPubkey;
    if (userPubkey == null || userPubkey.isEmpty) {
      return;
    }

    await _grantStore.revokeGrant(
      userPubkey: userPubkey,
      appId: grant.appId,
      origin: grant.origin,
      capability: grant.capability,
    );

    emit(
      AppsPermissionsState(
        status: AppsPermissionsStatus.loaded,
        grants: _listGrants(),
      ),
    );
  }

  List<NostrAppGrant> _listGrants() {
    final userPubkey = _currentUserPubkey;
    if (userPubkey == null || userPubkey.isEmpty) {
      return const [];
    }
    return _grantStore.listGrants(userPubkey: userPubkey);
  }
}
