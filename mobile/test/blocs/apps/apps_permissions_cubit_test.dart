import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/apps/apps_permissions_cubit.dart';
import 'package:openvine/services/nostr_app_grant_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AppsPermissionsCubit', () {
    late SharedPreferences sharedPreferences;
    late NostrAppGrantStore grantStore;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      sharedPreferences = await SharedPreferences.getInstance();
      grantStore = NostrAppGrantStore(sharedPreferences: sharedPreferences);
      await grantStore.saveGrant(
        userPubkey: 'f' * 64,
        appId: 'primal-app',
        origin: 'https://primal.net',
        capability: 'signEvent:1',
      );
    });

    blocTest<AppsPermissionsCubit, AppsPermissionsState>(
      'loads grants for the current user and revokes a selected grant',
      build: () => AppsPermissionsCubit(
        grantStore: grantStore,
        currentUserPubkey: 'f' * 64,
      ),
      act: (cubit) async {
        await cubit.load();
        await cubit.revokeGrant(cubit.state.grants.single);
      },
      expect: () => [
        isA<AppsPermissionsState>()
            .having(
              (state) => state.status,
              'status',
              AppsPermissionsStatus.loading,
            )
            .having((state) => state.grants, 'grants', isEmpty),
        isA<AppsPermissionsState>()
            .having(
              (state) => state.status,
              'status',
              AppsPermissionsStatus.loaded,
            )
            .having(
              (state) => state.grants.single.appId,
              'app id',
              'primal-app',
            ),
        isA<AppsPermissionsState>()
            .having(
              (state) => state.status,
              'status',
              AppsPermissionsStatus.loaded,
            )
            .having((state) => state.grants, 'grants', isEmpty),
      ],
    );
  });
}
