// ABOUTME: Tests for SeedDataPreloadService seed data loading
// ABOUTME: Verifies JSON loading and parameterized round-trip for tricky input

import 'dart:convert';
import 'dart:io';

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/services/classic_viner_seed_preload_service.dart';
import 'package:openvine/services/seed_data_preload_service.dart';

class _TrackingClassicVinerService extends ClassicVinerSeedPreloadService {
  _TrackingClassicVinerService({required super.markerDirectoryProvider});

  bool importProfilesCalled = false;

  @override
  Future<void> importProfilesIfNeeded({
    required UserProfilesDao userProfilesDao,
    required ProfileStatsDao profileStatsDao,
  }) async {
    importProfilesCalled = true;
  }
}

/// Wires up a mock handler so [rootBundle.loadString] returns [payload] for
/// the seed asset path.
void _mockSeedAsset(String payload) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler('flutter/assets', (ByteData? message) async {
        if (message == null) return null;
        final assetName = utf8.decode(message.buffer.asUint8List());
        if (assetName == 'assets/seed_data/seed_events.json') {
          final bytes = Uint8List.fromList(utf8.encode(payload));
          return ByteData.sublistView(bytes);
        }
        return null;
      });
}

String _encodeBundle({
  List<Map<String, dynamic>> events = const [],
  List<Map<String, dynamic>> profiles = const [],
  List<Map<String, dynamic>> metrics = const [],
}) {
  return jsonEncode({
    'meta': {'events': events.length},
    'events': events,
    'profiles': profiles,
    'metrics': metrics,
  });
}

Map<String, dynamic> _eventFixture({
  required String id,
  required List<dynamic> tags,
  String content = 'Seed video',
}) {
  return {
    'id': id,
    'pubkey':
        'c0ffee1234567890abcdef1234567890abcdef1234567890abcdef1234567890',
    'created_at': 1234567890,
    'kind': 34236,
    'tags': tags,
    'content': content,
    'sig':
        'abc1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcd'
        'ef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcd',
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SeedDataPreloadService', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.test(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
      rootBundle.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', null);
    });

    test('skips load when database already has events', () async {
      final event = Event(
        '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
        34236,
        [],
        'Existing video',
        createdAt: 1234567890,
      );
      event.id =
          'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2';
      event.sig =
          'abc1234567890abcdef1234567890abcdef1234567890abcdef1234567890abc'
          'def1234567890abcdef1234567890abcdef1234567890abcdef123456789';

      await db.nostrEventsDao.upsertEvent(event);

      await SeedDataPreloadService.loadSeedDataIfNeeded(db);

      final count = await db.nostrEventsDao.getEventCount();
      expect(count, equals(1));
    });

    test('loads seed events when database is empty', () async {
      _mockSeedAsset(
        _encodeBundle(
          events: [
            _eventFixture(
              id:
                  '5eed1234567890abcdef1234567890abcdef1234567890ab'
                  'cdef1234567890abcd',
              tags: const [
                ['d', 'abc123'],
              ],
            ),
            _eventFixture(
              id:
                  '5eed2234567890abcdef1234567890abcdef1234567890ab'
                  'cdef1234567890abcd',
              tags: const [],
              content: '{"name":"Alice"}',
            ),
          ],
        ),
      );

      expect(await db.nostrEventsDao.getEventCount(), equals(0));

      await SeedDataPreloadService.loadSeedDataIfNeeded(db);

      final count = await db.nostrEventsDao.getEventCount();
      expect(count, equals(2));
    });

    test('round-trips tag JSON containing a semicolon', () async {
      // This is the bug in #3093: the old loader split on every `;`, which
      // tore INSERT statements apart when an author name like "ig; phaxn"
      // contained a semicolon inside its string literal.
      const id =
          '5e0c01017890abcdef1234567890abcdef1234567890abcdef1234567890abcd';
      _mockSeedAsset(
        _encodeBundle(
          events: [
            _eventFixture(
              id: id,
              tags: const [
                ['author', 'ig; phaxn'],
                ['title', 'hotter than the sun'],
              ],
            ),
          ],
        ),
      );

      await SeedDataPreloadService.loadSeedDataIfNeeded(db);

      expect(await db.nostrEventsDao.getEventCount(), equals(1));
      final row = await db.nostrEventsDao.getEventById(id);
      expect(row, isNotNull);
      expect(
        row!.tags,
        anyElement(equals(['author', 'ig; phaxn'])),
      );
    });

    test('round-trips content with single quotes', () async {
      const id =
          'a0057007890abcdef1234567890abcdef1234567890abcdef1234567890abcd12';
      _mockSeedAsset(
        _encodeBundle(
          events: [
            _eventFixture(
              id: id,
              tags: const [
                ['title', "When you're finally brave enough"],
              ],
              content: "She's out of her mind",
            ),
          ],
        ),
      );

      await SeedDataPreloadService.loadSeedDataIfNeeded(db);

      final row = await db.nostrEventsDao.getEventById(id);
      expect(row, isNotNull);
      expect(row!.content, equals("She's out of her mind"));
      expect(row.tags.first[1], equals("When you're finally brave enough"));
    });

    test('round-trips content with brackets and backslashes', () async {
      const id =
          'b7ac7e157890abcdef1234567890abcdef1234567890abcdef1234567890abcd';
      const trickyContent = r'Look at [this] \and\ "that"';
      _mockSeedAsset(
        _encodeBundle(
          events: [
            _eventFixture(
              id: id,
              tags: const [
                ['title', '[fixed]'],
              ],
              content: trickyContent,
            ),
          ],
        ),
      );

      await SeedDataPreloadService.loadSeedDataIfNeeded(db);

      final row = await db.nostrEventsDao.getEventById(id);
      expect(row, isNotNull);
      expect(row!.content, equals(trickyContent));
    });

    test('handles missing asset gracefully', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', (ByteData? message) async {
            return null;
          });

      await expectLater(
        SeedDataPreloadService.loadSeedDataIfNeeded(db),
        completes,
      );

      expect(await db.nostrEventsDao.getEventCount(), equals(0));
    });

    test('handles malformed JSON gracefully', () async {
      _mockSeedAsset('{not json at all');

      await expectLater(
        SeedDataPreloadService.loadSeedDataIfNeeded(db),
        completes,
      );

      expect(await db.nostrEventsDao.getEventCount(), equals(0));
    });

    test('calls injected ClassicVinerSeedPreloadService', () async {
      final markerDir = Directory.systemTemp.createTempSync(
        'seed_data_viner_di_test_',
      );
      addTearDown(() async {
        if (markerDir.existsSync()) {
          await markerDir.delete(recursive: true);
        }
      });

      final trackingService = _TrackingClassicVinerService(
        markerDirectoryProvider: () async => markerDir,
      );

      final event = Event(
        '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
        34236,
        [],
        'Existing video',
        createdAt: 1234567890,
      );
      event.id =
          'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2';
      event.sig =
          'abc1234567890abcdef1234567890abcdef1234567890abcdef1234567890abc'
          'def1234567890abcdef1234567890abcdef1234567890abcdef123456789';
      await db.nostrEventsDao.upsertEvent(event);

      await SeedDataPreloadService.loadSeedDataIfNeeded(
        db,
        classicVinerService: trackingService,
      );

      expect(trackingService.importProfilesCalled, isTrue);
    });
  });
}
