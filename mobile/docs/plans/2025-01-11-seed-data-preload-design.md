# Seed Data Preload Design

**Date:** 2025-01-11
**Status:** Approved
**Author:** Claude Code

## Overview

Preload curated Nostr events into the local Drift database on first app launch to provide immediate content without relay sync dependency.

## Goals

- Users see content immediately on first launch
- Works offline from first install
- No performance regression on startup (<500ms load time)
- Minimal APK size impact (~1-2MB)

## Non-Goals

- Updating seed data after initial load (user fetches fresh content from relay)
- Syncing seed data across devices
- User-customizable seed data

## Requirements

**Data Volume:**
- 250 video events (kind 34236) - top by loop count from relay.divine.video
- 250 user profiles (kind 0) - authors of videos
- Total: ~500 events, ~1-2MB compressed SQL

**Load Timing:**
- Only when database is empty (first install or after clear data)
- Never overwrite existing user data

**Data Source:**
- relay.divine.video for seed generation
- Selection: Top videos sorted by loop count tag

## Architecture

### Component Overview

```
┌─────────────────────────────────────────┐
│ App Startup (main.dart)                 │
│ ├─ Hive Migration                       │
│ ├─ [NEW] Seed Data Preload             │
│ └─ App Launch                           │
└─────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────┐
│ SeedDataPreloadService                  │
│ ├─ Check if DB empty (getEventCount)   │
│ ├─ Load SQL from assets                │
│ └─ Execute SQL in transaction          │
└─────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────┐
│ Direct SQLite Execution                 │
│ ├─ INSERT events to event table        │
│ ├─ INSERT profiles to user_profiles    │
│ └─ INSERT metrics to video_metrics     │
└─────────────────────────────────────────┘
```

### Design Decision: Raw SQL vs JSON

**Chosen Approach:** Raw SQL INSERT statements

**Why:**
- 10x faster: No JSON parsing, no Event object creation
- Smaller file size: SQL more compact than JSON (~1-2MB vs 2-5MB)
- Simpler: Direct database execution, no serialization layer
- Direct: No round-trip through nostr_sdk Event deserialization

**Rejected Alternatives:**
- JSON + Event objects: Slower, larger, unnecessary abstraction for static data
- Pre-built SQLite file: Complex database merging, schema version conflicts

## Implementation Details

### 1. NostrEventsDao Enhancement

**New Method:**
```dart
Future<int> getEventCount() async {
  final result = await customSelect(
    'SELECT COUNT(*) as cnt FROM event'
  ).getSingle();
  return result.read<int>('cnt');
}
```

**Purpose:** Check if database is empty before loading seed data.

**Test Coverage:**
- Unit test: Insert events, verify count
- Edge case: Empty database returns 0

---

### 2. SeedDataPreloadService

**File:** `lib/services/seed_data_preload_service.dart`

**API:**
```dart
class SeedDataPreloadService {
  /// Load seed data if database is empty
  ///
  /// This is a one-time operation on first app launch.
  /// If database already has events, this is a no-op.
  static Future<void> loadSeedDataIfNeeded(AppDatabase db) async {
    // Check if database already has events
    final count = await db.nostrEventsDao.getEventCount();
    if (count > 0) {
      Log.info('[SEED] Database has $count events, skipping seed load',
        name: 'SeedDataPreload', category: LogCategory.system);
      return;
    }

    Log.info('[SEED] Database empty, loading seed data...',
      name: 'SeedDataPreload', category: LogCategory.system);

    try {
      // Load SQL file from assets
      final sql = await rootBundle.loadString(
        'assets/seed_data/seed_events.sql'
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

**Error Handling:**
- SQL execution failure → Log error, continue app startup
- Asset not found → Log error, continue (development builds may not have seed data)
- Malformed SQL → Log error, continue
- **Rationale:** Seed data is optimization, not requirement. App works normally by fetching from relay.

**Test Coverage:**
- Unit test: Mock rootBundle, verify SQL execution
- Integration test: Load real seed SQL, verify events in database
- Error test: Malformed SQL handled gracefully
- Performance test: Verify <500ms load time

---

### 3. Seed Data Generation Script

**File:** `mobile/scripts/generate_seed_data.dart`

**Purpose:** Generate `assets/seed_data/seed_events.sql` from relay.divine.video

**Algorithm:**
```dart
// 1. Connect to relay.divine.video using nostr_sdk
final relay = await Relay.connect('wss://relay.divine.video');

// 2. Query top 250 videos sorted by loop count
final videoFilter = Filter()
  ..kinds = [34236]
  ..limit = 250;
final videos = await relay.query(videoFilter);

// Sort by loop count tag (descending)
videos.sort((a, b) {
  final aLoops = _getLoopCount(a);
  final bLoops = _getLoopCount(b);
  return bLoops.compareTo(aLoops);
});
final top250 = videos.take(250).toList();

// 3. Extract unique author pubkeys
final authorPubkeys = top250.map((v) => v.pubkey).toSet();

// 4. Query author profiles
final profileFilter = Filter()
  ..kinds = [0]
  ..authors = authorPubkeys.toList();
final profiles = await relay.query(profileFilter);

// 5. Generate SQL INSERT statements
final sqlBuffer = StringBuffer();
sqlBuffer.writeln('-- Divine Seed Data');
sqlBuffer.writeln('-- Generated: ${DateTime.now().toIso8601String()}');
sqlBuffer.writeln('-- Events: ${top250.length} videos + ${profiles.length} profiles');
sqlBuffer.writeln();

// Video events
for (final video in top250) {
  sqlBuffer.writeln(_generateEventInsert(video));
}

// User profiles
for (final profile in profiles) {
  sqlBuffer.writeln(_generateProfileInsert(profile));
}

// Video metrics (extract from event tags)
for (final video in top250) {
  sqlBuffer.writeln(_generateMetricsInsert(video));
}

// 6. Write to file
await File('assets/seed_data/seed_events.sql').writeAsString(sqlBuffer.toString());
```

**SQL Generation Helpers:**
```dart
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
  final profile = _parseProfileContent(event.content);
  return '''
INSERT OR IGNORE INTO user_profiles (
  pubkey, display_name, name, picture, banner, about, website,
  nip05, lud16, lud06, raw_data, created_at, event_id, last_fetched
)
VALUES (
  '${_escape(event.pubkey)}',
  ${_sqlString(profile.displayName)},
  ${_sqlString(profile.name)},
  ${_sqlString(profile.picture)},
  ${_sqlString(profile.banner)},
  ${_sqlString(profile.about)},
  ${_sqlString(profile.website)},
  ${_sqlString(profile.nip05)},
  ${_sqlString(profile.lud16)},
  ${_sqlString(profile.lud06)},
  '${_escape(event.content)}',
  '${DateTime.fromMillisecondsSinceEpoch(event.createdAt * 1000).toIso8601String()}',
  '${_escape(event.id)}',
  '${DateTime.now().toIso8601String()}'
);''';
}

String _generateMetricsInsert(Event event) {
  final loopCount = _getTagValue(event.tags, 'loops');
  final likes = _getTagValue(event.tags, 'likes');
  final views = _getTagValue(event.tags, 'views');

  return '''
INSERT OR IGNORE INTO video_metrics (event_id, loop_count, likes, views, updated_at)
VALUES (
  '${_escape(event.id)}',
  ${loopCount ?? 'NULL'},
  ${likes ?? 'NULL'},
  ${views ?? 'NULL'},
  '${DateTime.now().toIso8601String()}'
);''';
}

String _escape(String str) => str.replaceAll("'", "''");
String _sqlString(String? str) => str == null ? 'NULL' : "'${_escape(str)}'";
```

**Usage:**
```bash
cd mobile
dart run scripts/generate_seed_data.dart
# Outputs: assets/seed_data/seed_events.sql
```

**Curation Criteria:**
- Only videos with `loops` tag > 0 (proven engagement)
- Only users with valid kind 0 profile events
- Optional: Skip NSFW if `content-warning` tag present

**Test Coverage:**
- Manual: Inspect generated SQL for correctness
- Manual: Verify SQL executes without errors in SQLite shell
- Automated: Run generation script in CI to catch breakage

---

### 4. Integration into main.dart

**Location:** After Hive migration, before app launch

**Code:**
```dart
// Run Hive → Drift migration if needed
StartupPerformanceService.instance.startPhase('data_migration');
// ... existing migration code ...
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

// Continue with app launch
Log.info('Divine starting...', name: 'Main');
```

**Performance Impact:**
- Empty DB: ~200-500ms (load SQL + execute in transaction)
- Non-empty DB: ~5ms (single COUNT(*) query)
- APK size: +1-2MB compressed

**Why separate AppDatabase instance:**
- Avoid "multiple database instances" warning
- Clean lifecycle: open → load → close
- Main app database created later by Riverpod provider

---

### 5. Asset Configuration

**File:** `pubspec.yaml`

**Addition:**
```yaml
flutter:
  assets:
    - assets/seed_data/seed_events.sql
```

**File Structure:**
```
mobile/
├─ assets/
│  └─ seed_data/
│     └─ seed_events.sql  (generated, git-tracked)
├─ scripts/
│  └─ generate_seed_data.dart  (generation script)
└─ lib/
   └─ services/
      └─ seed_data_preload_service.dart
```

## Testing Strategy

### Unit Tests

**File:** `test/services/seed_data_preload_service_test.dart`

**Coverage:**
- Skips load when database non-empty
- Loads seed data when database empty
- Handles asset not found gracefully
- Handles malformed SQL gracefully

**File:** `test/database/daos/nostr_events_dao_test.dart`

**Coverage:**
- `getEventCount()` returns correct count
- `getEventCount()` returns 0 for empty database

### Integration Tests

**File:** `test/integration/seed_data_integration_test.dart`

**Coverage:**
- Load real seed SQL file
- Verify events inserted to event table
- Verify profiles inserted to user_profiles table
- Verify metrics inserted to video_metrics table
- Verify can query videos immediately after seed load

### Performance Tests

**File:** `test/performance/seed_data_performance_test.dart`

**Coverage:**
- Measure load time on simulated low-end device
- Verify <500ms for 500 events
- Verify memory usage stays under 50MB spike

### Manual Testing

**Scenarios:**
- Fresh install → verify seed data loads, content appears
- Reinstall (clear data) → verify seed data reloads
- App update with existing data → verify seed data skipped
- Offline mode → verify seed videos play without relay

## Performance Characteristics

**Load Time:**
- Empty DB: 200-500ms
  - Asset load: ~50ms
  - SQL parse/split: ~50ms
  - Transaction execution: ~100-400ms
- Non-empty DB: ~5ms (single COUNT query)

**Memory Usage:**
- Peak: ~20-30MB during SQL execution
- Sustained: 0MB (no retained references)

**APK Size:**
- Uncompressed: ~3-4MB (SQL text)
- Compressed: ~1-2MB (gzip in APK)

**Network Impact:**
- Zero network usage for seed data load
- Reduces initial relay sync from ~500 events to ~0 events

## Security Considerations

**SQL Injection:**
- Not a concern: SQL is pre-generated, bundled in APK
- No user input in SQL execution
- All data from trusted source (relay.divine.video)

**Event Signature Verification:**
- Seed events pre-verified during generation
- Invalid signatures filtered out during generation
- No runtime verification needed (trusted static data)

**Data Integrity:**
- SQL uses `INSERT OR IGNORE` to prevent conflicts
- Existing user data never overwritten
- Database constraints enforced (primary keys, foreign keys)

## Migration Path

**Initial Release:**
- Bundle seed data in app v1.X.0
- All users on v1.X.0+ get seed data on fresh install

**Updates:**
- Seed data updated monthly (regenerate SQL from relay)
- New app versions bundle updated seed data
- Existing users don't get updated seed (they have real data from relay)

**Rollback:**
- If seed data causes issues, remove asset from pubspec.yaml
- Service gracefully handles missing asset (logs error, continues)

## Future Enhancements

**Out of Scope for Initial Release:**

1. **Incremental Updates:** Update seed data on app upgrade
   - Complexity: Need to track seed data version, merge new events
   - Benefit: Users get refreshed curated content

2. **User-Customizable Seed:** Let users choose seed data topics
   - Complexity: Multiple seed files, user preference storage
   - Benefit: Personalized first-run experience

3. **Compressed Binary Format:** Use custom binary format for smaller size
   - Complexity: Custom serialization/deserialization
   - Benefit: ~50% smaller than SQL, ~30% faster parse
   - **Not worth it:** SQL is already fast enough (<500ms)

4. **Progressive Loading:** Load seed data in background after app launch
   - Complexity: Need UI state management, loading indicators
   - Benefit: Zero impact on startup time
   - **Not worth it:** 500ms is acceptable for first launch only

## Success Metrics

**Quantitative:**
- Seed load time <500ms on 90th percentile devices
- APK size increase <2MB
- 90%+ of fresh installs have seed data loaded successfully

**Qualitative:**
- Users report content visible immediately on first launch
- Zero user-reported issues with seed data conflicts
- No performance regressions on app startup

## Alternatives Considered

### 1. Pre-built SQLite Database
**Rejected:** Complex database merging, schema version conflicts

### 2. JSON + Event Objects
**Rejected:** 10x slower, 2x larger file size, unnecessary abstraction

### 3. Fetch on First Launch
**Rejected:** Requires network, slow relay sync, poor offline experience

### 4. No Seed Data
**Rejected:** Poor first-run experience, users see empty feed until relay sync completes

## Open Questions

None - design approved.

## Approvals

- [x] Rabble - Approved 2025-01-11
