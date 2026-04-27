// ABOUTME: Tests the block/mute bus bridge — VideoEventService subscribes to
// ContentBlocklistRepository.changes and emits removedVideoIds for every
// cached video by the affected author when an "addition" event fires.

@Tags(['skip_very_good_optimization'])
import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/services/video_event_service.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockSubscriptionManager extends Mock implements SubscriptionManager {}

VideoEvent _video({required String id, required String pubkey}) {
  final now = DateTime.now();
  return VideoEvent(
    id: id,
    pubkey: pubkey,
    createdAt: now.millisecondsSinceEpoch ~/ 1000,
    content: '',
    timestamp: now,
    title: id,
    videoUrl: 'https://example.com/$id.mp4',
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(<Filter>[]);
  });

  group('VideoEventService blocklist sweep', () {
    late VideoEventService service;
    late ContentBlocklistRepository blocklistRepo;
    late _MockNostrClient nostrClient;
    late _MockSubscriptionManager subscriptionManager;

    setUp(() {
      nostrClient = _MockNostrClient();
      subscriptionManager = _MockSubscriptionManager();
      when(() => nostrClient.isInitialized).thenReturn(true);
      when(() => nostrClient.connectedRelayCount).thenReturn(1);
      when(
        () => nostrClient.subscribe(any()),
      ).thenAnswer((_) => const Stream<Event>.empty());

      service = VideoEventService(
        nostrClient,
        subscriptionManager: subscriptionManager,
      );
      // No prefs — in-memory blocklist for the test.
      blocklistRepo = ContentBlocklistRepository();
      service.setBlocklistRepository(blocklistRepo);
    });

    tearDown(() {
      service.dispose();
      blocklistRepo.dispose();
    });

    test(
      'blockUser triggers a sweep — removedVideoIds emits every cached id '
      'for the blocked author',
      () async {
        const author = 'author-pubkey';
        service.debugSeedAuthorBucket(author, [
          _video(id: 'v1', pubkey: author),
          _video(id: 'v2', pubkey: author),
          _video(id: 'v3', pubkey: author),
        ]);

        final emitted = <String>[];
        final sub = service.removedVideoIds.listen(emitted.add);
        addTearDown(sub.cancel);

        await blocklistRepo.blockUser(author);
        await Future<void>.delayed(Duration.zero);

        expect(emitted, containsAll(['v1', 'v2', 'v3']));
        expect(emitted.length, 3);
      },
    );

    test('unblockUser does NOT trigger a sweep (no-op for removals)', () async {
      const author = 'author-pubkey';
      await blocklistRepo.blockUser(author); // pre-block so unblock fires
      service.debugSeedAuthorBucket(author, [
        _video(id: 'v1', pubkey: author),
      ]);

      // Listener after pre-block so the initial blocked emit isn't counted.
      final emitted = <String>[];
      final sub = service.removedVideoIds.listen(emitted.add);
      addTearDown(sub.cancel);

      await blocklistRepo.unblockUser(author);
      await Future<void>.delayed(Duration.zero);

      expect(emitted, isEmpty);
    });

    test(
      'sweep does NOT add ids to _locallyDeletedVideoIds (block is reversible)',
      () async {
        const author = 'author-pubkey';
        service.debugSeedAuthorBucket(author, [
          _video(id: 'v1', pubkey: author),
        ]);

        await blocklistRepo.blockUser(author);
        await Future<void>.delayed(Duration.zero);

        // The session-tombstone set is reserved for irrevocable
        // user-initiated deletions. Unblocking should restore visibility,
        // which would be impossible if we polluted the tombstone set.
        expect(service.isVideoLocallyDeleted('v1'), isFalse);
      },
    );

    test('block on author with no cached videos is a silent no-op', () async {
      final emitted = <String>[];
      final sub = service.removedVideoIds.listen(emitted.add);
      addTearDown(sub.cancel);

      await blocklistRepo.blockUser('unknown-author');
      await Future<void>.delayed(Duration.zero);

      expect(emitted, isEmpty);
    });

    test(
      're-blocking the same author is dedupe at the repository level — no '
      'duplicate sweep',
      () async {
        const author = 'author-pubkey';
        service.debugSeedAuthorBucket(author, [
          _video(id: 'v1', pubkey: author),
        ]);

        await blocklistRepo.blockUser(author);
        await Future<void>.delayed(Duration.zero);

        final emitted = <String>[];
        final sub = service.removedVideoIds.listen(emitted.add);
        addTearDown(sub.cancel);

        await blocklistRepo.blockUser(author); // already blocked → no-op
        await Future<void>.delayed(Duration.zero);

        expect(emitted, isEmpty);
      },
    );

    test(
      'dispose cancels the blocklist subscription (further repo emits are '
      'ignored without errors)',
      () async {
        // Build a separate service so the global tearDown does not double-
        // dispose. Pre-existing helpers (`service`, `blocklistRepo`) stay
        // owned by the outer setUp/tearDown.
        final localNostr = _MockNostrClient();
        when(() => localNostr.isInitialized).thenReturn(true);
        when(() => localNostr.connectedRelayCount).thenReturn(1);
        when(
          () => localNostr.subscribe(any()),
        ).thenAnswer((_) => const Stream<Event>.empty());
        final localService = VideoEventService(
          localNostr,
          subscriptionManager: subscriptionManager,
        );
        final localRepo = ContentBlocklistRepository();
        addTearDown(localRepo.dispose);

        localService.setBlocklistRepository(localRepo);
        const author = 'author-pubkey';
        localService.debugSeedAuthorBucket(author, [
          _video(id: 'v1', pubkey: author),
        ]);

        final emitted = <String>[];
        final sub = localService.removedVideoIds.listen(
          emitted.add,
          onError: (Object _) {},
        );
        addTearDown(sub.cancel);

        localService.dispose();

        // Repo is still live; emit a Blocked. The cancelled subscription
        // means the bus does not see this event.
        await localRepo.blockUser(author);
        await Future<void>.delayed(Duration.zero);

        expect(emitted, isEmpty);
      },
    );
  });
}
