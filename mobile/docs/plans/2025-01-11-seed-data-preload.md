Status: Historical

> Historical note
> Preserved for context during the P1 documentation refresh. This file may reference deleted screens, older branding, or superseded implementation details. Start with docs/README.md and docs/archive/README.md for current guidance.

# Seed Data Preload Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Preload 500 curated Nostr events (250 videos + 250 profiles) into local database on first app launch using raw SQL for <500ms load time.

**Architecture:** Bundle SQL INSERT statements in assets, check if database empty on startup, execute SQL in single transaction. Uses existing Drift database infrastructure with direct SQLite execution.

**Tech Stack:** Dart, Drift (SQLite ORM), nostr_sdk, Flutter assets

---

## Task 1: Add getEventCount() to NostrEventsDao

**Files:**
- Modify: `mobile/lib/database/daos/nostr_events_dao.dart`
- Test: `mobile/test/database/daos/nostr_events_dao_test.dart`

**Step 1: Write the failing test**

Create test file with:

```dart
// ABOUTME: Tests for NostrEventsDao event count queries
// ABOUTME: Verifies getEventCount() returns correct count for empty and populated database

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/database/app_database.dart';
import 'package:nostr_sdk/event.dart';

void main() {
  group('NostrEventsDao.getEventCount', () {
    late AppDatabase db;

    setUp(() async {
      // Create in-memory test database
      db = AppDatabase.test(':memory:');
    });

    tearDown(() async {
      await db.close();
    });

    test('returns 0 for empty database', () async {
      final count = await db.nostrEventsDao.getEventCount();
      expect(count, equals(0));
    });

    test('returns correct count after inserting events', () async {
      // Insert 3 test events
      final events = [
        Event(
          id: 'event1',
          pubkey: 'pubkey1',
          createdAt: 1234567890,
          kind: 34236,
          tags: [],
          content: 'Video 1',
          sig: 'sig1',
        ),
        Event(
          id: 'event2',
          pubkey: 'pubkey2',
          createdAt: 1234567891,
          kind: 34236,
          tags: [],
          content: 'Video 2',
          sig: 'sig2',
        ),
        Event(
          id: 'event3',
          pubkey: 'pubkey3',
          createdAt: 1234567892,
          kind: 0,
          tags: [],
          content: '{"name":"Alice"}',
          sig: 'sig3',
        ),
      ];

      await db.nostrEventsDao.upsertEventsBatch(events);

      final count = await db.nostrEventsDao.getEventCount();
      expect(count, equals(3));
    });

    test('count increases as events are added', () async {
      expect(await db.nostrEventsDao.getEventCount(), equals(0));

      await db.nostrEventsDao.upsertEvent(Event(
        id: 'event1',
        pubkey: 'pubkey1',
        createdAt: 1234567890,
        kind: 34236,
        tags: [],
        content: 'Video 1',
        sig: 'sig1',
      ));
      expect(await db.nostrEventsDao.getEventCount(), equals(1));

      await db.nostrEventsDao.upsertEvent(Event(
        id: 'event2',
        pubkey: 'pubkey2',
        createdAt: 1234567891,
        kind: 34236,
        tags: [],
        content: 'Video 2',
        sig: 'sig2',
      ));
      expect(await db.nostrEventsDao.getEventCount(), equals(2));
    });
  });
}
```

**Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/database/daos/nostr_events_dao_test.dart`

Expected: FAIL with "The method 'getEventCount' isn't defined"

**Step 3: Implement getEventCount() method**

Add to `mobile/lib/database/daos/nostr_events_dao.dart` after existing methods:

```dart
  /// Get total count of events in database
  ///
  /// Used to check if database is empty before loading seed data.
  Future<int> getEventCount() async {
    final result = await customSelect(
      'SELECT COUNT(*) as cnt FROM event',
    ).getSingle();
    return result.read<int>('cnt');
  }
```

**Step 4: Run test to verify it passes**

Run: `cd mobile && flutter test test/database/daos/nostr_events_dao_test.dart`

Expected: PASS (all 3 tests green)

**Step 5: Commit**

```bash
git add mobile/lib/database/daos/nostr_events_dao.dart mobile/test/database/daos/nostr_events_dao_test.dart
git commit -m "feat(database): add getEventCount() to NostrEventsDao

Add method to check if database is empty before loading seed data.

Tested:
- Returns 0 for empty database
- Returns correct count after inserting events
- Count increases as events are added

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 2: Create SeedDataPreloadService with Empty Database Check

**Files:**
- Create: `mobile/lib/services/seed_data_preload_service.dart`
- Test: `mobile/test/services/seed_data_preload_service_test.dart`

**Step 1: Write the failing test**

Create test file:

```dart
// ABOUTME: Tests for SeedDataPreloadService seed data loading
// ABOUTME: Verifies service skips load when DB non-empty and loads when empty

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/database/app_database.dart';
import 'package:openvine/services/seed_data_preload_service.dart';
import 'package:nostr_sdk/event.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SeedDataPreloadService', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.test(':memory:');
    });

    tearDown(() async {
      await db.close();
    });

    test('skips load when database already has events', () async {
      // Insert an event to make DB non-empty
      await db.nostrEventsDao.upsertEvent(Event(
        id: 'existing1',
        pubkey: 'pubkey1',
        createdAt: 1234567890,
        kind: 34236,
        tags: [],
        content: 'Existing video',
        sig: 'sig1',
      ));

      // Should skip load
      await SeedDataPreloadService.loadSeedDataIfNeeded(db);

      // Count should still be 1 (no seed data added)
      final count = await db.nostrEventsDao.getEventCount();
      expect(count, equals(1));
    });

    test('loads seed data when database is empty', () async {
      // Mock asset to return minimal SQL
      const mockSql = '''
INSERT OR IGNORE INTO event (id, pubkey, created_at, kind, tags, content, sig, sources)
VALUES ('seed1', 'seedpubkey1', 1234567890, 34236, '[]', 'Seed video', 'seedsig1', NULL);

INSERT OR IGNORE INTO event (id, pubkey, created_at, kind, tags, content, sig, sources)
VALUES ('seed2', 'seedpubkey2', 1234567891, 0, '[]', '{"name":"Alice"}', 'seedsig2', NULL);
''';

      // Override rootBundle for test
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('flutter/assets'),
        (MethodCall methodCall) async {
          if (methodCall.method == 'load' &&
              methodCall.arguments == 'assets/seed_data/seed_events.sql') {
            return mockSql.codeUnits;
          }
          return null;
        },
      );

      // Database should be empty
      expect(await db.nostrEventsDao.getEventCount(), equals(0));

      // Load seed data
      await SeedDataPreloadService.loadSeedDataIfNeeded(db);

      // Should have 2 events now
      final count = await db.nostrEventsDao.getEventCount();
      expect(count, equals(2));
    });

    test('handles missing asset gracefully', () async {
      // Override rootBundle to throw error
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('flutter/assets'),
        (MethodCall methodCall) async {
          throw FlutterError('Asset not found');
        },
      );

      // Should not throw, just log error
      await expectLater(
        SeedDataPreloadService.loadSeedDataIfNeeded(db),
        completes,
      );

      // Database should still be empty
      expect(await db.nostrEventsDao.getEventCount(), equals(0));
    });

    test('handles malformed SQL gracefully', () async {
      // Mock asset with invalid SQL
      const badSql = 'INVALID SQL SYNTAX HERE;;;';

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('flutter/assets'),
        (MethodCall methodCall) async {
          if (methodCall.method == 'load') {
            return badSql.codeUnits;
          }
          return null;
        },
      );

      // Should not throw, just log error
      await expectLater(
        SeedDataPreloadService.loadSeedDataIfNeeded(db),
        completes,
      );

      // Database should still be empty (no events inserted)
      expect(await db.nostrEventsDao.getEventCount(), equals(0));
    });
  });
}
```

**Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/services/seed_data_preload_service_test.dart`

Expected: FAIL with "SeedDataPreloadService not found"

**Step 3: Implement SeedDataPreloadService**

Create `mobile/lib/services/seed_data_preload_service.dart`:

```dart
// ABOUTME: Service for loading seed data into database on first launch
// ABOUTME: Executes bundled SQL INSERT statements when database is empty

import 'package:flutter/services.dart';
import 'package:openvine/database/app_database.dart';
import 'package:unified_logger/unified_logger.dart';

class SeedDataPreloadService {
  /// Load seed data if database is empty
  ///
  /// This is a one-time operation on first app launch.
  /// If database already has events, this is a no-op.
  ///
  /// Errors are logged but non-critical - app works normally by fetching
  /// from relay if seed load fails.
  static Future<void> loadSeedDataIfNeeded(AppDatabase db) async {
    try {
      // Check if database already has events
      final count = await db.nostrEventsDao.getEventCount();
      if (count > 0) {
        Log.info('[SEED] Database has $count events, skipping seed load',
            name: 'SeedDataPreload', category: LogCategory.system);
        return;
      }

      Log.info('[SEED] Database empty, loading seed data...',
          name: 'SeedDataPreload', category: LogCategory.system);

      // Load SQL file from assets
      final sql = await rootBundle.loadString(
        'assets/seed_data/seed_events.sql',
      );

      // Execute all SQL statements in a single transaction
      await db.transaction(() async {
        final statements = sql
            .split(';')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty && !s.startsWith('--'));

        for (final statement in statements) {
          await db.customStatement(statement);
        }
      });

      // Log success
      final finalCount = await db.nostrEventsDao.getEventCount();
      Log.info('[SEED] ✅ Loaded seed data: $finalCount events',
          name: 'SeedDataPreload', category: LogCategory.system);
    } catch (e, stack) {
      // Non-critical failure: user will fetch from relay normally
      Log.error('[SEED] ❌ Failed to load seed data (non-critical): $e',
          name: 'SeedDataPreload', category: LogCategory.system);
      Log.verbose('[SEED] Stack trace: $stack',
          name: 'SeedDataPreload', category: LogCategory.system);
    }
  }
}
```

**Step 4: Run test to verify it passes**

Run: `cd mobile && flutter test test/services/seed_data_preload_service_test.dart`

Expected: PASS (all 4 tests green)

**Step 5: Commit**

```bash
git add mobile/lib/services/seed_data_preload_service.dart mobile/test/services/seed_data_preload_service_test.dart
git commit -m "feat(services): add SeedDataPreloadService for first-launch preload

Service checks if database empty and loads SQL from assets if needed.

Features:
- Skips load when DB already has events
- Executes SQL in transaction
- Handles errors gracefully (non-critical)

Tested:
- Skips when DB non-empty
- Loads seed data when DB empty
- Handles missing asset gracefully
- Handles malformed SQL gracefully

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 3: Create Seed Data Generation Script

**Files:**
- Create: `mobile/scripts/generate_seed_data.dart`
- Create: `mobile/assets/seed_data/seed_events.sql` (generated output)

**Step 1: Create generation script**

Create `mobile/scripts/generate_seed_data.dart`:

```dart
// ABOUTME: Script to generate seed data SQL from relay.divine.video
// ABOUTME: Queries top 250 videos by loop count and their author profiles

import 'dart:io';
import 'dart:convert';
import 'package:nostr_sdk/nostr_sdk.dart';

Future<void> main() async {
  print('[SEED GEN] Connecting to relay.divine.video...');

  // Initialize nostr_sdk
  await Nostr.instance.init();

  try {
    // Connect to relay
    final relay = Relay('wss://relay.divine.video');
    await relay.connect();
    print('[SEED GEN] ✅ Connected');

    // Query for video events (kind 34236)
    print('[SEED GEN] Querying for top videos...');
    final videoFilter = Filter(
      kinds: [34236],
      limit: 1000, // Get more than needed to filter by loop count
    );

    final videoEvents = await relay.query([videoFilter]);
    print('[SEED GEN] Found ${videoEvents.length} videos');

    // Sort by loop count (descending) and take top 250
    final videosWithLoops = videoEvents.where((e) {
      final loopTag = e.tags.firstWhere(
        (tag) => tag.length >= 2 && tag[0] == 'loops',
        orElse: () => ['', '0'],
      );
      return int.tryParse(loopTag[1]) != null && int.parse(loopTag[1]) > 0;
    }).toList();

    videosWithLoops.sort((a, b) {
      final aLoops = int.parse(a.tags.firstWhere(
        (tag) => tag.length >= 2 && tag[0] == 'loops',
      )[1]);
      final bLoops = int.parse(b.tags.firstWhere(
        (tag) => tag.length >= 2 && tag[0] == 'loops',
      )[1]);
      return bLoops.compareTo(aLoops);
    });

    final top250Videos = videosWithLoops.take(250).toList();
    print('[SEED GEN] Selected top 250 videos by loop count');

    // Extract unique author pubkeys
    final authorPubkeys = top250Videos.map((e) => e.pubkey).toSet();
    print('[SEED GEN] Found ${authorPubkeys.length} unique authors');

    // Query for author profiles (kind 0)
    print('[SEED GEN] Querying for author profiles...');
    final profileFilter = Filter(
      kinds: [0],
      authors: authorPubkeys.toList(),
    );

    final profileEvents = await relay.query([profileFilter]);
    print('[SEED GEN] Found ${profileEvents.length} profiles');

    // Generate SQL
    print('[SEED GEN] Generating SQL...');
    final sql = _generateSQL(top250Videos, profileEvents);

    // Write to file
    final outputFile = File('assets/seed_data/seed_events.sql');
    await outputFile.create(recursive: true);
    await outputFile.writeAsString(sql);

    print('[SEED GEN] ✅ Generated seed data: ${outputFile.path}');
    print('[SEED GEN]    Videos: ${top250Videos.length}');
    print('[SEED GEN]    Profiles: ${profileEvents.length}');
    print('[SEED GEN]    Total events: ${top250Videos.length + profileEvents.length}');

    await relay.disconnect();
  } catch (e, stack) {
    print('[SEED GEN] ❌ Error: $e');
    print('[SEED GEN] Stack: $stack');
    exit(1);
  }
}

String _generateSQL(List<Event> videos, List<Event> profiles) {
  final buffer = StringBuffer();

  buffer.writeln('-- Divine Seed Data');
  buffer.writeln('-- Generated: ${DateTime.now().toIso8601String()}');
  buffer.writeln('-- Videos: ${videos.length}');
  buffer.writeln('-- Profiles: ${profiles.length}');
  buffer.writeln();

  // Video events
  buffer.writeln('-- Video Events (kind 34236)');
  for (final video in videos) {
    buffer.writeln(_generateEventInsert(video));
  }

  buffer.writeln();

  // Profile events
  buffer.writeln('-- User Profiles (kind 0)');
  for (final profile in profiles) {
    buffer.writeln(_generateEventInsert(profile));
    buffer.writeln(_generateProfileInsert(profile));
  }

  buffer.writeln();

  // Video metrics
  buffer.writeln('-- Video Metrics');
  for (final video in videos) {
    buffer.writeln(_generateMetricsInsert(video));
  }

  return buffer.toString();
}

String _generateEventInsert(Event event) {
  return '''
INSERT OR IGNORE INTO event (id, pubkey, created_at, kind, tags, content, sig, sources)
VALUES (
  '${_escape(event.id)}',
  '${_escape(event.pubkey)}',
  ${event.createdAt},
  ${event.kind},
  '${_escape(jsonEncode(event.tags))}',
  '${_escape(event.content)}',
  '${_escape(event.sig)}',
  NULL
);''';
}

String _generateProfileInsert(Event event) {
  try {
    final profile = jsonDecode(event.content) as Map<String, dynamic>;

    return '''
INSERT OR IGNORE INTO user_profiles (
  pubkey, display_name, name, picture, banner, about, website,
  nip05, lud16, lud06, raw_data, created_at, event_id, last_fetched
)
VALUES (
  '${_escape(event.pubkey)}',
  ${_sqlString(profile['display_name'])},
  ${_sqlString(profile['name'])},
  ${_sqlString(profile['picture'])},
  ${_sqlString(profile['banner'])},
  ${_sqlString(profile['about'])},
  ${_sqlString(profile['website'])},
  ${_sqlString(profile['nip05'])},
  ${_sqlString(profile['lud16'])},
  ${_sqlString(profile['lud06'])},
  '${_escape(event.content)}',
  '${DateTime.fromMillisecondsSinceEpoch(event.createdAt * 1000).toIso8601String()}',
  '${_escape(event.id)}',
  '${DateTime.now().toIso8601String()}'
);''';
  } catch (e) {
    // Skip malformed profiles
    return '-- Skipped malformed profile for ${event.pubkey}';
  }
}

String _generateMetricsInsert(Event event) {
  final loopCount = _getTagValue(event.tags, 'loops');
  final likes = _getTagValue(event.tags, 'likes');
  final views = _getTagValue(event.tags, 'views');
  final comments = _getTagValue(event.tags, 'comments');

  return '''
INSERT OR IGNORE INTO video_metrics (event_id, loop_count, likes, views, comments, updated_at)
VALUES (
  '${_escape(event.id)}',
  ${loopCount ?? 'NULL'},
  ${likes ?? 'NULL'},
  ${views ?? 'NULL'},
  ${comments ?? 'NULL'},
  '${DateTime.now().toIso8601String()}'
);''';
}

String? _getTagValue(List<List<String>> tags, String tagName) {
  try {
    final tag = tags.firstWhere(
      (t) => t.length >= 2 && t[0] == tagName,
      orElse: () => [],
    );
    if (tag.length >= 2) {
      final value = int.tryParse(tag[1]);
      return value?.toString();
    }
  } catch (_) {}
  return null;
}

String _escape(String str) => str.replaceAll("'", "''");

String _sqlString(dynamic value) {
  if (value == null) return 'NULL';
  return "'${_escape(value.toString())}'";
}
```

**Step 2: Add script dependencies to pubspec.yaml**

This script uses nostr_sdk which is already in dependencies, no changes needed.

**Step 3: Run script to generate seed data**

Run: `cd mobile && dart run scripts/generate_seed_data.dart`

Expected: Creates `assets/seed_data/seed_events.sql` with ~500 INSERT statements

**Step 4: Verify generated SQL**

Run: `head -n 20 mobile/assets/seed_data/seed_events.sql`

Expected: See SQL comments and INSERT statements

**Step 5: Add asset to pubspec.yaml**

Edit `mobile/pubspec.yaml`, add to flutter/assets section:

```yaml
flutter:
  assets:
    # ... existing assets ...
    - assets/seed_data/seed_events.sql
```

**Step 6: Commit**

```bash
git add mobile/scripts/generate_seed_data.dart mobile/assets/seed_data/seed_events.sql mobile/pubspec.yaml
git commit -m "feat(scripts): add seed data generation script

Script queries relay.divine.video for:
- Top 250 videos by loop count
- Author profiles for those videos
- Generates SQL INSERT statements

Usage: dart run scripts/generate_seed_data.dart

Output: assets/seed_data/seed_events.sql (~500 events)

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 4: Integrate Seed Data Preload into App Startup

**Files:**
- Modify: `mobile/lib/main.dart` (add startup phase)
- Test: Manual testing (verify seed loads on first launch)

**Step 1: Add seed preload startup phase**

Edit `mobile/lib/main.dart`, add after Hive migration (around line 264):

```dart
  // Run Hive → Drift migration if needed
  StartupPerformanceService.instance.startPhase('data_migration');
  AppDatabase? migrationDb;
  try {
    migrationDb = AppDatabase();
    final migrationService = MigrationService(migrationDb);
    await migrationService.runMigrations();
    Log.info('[MIGRATION] ✅ Data migration complete',
        name: 'Main', category: LogCategory.system);
  } catch (e, stack) {
    // Don't block app startup on migration failures
    Log.error('[MIGRATION] ❌ Migration failed (non-critical): $e',
        name: 'Main', category: LogCategory.system);
    Log.verbose('[MIGRATION] Stack: $stack',
        name: 'Main', category: LogCategory.system);
  } finally {
    // Close migration database to prevent multiple instances warning
    await migrationDb?.close();
  }
  StartupPerformanceService.instance.completePhase('data_migration');

  // Load seed data if database is empty
  StartupPerformanceService.instance.startPhase('seed_data_preload');
  AppDatabase? seedDb;
  try {
    seedDb = AppDatabase();
    await SeedDataPreloadService.loadSeedDataIfNeeded(seedDb);
  } catch (e, stack) {
    // Non-critical: user will fetch from relay normally
    Log.error('[SEED] Preload failed (non-critical): $e',
        name: 'Main', category: LogCategory.system);
    Log.verbose('[SEED] Stack: $stack',
        name: 'Main', category: LogCategory.system);
  } finally {
    await seedDb?.close();
  }
  StartupPerformanceService.instance.completePhase('seed_data_preload');

  // Initialize SharedPreferences for feature flags
  StartupPerformanceService.instance.startPhase('shared_preferences');
  final sharedPreferences = await SharedPreferences.getInstance();
  StartupPerformanceService.instance.completePhase('shared_preferences');
```

**Step 2: Add import**

Add to imports at top of `mobile/lib/main.dart`:

```dart
import 'package:openvine/services/seed_data_preload_service.dart';
```

**Step 3: Test on fresh install (manual)**

Run:
```bash
# Clear app data
cd mobile
flutter clean
rm -rf ~/Library/Containers/com.openvine.divine  # macOS
# OR
adb shell pm clear com.openvine.divine  # Android

# Run app
./run_dev.sh macos debug
```

Expected:
- App starts successfully
- Console shows "[SEED] Database empty, loading seed data..."
- Console shows "[SEED] ✅ Loaded seed data: 500 events"
- Home feed shows videos immediately

**Step 4: Test with existing data (manual)**

Run app again without clearing data.

Expected:
- Console shows "[SEED] Database has X events, skipping seed load"
- No seed data loaded (count unchanged)

**Step 5: Commit**

```bash
git add mobile/lib/main.dart
git commit -m "feat(startup): integrate seed data preload into app launch

Add startup phase after Hive migration to load seed data if DB empty.

Non-blocking: Errors logged but don't prevent app startup.
Performance: <500ms load time for 500 events.

Tested manually:
- Fresh install loads seed data
- Existing install skips seed load

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com)"
```

---

## Task 5: Performance Testing and Optimization

**Files:**
- Create: `mobile/test/performance/seed_data_performance_test.dart`

**Step 1: Create performance test**

Create test file:

```dart
// ABOUTME: Performance tests for seed data preload
// ABOUTME: Verifies load time is <500ms for realistic data volume

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/database/app_database.dart';
import 'package:openvine/services/seed_data_preload_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SeedDataPreloadService Performance', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.test(':memory:');
    });

    tearDown(() async {
      await db.close();
    });

    test('loads 500 events in <500ms', () async {
      // Generate mock SQL with 500 events (250 videos + 250 profiles)
      final mockSql = _generateMockSql(250, 250);

      // Mock asset
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('flutter/assets'),
        (MethodCall methodCall) async {
          if (methodCall.method == 'load') {
            return mockSql.codeUnits;
          }
          return null;
        },
      );

      // Measure load time
      final stopwatch = Stopwatch()..start();
      await SeedDataPreloadService.loadSeedDataIfNeeded(db);
      stopwatch.stop();

      final loadTimeMs = stopwatch.elapsedMilliseconds;
      print('[PERF] Seed data load time: ${loadTimeMs}ms');

      // Verify loaded
      final count = await db.nostrEventsDao.getEventCount();
      expect(count, equals(500));

      // Verify performance
      expect(loadTimeMs, lessThan(500),
          reason: 'Seed data load should complete in <500ms');
    });

    test('empty database check is <10ms', () async {
      // Insert some events to make DB non-empty
      await db.customStatement('''
        INSERT INTO event (id, pubkey, created_at, kind, tags, content, sig, sources)
        VALUES ('test1', 'pubkey1', 1234567890, 34236, '[]', 'test', 'sig1', NULL)
      ''');

      // Measure empty check time
      final stopwatch = Stopwatch()..start();
      await SeedDataPreloadService.loadSeedDataIfNeeded(db);
      stopwatch.stop();

      final checkTimeMs = stopwatch.elapsedMilliseconds;
      print('[PERF] Empty check time: ${checkTimeMs}ms');

      // Should be very fast (just a COUNT query)
      expect(checkTimeMs, lessThan(10),
          reason: 'Empty check should be <10ms');
    });
  });
}

String _generateMockSql(int videoCount, int profileCount) {
  final buffer = StringBuffer();

  buffer.writeln('-- Mock Seed Data for Performance Testing');
  buffer.writeln();

  // Generate video events
  for (var i = 0; i < videoCount; i++) {
    buffer.writeln('''
INSERT OR IGNORE INTO event (id, pubkey, created_at, kind, tags, content, sig, sources)
VALUES ('video$i', 'pubkey$i', ${1234567890 + i}, 34236, '[["url","https://example.com/video$i.mp4"],["loops","${1000 - i}"]]', 'Video $i', 'sig$i', NULL);
''');
  }

  buffer.writeln();

  // Generate profile events
  for (var i = 0; i < profileCount; i++) {
    buffer.writeln('''
INSERT OR IGNORE INTO event (id, pubkey, created_at, kind, tags, content, sig, sources)
VALUES ('profile$i', 'pubkey$i', ${1234567890 + i}, 0, '[]', '{"name":"User$i","picture":"https://example.com/avatar$i.jpg"}', 'profsig$i', NULL);

INSERT OR IGNORE INTO user_profiles (pubkey, display_name, name, picture, created_at, event_id, last_fetched)
VALUES ('pubkey$i', 'User$i', 'user$i', 'https://example.com/avatar$i.jpg', '2024-01-01', 'profile$i', '2024-01-01');
''');
  }

  buffer.writeln();

  // Generate video metrics
  for (var i = 0; i < videoCount; i++) {
    buffer.writeln('''
INSERT OR IGNORE INTO video_metrics (event_id, loop_count, likes, views, updated_at)
VALUES ('video$i', ${1000 - i}, ${50 + i}, ${2000 + i * 10}, '2024-01-01');
''');
  }

  return buffer.toString();
}
```

**Step 2: Run performance test**

Run: `cd mobile && flutter test test/performance/seed_data_performance_test.dart`

Expected:
- PASS with load time <500ms
- Console shows actual load time (e.g., "[PERF] Seed data load time: 234ms")

**Step 3: Commit**

```bash
git add mobile/test/performance/seed_data_performance_test.dart
git commit -m "test(performance): add seed data preload performance tests

Verify:
- 500 events load in <500ms
- Empty DB check is <10ms

Results logged to console for monitoring.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 6: Documentation and Final Verification

**Files:**
- Create: `mobile/scripts/README.md` (document seed generation)
- Modify: `mobile/README.md` or `CONTRIBUTING.md` (add seed data section)

**Step 1: Document seed generation script**

Create `mobile/scripts/README.md`:

```markdown
# Scripts

## generate_seed_data.dart

Generates seed data SQL from relay.divine.video for first-launch preload.

**Usage:**
```bash
cd mobile
dart run scripts/generate_seed_data.dart
```

**Output:**
- `assets/seed_data/seed_events.sql` - SQL INSERT statements

**What it generates:**
- Top 250 video events (kind 34236) sorted by loop count
- User profiles (kind 0) for video authors
- Video metrics extracted from event tags

**When to regenerate:**
- Monthly (or before major releases) to refresh curated content
- After relay.divine.video gets significant new popular videos

**Requirements:**
- Access to relay.divine.video
- nostr_sdk dependency (already in pubspec.yaml)
```

**Step 2: Add section to main README**

Add to `mobile/README.md` or create section in `CONTRIBUTING.md`:

```markdown
## Seed Data

The app preloads 500 curated Nostr events on first launch for immediate content availability.

**How it works:**
- `assets/seed_data/seed_events.sql` contains SQL INSERT statements
- `SeedDataPreloadService` loads SQL on first launch if database empty
- Load time: <500ms, APK size impact: ~1-2MB

**Regenerating seed data:**
```bash
cd mobile
dart run scripts/generate_seed_data.dart
```

See `scripts/README.md` for details.
```

**Step 3: Run final verification**

```bash
# Run all tests
cd mobile
flutter test

# Check APK size impact
flutter build apk --release
ls -lh build/app/outputs/flutter-apk/app-release.apk

# Verify seed SQL exists
ls -lh assets/seed_data/seed_events.sql
```

Expected:
- All tests pass
- APK size increase ~1-2MB
- Seed SQL file ~2-3MB uncompressed

**Step 4: Commit**

```bash
git add mobile/scripts/README.md mobile/README.md
git commit -m "docs: add seed data documentation

Document:
- Seed generation script usage
- Seed data architecture overview
- When and how to regenerate

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com)"
```

---

## Final Checklist

Before marking complete:

- [ ] All tests pass: `flutter test`
- [ ] Performance verified: <500ms load time
- [ ] Manual testing: Fresh install shows seed data
- [ ] Manual testing: Existing install skips seed load
- [ ] APK size verified: ~1-2MB increase
- [ ] Code analysis clean: `flutter analyze`
- [ ] All commits pushed to feature branch
- [ ] Ready for code review

## Code Review Checklist

Use @superpowers:requesting-code-review after implementation complete.

**Review criteria:**
- TDD followed: Tests written before implementation
- Performance targets met: <500ms load time
- Error handling: Graceful degradation on failures
- SQL injection safe: Pre-generated SQL, no user input
- Asset bundling: seed_events.sql in pubspec.yaml
- Logging appropriate: Info for success, error for failure
- Memory efficient: Transaction-based batch insert

---

## Notes

**Why raw SQL vs JSON:**
- 10x faster: No JSON parsing, no Event object creation
- Smaller: SQL more compact than JSON
- Direct: Straight to database, no abstraction layers

**Why non-critical errors:**
- Seed data is optimization, not requirement
- App works normally by fetching from relay
- Don't block startup on seed load failure

**Future enhancements (out of scope):**
- Progressive loading (background after startup)
- Incremental updates on app upgrade
- User-customizable seed topics
