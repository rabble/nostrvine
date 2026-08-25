// ABOUTME: #7318 — an in-flight DM history drain must not outlive the account
// ABOUTME: cleanup that wipes the DM tables and DmSyncState out from under it.

import 'dart:async';

import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/event_kind.dart';
import 'package:nostr_sdk/filter.dart' as nostr_filter;
import 'package:nostr_sdk/signer/local_nostr_signer.dart';
import 'package:openvine/providers/container_swap_host.dart';
import 'package:openvine/providers/device_scope.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/providers/social_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _FakeFilter extends Fake implements nostr_filter.Filter {}

/// The account being switched away from.
const _departingPubkey =
    'a1b2c3d4e5f6789012345678901234567890abcdef1234567890123456789012';
const _departingPrivateKey =
    '0000000000000000000000000000000000000000000000000000000000000001';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(<nostr_filter.Filter>[_FakeFilter()]);
  });

  group('account cleanup vs in-flight DM history drain (#7318)', () {
    late AppDatabase db;
    late SharedPreferences prefs;
    late DeviceScope deviceScope;
    late _MockNostrClient nostrClient;
    late DmRepository repository;

    // Page 2 of the drain parks here so the cleanup runs while the drain is
    // suspended mid-page — the production shape, made deterministic.
    late Completer<void> secondPageStarted;
    late Completer<void> secondPageRelease;

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        // A drain only runs when it has somewhere to start from and is not
        // already marked complete.
        'dm.oldestSyncedAt.$_departingPubkey': 1000000,
        'dm.historyDrainVersion.$_departingPubkey':
            DmSyncState.currentDrainVersion,
      });
      prefs = await SharedPreferences.getInstance();
      db = AppDatabase.test(NativeDatabase.memory());
      deviceScope = DeviceScope(
        database: db,
        sharedPreferences: prefs,
        switchController: AccountSwitchController(),
        appVersion: '1.2.3',
        documentsPath: '/documents',
      );

      nostrClient = _MockNostrClient();
      when(() => nostrClient.connectedRelayCount).thenReturn(1);
      when(() => nostrClient.configuredRelayCount).thenReturn(1);
      when(() => nostrClient.unsubscribe(any())).thenAnswer((_) async {});

      secondPageStarted = Completer<void>();
      secondPageRelease = Completer<void>();
      var pageCalls = 0;
      when(
        () => nostrClient.queryEvents(
          any(),
          subscriptionId: any(named: 'subscriptionId'),
          useCache: any(named: 'useCache'),
          tempRelays: any(named: 'tempRelays'),
        ),
      ).thenAnswer((inv) async {
        final filter =
            (inv.positionalArguments.first as List<nostr_filter.Filter>).single;
        // Neither the own-kind-10050 inbox resolve (#4974) nor the
        // outgoing-NIP-04 recovery pass (#5304) is a history page.
        if (filter.kinds?.contains(EventKind.dmRelaysList) ?? false) {
          return const <Event>[];
        }
        if (filter.authors != null && (filter.p?.isEmpty ?? true)) {
          return const <Event>[];
        }
        pageCalls++;
        if (pageCalls == 2) {
          secondPageStarted.complete();
          await secondPageRelease.future;
        }
        // Kind-5 deletions with no tags exercise the drain's pagination and
        // cursor persistence with no decryption or DAO side effects.
        return pageCalls <= 3
            ? [
                Event(
                  _departingPubkey,
                  EventKind.eventDeletion,
                  const <List<String>>[],
                  '',
                  createdAt: filter.until! - 1,
                ),
              ]
            : const <Event>[];
      });

      repository = DmRepository(
        nostrClient: nostrClient,
        directMessagesDao: db.directMessagesDao,
        conversationsDao: db.conversationsDao,
        pendingGiftWrapsDao: db.pendingGiftWrapsDao,
        processedGiftWrapsDao: db.processedGiftWrapsDao,
        syncState: DmSyncState(prefs),
        userPubkey: _departingPubkey,
        signer: LocalNostrSigner(_departingPrivateKey),
      );
    });

    tearDown(() async {
      await repository.stopListening();
      await db.close();
    });

    test(
      'a drain started before an account switch does not re-seed DmSyncState '
      'after the incoming container has wiped it',
      () async {
        // The outgoing account's container, holding the live repository.
        // swapAccount() disposes this one only AFTER signing in on the
        // incoming container, so it is still alive during the cleanup below.
        final departing = buildAccountContainer(
          deviceScope,
          accountOverrides: [
            // overrideWith rather than overrideWithValue so the container keeps
            // the real disposal wiring from repository_providers.dart — a fix
            // that disposes the outgoing container before the wipe must be
            // able to turn this test green.
            dmRepositoryProvider.overrideWith((ref) {
              ref.onDispose(repository.stopListening);
              return repository;
            }),
            openVineImageCacheClearProvider.overrideWithValue(() async {}),
          ],
        );
        addTearDown(departing.dispose);
        expect(departing.read(dmRepositoryProvider), same(repository));

        final drain = repository.backfillHistoryIfNeeded();
        await secondPageStarted.future;
        expect(
          prefs.getInt('dm.historyDrainCursor.$_departingPubkey'),
          isNotNull,
          reason: 'the drain should have persisted page 1s cursor by now',
        );

        // The incoming account's container runs the identity-change cleanup
        // (AuthService._setupUserSession → clearUserSpecificData), sharing the
        // same DeviceScope database and SharedPreferences.
        final arriving = buildAccountContainer(
          deviceScope,
          accountOverrides: [
            openVineImageCacheClearProvider.overrideWithValue(() async {}),
          ],
        );
        addTearDown(arriving.dispose);
        final service = arriving.read(userDataCleanupServiceProvider);
        expect(service.onDatabaseCleanup, isNotNull);
        await service.onDatabaseCleanup!(userPubkey: _departingPubkey);

        secondPageRelease.complete();
        await drain;

        // DmSyncState.clearAll() removed every dm.* key for this pubkey. Any
        // that came back was written by the departing account's drain after
        // the wipe. Asserting on the whole key set rather than one key keeps
        // the check honest: markHistoryDrainComplete() clears the cursor as a
        // side effect, so a cursor-only assertion passes even when the drain
        // ran on to completion.
        expect(
          prefs
              .getKeys()
              .where(
                (key) =>
                    key.startsWith('dm.') && key.endsWith(_departingPubkey),
              )
              .toList(),
          isEmpty,
          reason:
              "the departing account's drain wrote DM sync state back after "
              'the switch cleanup had wiped it',
        );
      },
    );
  });
}
