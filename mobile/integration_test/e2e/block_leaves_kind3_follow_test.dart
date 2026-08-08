// ABOUTME: Repro for #6903 — blocking a followed user leaves them listed as
// ABOUTME: a follow in the public kind-3 contact list. Drives the real
// ABOUTME: FollowRepository + ContentBlocklistRepository over real sockets.
// ABOUTME: Requires: NO Docker stack — the relay runs in-process.

@Tags(['service'])
import 'package:cache_sync/cache_sync.dart';
import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/client_utils/keys.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/nostr.dart';
import 'package:nostr_sdk/relay/relay_base.dart';
import 'package:nostr_sdk/relay/relay_status.dart';
import 'package:nostr_sdk/relay/web_socket_connection_manager.dart';
import 'package:nostr_sdk/signer/local_nostr_signer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../helpers/fake_relay.dart';

/// Sends every socket to the in-process relay, whatever host was asked for.
class _LoopbackFactory implements WebSocketChannelFactory {
  _LoopbackFactory(this.port);

  final int port;

  @override
  WebSocketChannel create(Uri uri) =>
      WebSocketChannel.connect(Uri.parse('ws://127.0.0.1:$port${uri.path}'));
}

/// In-memory [CacheDao] so `FollowRepository`'s cache invalidation has
/// somewhere to go. Without it `CacheSync._dao` is an uninitialised `late`
/// field and `follow()` throws a `LateInitializationError` — an `Error`, so
/// the repository's `on Exception` guard does not catch it.
class _MemoryCacheDao implements CacheDao {
  final Map<String, String> _entries = {};

  @override
  Future<String?> read(String key) async => _entries[key];

  @override
  Future<void> write({
    required String key,
    required String payload,
    Duration? ttl,
  }) async => _entries[key] = payload;

  @override
  Future<void> delete(String key) async => _entries.remove(key);

  @override
  Future<void> deletePrefix(String prefix) async =>
      _entries.removeWhere((key, _) => key.startsWith(prefix));

  @override
  Future<int> totalPayloadBytes() async =>
      _entries.values.fold<int>(0, (sum, v) => sum + v.length);

  @override
  Future<void> evictOldest(int bytesToFree) async {
    // Intentional no-op: a per-test map has no size limit to enforce.
  }
}

/// The `BlockListSigner` the repository needs, backed by a real local key.
class _LocalBlockListSigner implements BlockListSigner {
  _LocalBlockListSigner(this._signer, this._pubkey);

  final LocalNostrSigner _signer;
  final String _pubkey;

  @override
  bool get isAuthenticated => true;

  @override
  Future<Event?> createAndSignEvent({
    required int kind,
    required String content,
    List<List<String>>? tags,
  }) async {
    final event = Event(_pubkey, kind, tags ?? const [], content);
    return _signer.signEvent(event);
  }
}

/// Everything a viewer of the author's follow list would see, in publish
/// order: one entry per kind-3 the relay was handed.
extension on FakeRelay {
  List<Event> get publishedEvents => [
    for (final frame in receivedFrames)
      if (frame.isNotEmpty && frame[0] == 'EVENT' && frame.length >= 2)
        Event.fromJson(frame[1] as Map<String, dynamic>),
  ];

  /// The `p` tags of the newest kind-3 the relay holds — kind 3 is
  /// replaceable, so this is exactly what an external viewer resolves to.
  /// Null when the author has never published one.
  List<String>? get publicFollows {
    final contactLists = publishedEvents.where((e) => e.kind == 3).toList();
    if (contactLists.isEmpty) return null;
    contactLists.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return [
      for (final tag in contactLists.last.tags)
        if (tag.isNotEmpty && tag[0] == 'p' && tag.length > 1) tag[1],
    ];
  }

  List<int> get publishedKinds => [for (final e in publishedEvents) e.kind];

  /// Waits until the relay has recorded [count] events of [kind].
  ///
  /// A publish resolves once the frame is handed to the socket, which is a
  /// tick or two before the relay's listener records it. Asserting on the
  /// relay without this reads a snapshot that is merely early, not wrong.
  Future<void> awaitPublished(int kind, {int count = 1}) async {
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (publishedKinds.where((k) => k == kind).length < count) {
      if (DateTime.now().isAfter(deadline)) {
        throw StateError(
          'relay never received $count event(s) of kind $kind; '
          'saw kinds $publishedKinds',
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const authorKey =
      '06478cf31821ae2643888988c5ce3f31731079dbe6c544f5b4451f3c7ce8979c';
  final authorPubkey = getPublicKey(authorKey);
  const targetKey =
      '50dc4b2e01ef449822e422e8c625ddf7d95dc069c414f06d2450556bf5ba7179';
  final targetPubkey = getPublicKey(targetKey);

  /// The real stack — Nostr → RelayPool → RelayManager → NostrClient — with
  /// every socket landing on [relay], plus the two repositories under test
  /// wired the way `moderation_providers.dart` wires them in the app.
  Future<({FollowRepository follows, ContentBlocklistRepository blocks})>
  buildStack(FakeRelay relay) async {
    await CacheSync.init(dao: _MemoryCacheDao());

    final factory = _LoopbackFactory(relay.port);
    final signer = LocalNostrSigner(authorKey);

    RelayBase gen(String url) =>
        RelayBase(url, RelayStatus(url), channelFactory: factory);
    final nostr = Nostr(signer, [], gen, channelFactory: factory);

    final relayManager = RelayManager(
      config: RelayManagerConfig(
        defaultRelayUrl: relay.url,
        storage: InMemoryRelayStorage(),
        // A relay that drops at teardown would otherwise keep retrying and
        // surface the failure against whichever test runs next.
        autoReconnect: false,
      ),
      relayPool: nostr.relayPool,
    );
    final client = NostrClient.forTesting(
      nostr: nostr,
      relayManager: relayManager,
    );
    addTearDown(nostr.relayPool.removeAll);
    await client.initialize();

    final follows = FollowRepository(
      nostrClient: client,
      // Empty so the repository never dials a real indexer.
      indexerRelayUrls: const [],
    );

    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final blocks = ContentBlocklistRepository(prefs: prefs);
    await blocks.syncBlockListsInBackground(
      client,
      _LocalBlockListSigner(signer, authorPubkey),
      authorPubkey,
    );

    return (follows: follows, blocks: blocks);
  }

  group('#6903 block vs. the public kind-3 follow list', () {
    testWidgets('unfollowing removes the target from the public follow list', (
      tester,
    ) async {
      final relay = await FakeRelay.start();
      addTearDown(relay.stop);
      final stack = await buildStack(relay);

      await stack.follows.follow(targetPubkey);
      await relay.awaitPublished(3);
      expect(
        relay.publicFollows,
        contains(targetPubkey),
        reason: 'positive control: the follow must reach the relay at all',
      );

      await stack.follows.unfollow(targetPubkey);
      await relay.awaitPublished(3, count: 2);

      // This is the control that makes the next test meaningful: the harness
      // can observe a follow list shrinking, so a failure there is the app's
      // behaviour and not a blind spot in how this test reads the relay.
      expect(relay.publicFollows, isNot(contains(targetPubkey)));
    });

    testWidgets('blocking removes the target from the public follow list', (
      tester,
    ) async {
      final relay = await FakeRelay.start();
      addTearDown(relay.stop);
      final stack = await buildStack(relay);

      await stack.follows.follow(targetPubkey);
      await relay.awaitPublished(3);
      expect(relay.publicFollows, contains(targetPubkey));

      // Verbatim the call `conversation_view.dart:105` makes when a user
      // taps ⋯ → Block inside a DM thread.
      await stack.blocks.blockUser(targetPubkey, ourPubkey: authorPubkey);

      // The block itself is durable — it is only the follow list that is
      // left contradicting it. Waiting on the block's own events also proves
      // the relay has caught up, so the follow-list assertion below is not
      // just reading an early snapshot.
      await relay.awaitPublished(10000);
      await relay.awaitPublished(30000);
      expect(stack.blocks.isBlocked(targetPubkey), isTrue);

      expect(
        relay.publicFollows,
        isNot(contains(targetPubkey)),
        reason:
            'a viewer resolving this author still sees the blocked account '
            'listed as a follow (#6903)',
      );
    });
  });
}
