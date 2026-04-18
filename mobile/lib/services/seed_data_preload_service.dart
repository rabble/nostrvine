// ABOUTME: Service for loading seed data into database on first launch.
// ABOUTME: Reads a bundled JSON manifest and issues parameterized INSERTs.

import 'dart:convert';

import 'package:db_client/db_client.dart';
import 'package:drift/drift.dart' show Variable;
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
        final bundle = jsonDecode(raw) as Map<String, dynamic>;
        final events = (bundle['events'] as List? ?? const [])
            .cast<Map<String, dynamic>>();
        final profiles = (bundle['profiles'] as List? ?? const [])
            .cast<Map<String, dynamic>>();
        final metrics = (bundle['metrics'] as List? ?? const [])
            .cast<Map<String, dynamic>>();

        await db.transaction(() async {
          for (final event in events) {
            await _insertEvent(db, event);
          }
          for (final profile in profiles) {
            await _insertProfile(db, profile);
          }
          for (final metric in metrics) {
            await _insertMetric(db, metric);
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

  static Future<void> _insertEvent(
    AppDatabase db,
    Map<String, dynamic> event,
  ) async {
    await db.customInsert(
      'INSERT OR IGNORE INTO event '
      '(id, pubkey, created_at, kind, tags, content, sig, sources) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, NULL)',
      variables: [
        Variable.withString(event['id'] as String),
        Variable.withString(event['pubkey'] as String),
        Variable.withInt(event['created_at'] as int),
        Variable.withInt(event['kind'] as int),
        Variable.withString(jsonEncode(event['tags'])),
        Variable.withString(event['content'] as String),
        Variable.withString(event['sig'] as String),
      ],
    );
  }

  static Future<void> _insertProfile(
    AppDatabase db,
    Map<String, dynamic> profile,
  ) async {
    final displayName = profile['display_name'] as String?;
    final name = profile['name'] as String?;
    final picture = profile['picture'] as String?;
    final banner = profile['banner'] as String?;
    final about = profile['about'] as String?;
    final website = profile['website'] as String?;
    final nip05 = profile['nip05'] as String?;
    final lud16 = profile['lud16'] as String?;
    final lud06 = profile['lud06'] as String?;
    final rawData = profile['raw_data'] as String?;
    await db.customInsert(
      'INSERT OR IGNORE INTO user_profiles '
      '(pubkey, display_name, name, picture, banner, about, website, '
      'nip05, lud16, lud06, raw_data, created_at, event_id, last_fetched) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      variables: [
        Variable.withString(profile['pubkey'] as String),
        if (displayName != null)
          Variable.withString(displayName)
        else
          const Variable(null),
        if (name != null) Variable.withString(name) else const Variable(null),
        if (picture != null)
          Variable.withString(picture)
        else
          const Variable(null),
        if (banner != null)
          Variable.withString(banner)
        else
          const Variable(null),
        if (about != null) Variable.withString(about) else const Variable(null),
        if (website != null)
          Variable.withString(website)
        else
          const Variable(null),
        if (nip05 != null) Variable.withString(nip05) else const Variable(null),
        if (lud16 != null) Variable.withString(lud16) else const Variable(null),
        if (lud06 != null) Variable.withString(lud06) else const Variable(null),
        if (rawData != null)
          Variable.withString(rawData)
        else
          const Variable(null),
        Variable.withDateTime(DateTime.parse(profile['created_at'] as String)),
        Variable.withString(profile['event_id'] as String),
        Variable.withDateTime(
          DateTime.parse(profile['last_fetched'] as String),
        ),
      ],
    );
  }

  static Future<void> _insertMetric(
    AppDatabase db,
    Map<String, dynamic> metric,
  ) async {
    final loopCount = metric['loop_count'] as int?;
    final likes = metric['likes'] as int?;
    final views = metric['views'] as int?;
    final comments = metric['comments'] as int?;
    await db.customInsert(
      'INSERT OR IGNORE INTO video_metrics '
      '(event_id, loop_count, likes, views, comments, updated_at) '
      'VALUES (?, ?, ?, ?, ?, ?)',
      variables: [
        Variable.withString(metric['event_id'] as String),
        if (loopCount != null)
          Variable.withInt(loopCount)
        else
          const Variable(null),
        if (likes != null) Variable.withInt(likes) else const Variable(null),
        if (views != null) Variable.withInt(views) else const Variable(null),
        if (comments != null)
          Variable.withInt(comments)
        else
          const Variable(null),
        Variable.withDateTime(DateTime.parse(metric['updated_at'] as String)),
      ],
    );
  }
}
