// ABOUTME: Regression tests for account cleanup provider wiring.
// ABOUTME: Ensures destructive cleanup reaches the live Hive upload store.

import 'dart:io';

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' as model;
import 'package:openvine/models/pending_upload.dart' as hive_model;
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/social_providers.dart';
import 'package:openvine/providers/upload_media_providers.dart';
import 'package:openvine/services/upload_manager.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_helpers.dart';
import '../mocks/mock_path_provider_platform.dart';

class _MockDmRepository extends Mock implements DmRepository {}

class _MockBlossomUploadService extends Mock implements BlossomUploadService {}

const _pubkeyA =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _pubkeyB =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _reactionIdA =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
const _reactionIdB =
    'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';
const _dmConversationId =
    'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
const _dmTargetMessageId =
    'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';
const _dmSecondTargetMessageId =
    '1111111111111111111111111111111111111111111111111111111111111111';
const _pendingReactionId =
    '2222222222222222222222222222222222222222222222222222222222222222';
const _pendingDeletionId =
    '3333333333333333333333333333333333333333333333333333333333333333';

void main() {
  group(userDataCleanupServiceProvider, () {
    late AppDatabase db;
    late SharedPreferences prefs;
    late _MockDmRepository dmRepository;
    late _MockBlossomUploadService blossomUploadService;
    late UploadManager uploadManager;
    late Directory tempDir;
    late PathProviderPlatform originalPathProviderInstance;
    late ProviderContainer container;

    setUpAll(() async {
      await initializeServiceTestEnvironment();
    });

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      db = AppDatabase.test(NativeDatabase.memory());
      dmRepository = _MockDmRepository();
      blossomUploadService = _MockBlossomUploadService();
      when(() => dmRepository.stopListening()).thenAnswer((_) async {});
      when(
        () => blossomUploadService.isBlossomEnabled(),
      ).thenAnswer((_) async => false);

      tempDir = await Directory.systemTemp.createTemp(
        'social_cleanup_uploads_',
      );
      originalPathProviderInstance = PathProviderPlatform.instance;
      final mockPathProvider = MockPathProviderPlatform()
        ..setTemporaryPath(tempDir.path)
        ..setApplicationDocumentsPath('${tempDir.path}/documents')
        ..setApplicationSupportPath('${tempDir.path}/support')
        ..setApplicationCachePath('${tempDir.path}/cache');
      PathProviderPlatform.instance = mockPathProvider;

      uploadManager = UploadManager(
        blossomService: blossomUploadService,
        currentNostrPubkey: _pubkeyB,
        scopeUploadsToCurrentUser: true,
      );
      await uploadManager.initialize();
      await TestHelpers.ensureBoxEmpty<hive_model.PendingUpload>(
        'pending_uploads',
      );

      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          dmRepositoryProvider.overrideWithValue(dmRepository),
          openVineImageCacheClearProvider.overrideWithValue(() async {}),
          uploadManagerProvider.overrideWithValue(uploadManager),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      uploadManager.dispose();
      await db.close();
      await TestHelpers.cleanupHiveBox('pending_uploads');
      PathProviderPlatform.instance = originalPathProviderInstance;
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
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
        final box = Hive.box<hive_model.PendingUpload>('pending_uploads');
        final a1 = hive_model.PendingUpload.create(
          localVideoPath: '/tmp/a1.mp4',
          nostrPubkey: _pubkeyA,
        );
        final a2 = hive_model.PendingUpload.create(
          localVideoPath: '/tmp/a2.mp4',
          nostrPubkey: _pubkeyA,
        );
        final b1 = hive_model.PendingUpload.create(
          localVideoPath: '/tmp/b1.mp4',
          nostrPubkey: _pubkeyB,
        );
        await box.put(a1.id, a1);
        await box.put(a2.id, a2);
        await box.put(b1.id, b1);

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
        expect(box.get(a1.id), isNull);
        expect(box.get(a2.id), isNull);
        expect(box.get(b1.id), isNotNull);
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

      expect(
        Hive.box<hive_model.PendingUpload>('pending_uploads').values,
        isEmpty,
      );
    });

    Future<void> seedDmReaction({
      required String id,
      required String ownerPubkey,
    }) {
      return db.dmReactionsDao.upsertIncoming(
        id: id,
        conversationId: _dmConversationId,
        targetMessageId: _dmTargetMessageId,
        targetMessageAuthor: _pubkeyB,
        reactorPubkey: _pubkeyB,
        emoji: '😂',
        createdAt: 1_700_000_000,
        giftWrapId: id,
        ownerPubkey: ownerPubkey,
      );
    }

    Future<void> seedPendingOwnReaction({
      required String id,
      required String targetMessageId,
    }) async {
      await db.dmReactionsDao.insertOwnReactionSuperseding(
        placeholderId: id,
        conversationId: _dmConversationId,
        targetMessageId: targetMessageId,
        targetMessageAuthor: _pubkeyB,
        reactorPubkey: _pubkeyA,
        emoji: '😂',
        createdAt: 1_700_000_000,
        ownerPubkey: _pubkeyA,
        rumorEventJson: '{"id":"$id"}',
      );
    }

    Future<void> seedPendingOwnDeletion({
      required String id,
      required String targetMessageId,
    }) async {
      await seedPendingOwnReaction(id: id, targetMessageId: targetMessageId);
      await db.dmReactionsDao.markOwnDeletionPending(
        id: id,
        ownerPubkey: _pubkeyA,
        deletionRumorJson: '{"kind":5}',
      );
    }

    test(
      'destructive cleanup purges dm reactions for the departing user',
      () async {
        await seedDmReaction(id: _reactionIdA, ownerPubkey: _pubkeyA);
        await seedDmReaction(id: _reactionIdB, ownerPubkey: _pubkeyB);
        await seedPendingOwnReaction(
          id: _pendingReactionId,
          targetMessageId: _dmTargetMessageId,
        );
        await seedPendingOwnDeletion(
          id: _pendingDeletionId,
          targetMessageId: _dmSecondTargetMessageId,
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
          await db.dmReactionsDao.getById(
            id: _reactionIdA,
            ownerPubkey: _pubkeyA,
          ),
          isNull,
        );
        expect(
          await db.dmReactionsDao.getById(
            id: _pendingReactionId,
            ownerPubkey: _pubkeyA,
          ),
          isNull,
        );
        expect(
          await db.dmReactionsDao.getById(
            id: _pendingDeletionId,
            ownerPubkey: _pubkeyA,
          ),
          isNull,
        );
        expect(
          await db.dmReactionsDao.getById(
            id: _reactionIdB,
            ownerPubkey: _pubkeyB,
          ),
          isNotNull,
        );
      },
    );

    test(
      'non-destructive cleanup preserves retryable outgoing dm reactions',
      () async {
        await seedDmReaction(id: _reactionIdA, ownerPubkey: _pubkeyA);
        await seedPendingOwnReaction(
          id: _pendingReactionId,
          targetMessageId: _dmTargetMessageId,
        );
        await seedPendingOwnDeletion(
          id: _pendingDeletionId,
          targetMessageId: _dmSecondTargetMessageId,
        );

        final subscription = container.listen(
          userDataCleanupServiceProvider,
          (_, _) {},
        );
        addTearDown(subscription.close);
        final service = subscription.read();

        expect(service.onDatabaseCleanup, isNotNull);
        await service.onDatabaseCleanup!(userPubkey: _pubkeyA);

        expect(
          await db.dmReactionsDao.getById(
            id: _reactionIdA,
            ownerPubkey: _pubkeyA,
          ),
          isNull,
        );
        expect(
          await db.dmReactionsDao.getById(
            id: _pendingReactionId,
            ownerPubkey: _pubkeyA,
          ),
          isNotNull,
        );
        final deletion = await db.dmReactionsDao.getById(
          id: _pendingDeletionId,
          ownerPubkey: _pubkeyA,
        );
        expect(deletion, isNotNull);
        expect(deletion!.publishStatus, equals('deletion_pending'));
      },
    );
  });
}
