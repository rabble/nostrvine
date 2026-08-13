// ABOUTME: Regression tests for the #6903 blocked-follow reconciler provider.
// ABOUTME: Blocking must republish kind 3 without the blocked account.

import 'dart:async';

import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/providers/moderation_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockFollowRepository extends Mock implements FollowRepository {}

void main() {
  const ourPubkey =
      '0edc2f474484769bc9bf6d471d180e4e280b0bcd719b6da791001beb730cff1b';
  const otherAccount =
      '00000000000000000000000000000000000000000000000000000000000000aa';
  const blockedFollow =
      'b2c3d4e5f6789012345678901234567890abcdef1234567890123456789012a1';
  const otherFollow =
      'c3d4e5f6789012345678901234567890abcdef1234567890123456789012ab12';

  late _MockNostrClient nostrClient;
  late _MockFollowRepository followRepository;
  late ContentBlocklistRepository blocklistRepository;
  late StreamController<List<String>> followingController;
  late List<String> followingPubkeys;

  Future<ProviderContainer> createContainer({
    String signingPubkey = ourPubkey,
  }) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();

    nostrClient = _MockNostrClient();
    when(() => nostrClient.publicKey).thenReturn(signingPubkey);
    when(
      () => nostrClient.subscribe(any()),
    ).thenAnswer((_) => const Stream<Event>.empty());

    followRepository = _MockFollowRepository();
    when(
      () => followRepository.followingPubkeys,
    ).thenAnswer((_) => followingPubkeys);
    when(
      () => followRepository.followingStream,
    ).thenAnswer((_) => followingController.stream);
    when(
      () => followRepository.republishContactList(),
    ).thenAnswer((_) async {});

    blocklistRepository = ContentBlocklistRepository(prefs: prefs);
    // Adopting the identity is what scopes the persisted blocks to an
    // account; blockedPubkeysForAccount withholds everything until it runs.
    await blocklistRepository.syncMuteListsInBackground(nostrClient, ourPubkey);

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        nostrServiceProvider.overrideWithValue(nostrClient),
        followRepositoryProvider.overrideWithValue(followRepository),
        contentBlocklistRepositoryProvider.overrideWithValue(
          blocklistRepository,
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  setUp(() {
    followingPubkeys = <String>[];
    followingController = StreamController<List<String>>.broadcast();
  });

  tearDown(() async {
    await followingController.close();
  });

  group('blockedFollowReconcilerProvider', () {
    test('republishes when a followed account is blocked', () async {
      followingPubkeys = <String>[blockedFollow, otherFollow];
      final container = await createContainer();
      container.read(blockedFollowReconcilerProvider);

      await blocklistRepository.blockUser(blockedFollow, ourPubkey: ourPubkey);
      await Future<void>.delayed(Duration.zero);

      verify(() => followRepository.republishContactList()).called(1);
    });

    test(
      'does not republish when the blocked account is not followed',
      () async {
        followingPubkeys = <String>[otherFollow];
        final container = await createContainer();
        container.read(blockedFollowReconcilerProvider);

        await blocklistRepository.blockUser(
          blockedFollow,
          ourPubkey: ourPubkey,
        );
        await Future<void>.delayed(Duration.zero);

        verifyNever(() => followRepository.republishContactList());
      },
    );

    // The defect this exists for: blocking before the follow list has
    // finished loading — a fresh install, a new sign-in, a cleared cache —
    // leaves nothing to reconcile at block time. The list arriving later is
    // the second chance.
    test('heals a block made before the follow list loaded', () async {
      final container = await createContainer();
      container.read(blockedFollowReconcilerProvider);

      await blocklistRepository.blockUser(blockedFollow, ourPubkey: ourPubkey);
      await Future<void>.delayed(Duration.zero);
      verifyNever(() => followRepository.republishContactList());

      followingPubkeys = <String>[blockedFollow, otherFollow];
      followingController.add(followingPubkeys);
      await Future<void>.delayed(Duration.zero);

      verify(() => followRepository.republishContactList()).called(1);
    });

    // divine-web keeps whichever kind 3 carries more entries
    // (divinevideo/divine-web#551), so it can resurrect the entry we just
    // dropped. Without the bound the two clients trade publishes forever.
    test('republishes at most once per blocked pubkey per session', () async {
      followingPubkeys = <String>[blockedFollow];
      final container = await createContainer();
      container.read(blockedFollowReconcilerProvider);

      await blocklistRepository.blockUser(blockedFollow, ourPubkey: ourPubkey);
      await Future<void>.delayed(Duration.zero);

      followingController.add(followingPubkeys);
      await Future<void>.delayed(Duration.zero);
      followingController.add(followingPubkeys);
      await Future<void>.delayed(Duration.zero);

      verify(() => followRepository.republishContactList()).called(1);
    });

    test('retries on the next trigger when the republish fails', () async {
      followingPubkeys = <String>[blockedFollow];
      final container = await createContainer();
      container.read(blockedFollowReconcilerProvider);

      when(
        () => followRepository.republishContactList(),
      ).thenThrow(Exception('relay unreachable'));
      await blocklistRepository.blockUser(blockedFollow, ourPubkey: ourPubkey);
      await Future<void>.delayed(Duration.zero);

      when(
        () => followRepository.republishContactList(),
      ).thenAnswer((_) async {});
      followingController.add(followingPubkeys);
      await Future<void>.delayed(Duration.zero);

      verify(() => followRepository.republishContactList()).called(2);
    });

    // A keepAlive blocklist can still hold account A's blocks while the
    // session signs as B. Reconciling then would rewrite B's follow list
    // from A's data.
    test('does not republish when the signing account is not the one whose '
        'blocks are loaded', () async {
      followingPubkeys = <String>[blockedFollow];
      final container = await createContainer(signingPubkey: otherAccount);
      container.read(blockedFollowReconcilerProvider);

      await blocklistRepository.blockUser(blockedFollow, ourPubkey: ourPubkey);
      await Future<void>.delayed(Duration.zero);
      followingController.add(followingPubkeys);
      await Future<void>.delayed(Duration.zero);

      verifyNever(() => followRepository.republishContactList());
    });

    test('does not republish on an unblock', () async {
      followingPubkeys = <String>[blockedFollow];
      final container = await createContainer();
      await blocklistRepository.blockUser(blockedFollow, ourPubkey: ourPubkey);
      container.read(blockedFollowReconcilerProvider);

      await blocklistRepository.unblockUser(blockedFollow);
      await Future<void>.delayed(Duration.zero);

      verifyNever(() => followRepository.republishContactList());
    });
  });
}
