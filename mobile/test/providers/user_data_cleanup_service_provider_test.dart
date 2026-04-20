// ABOUTME: Tests that userDataCleanupServiceProvider clears every per-user
// ABOUTME: Drift table on signOut while leaving shared caches intact (#2999).

import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeDmRepository extends Mock implements DmRepository {}

void main() {
  // 64-char hex pubkey used to own the seeded per-user rows.
  const ownerPubkey =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
  const otherPubkey =
      'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210';

  group('userDataCleanupServiceProvider onDatabaseCleanup (#2999)', () {
    late AppDatabase database;
    late SharedPreferences prefs;
    late _FakeDmRepository dmRepository;

    setUp(() async {
      database = AppDatabase.test(NativeDatabase.memory());

      SharedPreferences.setMockInitialValues(<String, Object>{});
      prefs = await SharedPreferences.getInstance();

      dmRepository = _FakeDmRepository();
      when(() => dmRepository.stopListening()).thenAnswer((_) async {});
    });

    tearDown(() async {
      await database.close();
    });

    ProviderContainer createContainer() {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(database),
          sharedPreferencesProvider.overrideWithValue(prefs),
          dmRepositoryProvider.overrideWithValue(dmRepository),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    Future<void> seedPerUserRows() async {
      // DMs & conversations — existing cleanup path.
      await database
          .into(database.directMessages)
          .insert(
            DirectMessagesCompanion.insert(
              id: 'dm-1',
              conversationId: 'conv-1',
              senderPubkey: ownerPubkey,
              content: 'hello',
              createdAt: 1,
              giftWrapId: 'gw-1',
            ),
          );
      await database
          .into(database.conversations)
          .insert(
            ConversationsCompanion.insert(
              id: 'conv-1',
              participantPubkeys: '["$ownerPubkey"]',
              createdAt: 1,
            ),
          );
      await database
          .into(database.notifications)
          .insert(
            NotificationsCompanion.insert(
              id: 'notif-1',
              type: 'like',
              fromPubkey: otherPubkey,
              timestamp: 1,
              cachedAt: DateTime.utc(2026),
            ),
          );

      // Authoring surfaces (leaked before #2999 fix).
      await database
          .into(database.drafts)
          .insert(
            DraftsCompanion.insert(
              id: 'draft-1',
              createdAt: DateTime.utc(2026),
              lastModified: DateTime.utc(2026),
              data: '{}',
              ownerPubkey: const Value(ownerPubkey),
            ),
          );
      await database
          .into(database.clips)
          .insert(
            ClipsCompanion.insert(
              id: 'clip-1',
              durationMs: 1000,
              recordedAt: DateTime.utc(2026),
              data: '{}',
              ownerPubkey: const Value(ownerPubkey),
            ),
          );
      await database
          .into(database.pendingUploads)
          .insert(
            PendingUploadsCompanion.insert(
              id: 'upload-1',
              localVideoPath: '/tmp/x.mp4',
              nostrPubkey: ownerPubkey,
              status: 'pending',
              createdAt: DateTime.utc(2026),
            ),
          );

      // Personal engagement & offline queue (leaked before #2999 fix).
      await database
          .into(database.personalReactions)
          .insert(
            PersonalReactionsCompanion.insert(
              targetEventId:
                  'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
              reactionEventId:
                  'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
              userPubkey: ownerPubkey,
              createdAt: 1,
            ),
          );
      await database
          .into(database.personalReposts)
          .insert(
            PersonalRepostsCompanion.insert(
              addressableId: '34236:$otherPubkey:vine-1',
              repostEventId:
                  'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
              originalAuthorPubkey: otherPubkey,
              userPubkey: ownerPubkey,
              createdAt: 1,
            ),
          );
      await database
          .into(database.pendingActions)
          .insert(
            PendingActionsCompanion.insert(
              id: 'action-1',
              type: 'like',
              targetId:
                  'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
              status: 'pending',
              userPubkey: ownerPubkey,
              createdAt: DateTime.utc(2026),
            ),
          );
    }

    Future<void> seedSharedRows() async {
      // Shared across users — MUST survive signOut.
      await database
          .into(database.nostrEvents)
          .insert(
            NostrEventsCompanion.insert(
              id: 'event-1',
              pubkey: otherPubkey,
              createdAt: 1,
              kind: 34236,
              tags: '[]',
              content: 'video',
              sig: 'sig',
            ),
          );
      await database
          .into(database.userProfiles)
          .insert(
            UserProfilesCompanion.insert(
              pubkey: otherPubkey,
              createdAt: DateTime.utc(2026),
              eventId: 'event-profile',
              lastFetched: DateTime.utc(2026),
            ),
          );
      await database
          .into(database.videoMetrics)
          .insert(
            VideoMetricsCompanion.insert(
              eventId: 'event-1',
              updatedAt: DateTime.utc(2026),
            ),
          );
      await database
          .into(database.profileStats)
          .insert(
            ProfileStatsCompanion.insert(
              pubkey: otherPubkey,
              cachedAt: DateTime.utc(2026),
            ),
          );
      await database
          .into(database.hashtagStats)
          .insert(
            HashtagStatsCompanion.insert(
              hashtag: 'flutter',
              cachedAt: DateTime.utc(2026),
            ),
          );
      await database
          .into(database.nip05Verifications)
          .insert(
            Nip05VerificationsCompanion.insert(
              pubkey: otherPubkey,
              nip05: 'alice@example.com',
              status: 'verified',
              verifiedAt: DateTime.utc(2026),
              expiresAt: DateTime.utc(2026, 1, 2),
            ),
          );
    }

    Future<int> countRows(String tableName) async {
      final row = await database
          .customSelect('SELECT COUNT(*) AS c FROM $tableName')
          .getSingle();
      return row.read<int>('c');
    }

    test('clears every per-user table on signOut', () async {
      await seedPerUserRows();
      await seedSharedRows();

      final container = createContainer();
      final service = container.read(userDataCleanupServiceProvider);

      await service.clearUserSpecificData(reason: 'test_explicit_logout');

      expect(await countRows('direct_messages'), equals(0));
      expect(await countRows('conversations'), equals(0));
      expect(await countRows('notifications'), equals(0));
      expect(await countRows('drafts'), equals(0));
      expect(await countRows('clips'), equals(0));
      expect(await countRows('pending_uploads'), equals(0));
      expect(await countRows('personal_reactions'), equals(0));
      expect(await countRows('personal_reposts'), equals(0));
      expect(await countRows('pending_actions'), equals(0));
    });

    test('leaves shared-across-users tables untouched', () async {
      await seedPerUserRows();
      await seedSharedRows();

      final container = createContainer();
      final service = container.read(userDataCleanupServiceProvider);

      await service.clearUserSpecificData(reason: 'test_explicit_logout');

      expect(await countRows('event'), equals(1));
      expect(await countRows('user_profiles'), equals(1));
      expect(await countRows('video_metrics'), equals(1));
      expect(await countRows('profile_statistics'), equals(1));
      expect(await countRows('hashtag_stats'), equals(1));
      expect(await countRows('nip05_verifications'), equals(1));
    });

    test('stops the DM listener before clearing tables', () async {
      await seedPerUserRows();

      final container = createContainer();
      final service = container.read(userDataCleanupServiceProvider);

      await service.clearUserSpecificData(reason: 'test_explicit_logout');

      verify(() => dmRepository.stopListening()).called(1);
    });
  });
}
