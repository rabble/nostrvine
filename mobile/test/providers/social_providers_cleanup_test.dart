// ABOUTME: Regression tests for account cleanup provider wiring.
// ABOUTME: Ensures destructive cleanup reaches the live Hive upload store.

import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' as model;
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/social_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_helpers.dart';

class _MockDmRepository extends Mock implements DmRepository {}

const _pubkeyA =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _pubkeyB =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

void main() {
  group(userDataCleanupServiceProvider, () {
    late AppDatabase db;
    late SharedPreferences prefs;
    late _MockDmRepository dmRepository;
    late List<String> purgedUploadOwners;
    late ProviderContainer container;

    setUpAll(() async {
      await initializeServiceTestEnvironment();
    });

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      db = AppDatabase.test(NativeDatabase.memory());
      dmRepository = _MockDmRepository();
      purgedUploadOwners = [];
      when(() => dmRepository.stopListening()).thenAnswer((_) async {});

      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          dmRepositoryProvider.overrideWithValue(dmRepository),
          pendingUploadOwnerCleanupProvider.overrideWithValue((ownerPubkey) {
            purgedUploadOwners.add(ownerPubkey);
            return Future.value(1);
          }),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test(
      'destructive cleanup purges Hive uploads for the departing user',
      () async {
        await db.pendingUploadsDao.upsertUpload(
          model.PendingUpload.create(
            localVideoPath: '/tmp/a.mp4',
            nostrPubkey: _pubkeyA,
          ),
        );
        await db.pendingUploadsDao.upsertUpload(
          model.PendingUpload.create(
            localVideoPath: '/tmp/b.mp4',
            nostrPubkey: _pubkeyB,
          ),
        );

        final subscription = container.listen(
          userDataCleanupServiceProvider,
          (_, _) {},
        );
        addTearDown(subscription.close);
        final service = subscription.read();

        expect(service.onDatabaseCleanup, isNotNull);
        await service.onDatabaseCleanup!(
          userPubkey: _pubkeyA,
          deleteUserData: true,
        );

        expect(
          await db.pendingUploadsDao.getAllUploads(ownerPubkey: _pubkeyA),
          isEmpty,
        );
        final remainingDriftUploads = await db.pendingUploadsDao.getAllUploads(
          ownerPubkey: _pubkeyB,
        );
        expect(remainingDriftUploads, hasLength(1));
        expect(purgedUploadOwners, [_pubkeyA]);
      },
    );

    test('non-destructive cleanup preserves pending uploads', () async {
      final subscription = container.listen(
        userDataCleanupServiceProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      final service = subscription.read();

      expect(service.onDatabaseCleanup, isNotNull);
      await service.onDatabaseCleanup!(
        userPubkey: _pubkeyA,
      );

      expect(purgedUploadOwners, isEmpty);
    });
  });
}
