// ABOUTME: Regression tests for purging NIP-09 deleted videos from the local
// ABOUTME: event store, so a restart's cache-first load cannot resurface them.

import 'dart:async';
import 'dart:io';

import 'package:db_client/db_client.dart' hide Filter;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/services/event_router.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:path/path.dart' as p;

/// Emits events on demand so a deletion can be delivered after the video.
class _StreamingNostrService implements NostrClient {
  final StreamController<Event> _events = StreamController<Event>.broadcast();

  @override
  bool get isInitialized => true;

  @override
  int get connectedRelayCount => 1;

  @override
  Stream<Event> subscribe(
    List<Filter> filters, {
    String? subscriptionId,
    List<String>? tempRelays,
    List<String>? targetRelays,
    List<int> relayTypes = const [],
    bool sendAfterAuth = false,
    void Function()? onEose,
  }) {
    if (onEose != null) {
      Future.microtask(onEose);
    }
    return _events.stream;
  }

  void emit(Event event) => _events.add(event);

  @override
  Future<void> dispose() async => _events.close();

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

const _authorPubkey =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _videoId =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _deletionId =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
const _sig =
    'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd'
    'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';

Event _videoEvent() =>
    Event(
        _authorPubkey,
        34236,
        [
          ['d', 'clip-1'],
          ['url', 'https://example.com/video.mp4'],
          ['title', 'Deleted clip'],
        ],
        'a video that gets deleted',
        createdAt: 1000,
      )
      ..id = _videoId
      ..sig = _sig;

Event _deletionEvent() =>
    Event(
        _authorPubkey,
        5,
        [
          ['e', _videoId],
        ],
        'deleted by author',
        createdAt: 2000,
      )
      ..id = _deletionId
      ..sig = _sig;

void main() {
  group('VideoEventService NIP-09 local cache purge', () {
    late AppDatabase db;
    late String dbPath;
    late Directory tempDir;
    late EventRouter eventRouter;
    late _StreamingNostrService nostrService;
    late VideoEventService service;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('openvine_purge_test_');
      dbPath = p.join(tempDir.path, 'test.db');
      db = AppDatabase.test(NativeDatabase(File(dbPath)));
      eventRouter = EventRouter(
        db,
        config: const EventRouterConfig(autoStart: false),
      );
      nostrService = _StreamingNostrService();
      service = VideoEventService(
        nostrService,
        subscriptionManager: SubscriptionManager(nostrService),
        eventRouter: eventRouter,
      );
    });

    tearDown(() async {
      service.dispose();
      await db.close();
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    /// Lets the broadcast stream forward pending events into the router, then
    /// persists them. Replaces wall-clock waits.
    Future<void> settle() async {
      await pumpEventQueue();
      await eventRouter.drainForTesting();
    }

    Future<int> cachedVideoRowCount() async {
      final rows = await db.nostrEventsDao.getEventsByFilter(
        Filter(kinds: const [34236], authors: const [_authorPubkey]),
      );
      return rows.length;
    }

    test('deletes the target event row from the local store', () async {
      await service.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.discovery,
      );
      nostrService.emit(_videoEvent());
      await settle();
      expect(
        await cachedVideoRowCount(),
        1,
        reason: 'the video should be cached before the deletion arrives',
      );

      nostrService.emit(_deletionEvent());
      await settle();

      expect(await cachedVideoRowCount(), 0);
    });

    test('the cache-first read does not write the row back', () async {
      // A row already in the store, as after a restart.
      await db.nostrEventsDao.upsertEvent(_videoEvent());
      expect(await cachedVideoRowCount(), 1);

      // Cache-first picks it up and hands it to the same handler the relay
      // path uses. Deliberately no drain here: that write-back is what used to
      // land after the purge and resurrect the row on every single launch.
      await service.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.discovery,
        authors: const [_authorPubkey],
      );

      nostrService.emit(_deletionEvent());
      await pumpEventQueue();
      await pumpEventQueue();
      await eventRouter.drainForTesting();

      expect(await cachedVideoRowCount(), 0);
    });

    test('deletes the row on a locally initiated delete too', () async {
      await service.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.discovery,
      );
      nostrService.emit(_videoEvent());
      await settle();
      expect(await cachedVideoRowCount(), 1);

      service.removeVideoCompletely(_videoId);
      await pumpEventQueue();

      expect(await cachedVideoRowCount(), 0);
    });
  });
}
