// ABOUTME: Service for loading seed data into database on first launch.
// ABOUTME: Reads a bundled JSON manifest and issues parameterized INSERTs.

import 'dart:convert';

import 'package:db_client/db_client.dart';
import 'package:drift/drift.dart' show Batch;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:openvine/services/classic_viner_seed_preload_service.dart';
import 'package:unified_logger/unified_logger.dart';

class SeedDataPreloadService {
  static const String _seedAsset = 'assets/seed_data/seed_events.json';

  /// Load seed data if database is empty.
  ///
  /// One-time operation on first app launch; no-op when the database
  /// already has events. Errors are logged but non-critical — the app
  /// falls back to relay fetches when seed loading fails.
  static Future<void> loadSeedDataIfNeeded(
    AppDatabase db, {
    ClassicVinerSeedPreloadService? classicVinerService,
  }) async {
    try {
      final count = await db.nostrEventsDao.getEventCount();
      if (count > 0) {
        Log.info(
          '[SEED] Database has $count events, skipping event seed load',
          name: 'SeedDataPreload',
          category: LogCategory.system,
        );
      } else {
        Log.info(
          '[SEED] Database empty, loading seed data...',
          name: 'SeedDataPreload',
          category: LogCategory.system,
        );

        final raw = await rootBundle.loadString(_seedAsset);
        final bundle = await compute(_decodeBundle, raw);
        final events = ((bundle['events'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>();
        final profiles = ((bundle['profiles'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>();
        final metrics = ((bundle['metrics'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>();

        await db.batch((batch) {
          for (final event in events) {
            _insertEvent(batch, event);
          }
          for (final profile in profiles) {
            _insertProfile(batch, profile);
          }
          for (final metric in metrics) {
            _insertMetric(batch, metric);
          }
        });

        final finalCount = await db.nostrEventsDao.getEventCount();
        Log.info(
          '[SEED] ✅ Loaded seed data: $finalCount events',
          name: 'SeedDataPreload',
          category: LogCategory.system,
        );
      }

      final vinerService =
          classicVinerService ?? ClassicVinerSeedPreloadService();
      await vinerService.importProfilesIfNeeded(
        userProfilesDao: db.userProfilesDao,
        profileStatsDao: db.profileStatsDao,
      );
    } catch (e, stack) {
      Log.error(
        '[SEED] ❌ Failed to load seed data (non-critical): $e',
        name: 'SeedDataPreload',
        category: LogCategory.system,
      );
      Log.verbose(
        '[SEED] Stack trace: $stack',
        name: 'SeedDataPreload',
        category: LogCategory.system,
      );
    }
  }

  static Map<String, dynamic> _decodeBundle(String raw) =>
      jsonDecode(raw) as Map<String, dynamic>;

  // Drift encodes DateTime columns as unix seconds by default.
  static int _dateTimeToSql(String iso) =>
      DateTime.parse(iso).millisecondsSinceEpoch ~/ 1000;

  static void _insertEvent(Batch batch, Map<String, dynamic> event) {
    batch.customStatement(
      'INSERT OR IGNORE INTO event '
      '(id, pubkey, created_at, kind, tags, content, sig, sources) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, NULL)',
      [
        event['id'] as String,
        event['pubkey'] as String,
        event['created_at'] as int,
        event['kind'] as int,
        jsonEncode(event['tags']),
        event['content'] as String,
        event['sig'] as String,
      ],
    );
  }

  static void _insertProfile(Batch batch, Map<String, dynamic> profile) {
    batch.customStatement(
      'INSERT OR IGNORE INTO user_profiles '
      '(pubkey, display_name, name, picture, banner, about, website, '
      'nip05, lud16, lud06, raw_data, created_at, event_id, last_fetched) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        profile['pubkey'] as String,
        profile['display_name'] as String?,
        profile['name'] as String?,
        profile['picture'] as String?,
        profile['banner'] as String?,
        profile['about'] as String?,
        profile['website'] as String?,
        profile['nip05'] as String?,
        profile['lud16'] as String?,
        profile['lud06'] as String?,
        profile['raw_data'] as String?,
        _dateTimeToSql(profile['created_at'] as String),
        profile['event_id'] as String,
        _dateTimeToSql(profile['last_fetched'] as String),
      ],
    );
  }

  static void _insertMetric(Batch batch, Map<String, dynamic> metric) {
    batch.customStatement(
      'INSERT OR IGNORE INTO video_metrics '
      '(event_id, loop_count, likes, views, comments, updated_at) '
      'VALUES (?, ?, ?, ?, ?, ?)',
      [
        metric['event_id'] as String,
        metric['loop_count'] as int?,
        metric['likes'] as int?,
        metric['views'] as int?,
        metric['comments'] as int?,
        _dateTimeToSql(metric['updated_at'] as String),
      ],
    );
  }
}
