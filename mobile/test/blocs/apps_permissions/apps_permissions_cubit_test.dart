import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_app_bridge_repository/nostr_app_bridge_repository.dart';
import 'package:openvine/blocs/apps_permissions/apps_permissions_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group(AppsPermissionsCubit, () {
    late SharedPreferences prefs;
    late NostrAppGrantStore grantStore;
    const pubkey =
        'ffffffffffffffffffffffffffffffff'
        'ffffffffffffffffffffffffffffffff';

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      grantStore = NostrAppGrantStore(
        sharedPreferences: prefs,
      );
    });

    test('initial state is correct', () {
      final cubit = AppsPermissionsCubit(
        grantStore: grantStore,
        currentUserPubkey: pubkey,
      );
      expect(
        cubit.state.status,
        AppsPermissionsStatus.initial,
      );
      expect(cubit.state.grants, isEmpty);
    });

    blocTest<AppsPermissionsCubit, AppsPermissionsState>(
      'emits [loading, loaded] with grants on loadGrants',
      setUp: () async {
        await grantStore.saveGrant(
          userPubkey: pubkey,
          appId: 'primal-app',
          origin: 'https://primal.net',
          capability: 'signEvent:1',
        );
      },
      build: () => AppsPermissionsCubit(
        grantStore: grantStore,
        currentUserPubkey: pubkey,
      ),
      act: (cubit) => cubit.loadGrants(),
      expect: () => [
        const AppsPermissionsState(
          status: AppsPermissionsStatus.loading,
        ),
        isA<AppsPermissionsState>()
            .having(
              (s) => s.status,
              'status',
              AppsPermissionsStatus.loaded,
            )
            .having(
              (s) => s.grants.length,
              'grants.length',
              1,
            ),
      ],
    );

    blocTest<AppsPermissionsCubit, AppsPermissionsState>(
      'emits empty grants when currentUserPubkey is null',
      build: () => AppsPermissionsCubit(
        grantStore: grantStore,
        currentUserPubkey: null,
      ),
      act: (cubit) => cubit.loadGrants(),
      expect: () => [
        const AppsPermissionsState(
          status: AppsPermissionsStatus.loading,
        ),
        const AppsPermissionsState(
          status: AppsPermissionsStatus.loaded,
        ),
      ],
    );

    blocTest<AppsPermissionsCubit, AppsPermissionsState>(
      'revokeGrant removes the grant and reloads',
      setUp: () async {
        await grantStore.saveGrant(
          userPubkey: pubkey,
          appId: 'primal-app',
          origin: 'https://primal.net',
          capability: 'signEvent:1',
        );
      },
      build: () => AppsPermissionsCubit(
        grantStore: grantStore,
        currentUserPubkey: pubkey,
      ),
      act: (cubit) async {
        await cubit.loadGrants();
        final grant = cubit.state.grants.first;
        await cubit.revokeGrant(grant);
      },
      expect: () => [
        const AppsPermissionsState(
          status: AppsPermissionsStatus.loading,
        ),
        isA<AppsPermissionsState>()
            .having(
              (s) => s.status,
              'status',
              AppsPermissionsStatus.loaded,
            )
            .having(
              (s) => s.grants.length,
              'grants.length',
              1,
            ),
        const AppsPermissionsState(
          status: AppsPermissionsStatus.loaded,
        ),
      ],
    );
  });
}
