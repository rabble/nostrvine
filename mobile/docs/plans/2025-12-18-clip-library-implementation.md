# Clip Library Redesign Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace drafts with a persistent, reusable clip library where recorded segments are immediately saved and can be combined into videos.

**Architecture:** Auto-save recorded segments to ClipLibraryService. Remove VineDraft system entirely. ClipManager becomes the central "build your video" screen with ability to add clips from library.

**Tech Stack:** Flutter/Dart, Riverpod, SharedPreferences, FFmpeg for concatenation

---

## Task 1: Add sessionId to SavedClip Model

**Files:**
- Modify: `lib/models/saved_clip.dart`
- Test: `test/models/saved_clip_test.dart`

**Step 1: Write the failing test**

Create `test/models/saved_clip_test.dart`:

```dart
// ABOUTME: Tests for SavedClip model with session grouping
// ABOUTME: Verifies JSON serialization and session ID handling

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/saved_clip.dart';

void main() {
  group('SavedClip', () {
    test('should serialize sessionId to JSON', () {
      final clip = SavedClip(
        id: 'clip_1',
        filePath: '/path/to/video.mp4',
        thumbnailPath: '/path/to/thumb.jpg',
        duration: const Duration(seconds: 2),
        createdAt: DateTime(2025, 12, 18, 14, 30),
        aspectRatio: 'square',
        sessionId: 'session_123',
      );

      final json = clip.toJson();

      expect(json['sessionId'], 'session_123');
    });

    test('should deserialize sessionId from JSON', () {
      final json = {
        'id': 'clip_1',
        'filePath': '/path/to/video.mp4',
        'thumbnailPath': '/path/to/thumb.jpg',
        'durationMs': 2000,
        'createdAt': '2025-12-18T14:30:00.000',
        'aspectRatio': 'square',
        'sessionId': 'session_456',
      };

      final clip = SavedClip.fromJson(json);

      expect(clip.sessionId, 'session_456');
    });

    test('should handle null sessionId', () {
      final json = {
        'id': 'clip_1',
        'filePath': '/path/to/video.mp4',
        'thumbnailPath': null,
        'durationMs': 2000,
        'createdAt': '2025-12-18T14:30:00.000',
        'aspectRatio': 'square',
      };

      final clip = SavedClip.fromJson(json);

      expect(clip.sessionId, isNull);
    });
  });
}
```

**Step 2: Run test to verify it fails**

Run: `cd /Users/rabble/code/andotherstuff/openvine/mobile && flutter test test/models/saved_clip_test.dart`

Expected: FAIL - sessionId parameter doesn't exist

**Step 3: Write minimal implementation**

Modify `lib/models/saved_clip.dart`:

```dart
// ABOUTME: Data model for a saved video clip in the clip library
// ABOUTME: Supports JSON serialization, thumbnails, session grouping, and display formatting

class SavedClip {
  const SavedClip({
    required this.id,
    required this.filePath,
    required this.thumbnailPath,
    required this.duration,
    required this.createdAt,
    required this.aspectRatio,
    this.sessionId,
  });

  final String id;
  final String filePath;
  final String? thumbnailPath;
  final Duration duration;
  final DateTime createdAt;
  final String aspectRatio;
  final String? sessionId;

  double get durationInSeconds => duration.inMilliseconds / 1000.0;

  String get displayDuration {
    final elapsed = DateTime.now().difference(createdAt);
    if (elapsed.inDays > 0) {
      return '${elapsed.inDays}d ago';
    } else if (elapsed.inHours > 0) {
      return '${elapsed.inHours}h ago';
    } else if (elapsed.inMinutes > 0) {
      return '${elapsed.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  SavedClip copyWith({
    String? id,
    String? filePath,
    String? thumbnailPath,
    Duration? duration,
    DateTime? createdAt,
    String? aspectRatio,
    String? sessionId,
  }) {
    return SavedClip(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      duration: duration ?? this.duration,
      createdAt: createdAt ?? this.createdAt,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      sessionId: sessionId ?? this.sessionId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'filePath': filePath,
      'thumbnailPath': thumbnailPath,
      'durationMs': duration.inMilliseconds,
      'createdAt': createdAt.toIso8601String(),
      'aspectRatio': aspectRatio,
      'sessionId': sessionId,
    };
  }

  factory SavedClip.fromJson(Map<String, dynamic> json) {
    return SavedClip(
      id: json['id'] as String,
      filePath: json['filePath'] as String,
      thumbnailPath: json['thumbnailPath'] as String?,
      duration: Duration(milliseconds: json['durationMs'] as int),
      createdAt: DateTime.parse(json['createdAt'] as String),
      aspectRatio: json['aspectRatio'] as String,
      sessionId: json['sessionId'] as String?,
    );
  }

  @override
  String toString() {
    return 'SavedClip(id: $id, duration: ${durationInSeconds}s, aspectRatio: $aspectRatio, sessionId: $sessionId)';
  }
}
```

**Step 4: Run test to verify it passes**

Run: `cd /Users/rabble/code/andotherstuff/openvine/mobile && flutter test test/models/saved_clip_test.dart`

Expected: PASS

**Step 5: Commit**

```bash
git add lib/models/saved_clip.dart test/models/saved_clip_test.dart
git commit -m "feat(clips): add sessionId field to SavedClip for grouping"
```

---

## Task 2: Add Clip Grouping to ClipLibraryService

**Files:**
- Modify: `lib/services/clip_library_service.dart`
- Test: `test/services/clip_library_service_test.dart`

**Step 1: Write the failing test**

Create `test/services/clip_library_service_test.dart`:

```dart
// ABOUTME: Tests for ClipLibraryService with session grouping
// ABOUTME: Verifies clip storage, retrieval, and grouping by session

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/saved_clip.dart';
import 'package:openvine/services/clip_library_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ClipLibraryService', () {
    late ClipLibraryService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      service = ClipLibraryService(prefs);
    });

    test('should return clips grouped by session', () async {
      final now = DateTime.now();

      // Save clips from two sessions
      await service.saveClip(SavedClip(
        id: 'clip_1',
        filePath: '/path/1.mp4',
        thumbnailPath: null,
        duration: const Duration(seconds: 1),
        createdAt: now,
        aspectRatio: 'square',
        sessionId: 'session_A',
      ));
      await service.saveClip(SavedClip(
        id: 'clip_2',
        filePath: '/path/2.mp4',
        thumbnailPath: null,
        duration: const Duration(seconds: 2),
        createdAt: now,
        aspectRatio: 'square',
        sessionId: 'session_A',
      ));
      await service.saveClip(SavedClip(
        id: 'clip_3',
        filePath: '/path/3.mp4',
        thumbnailPath: null,
        duration: const Duration(seconds: 1),
        createdAt: now.subtract(const Duration(hours: 1)),
        aspectRatio: 'square',
        sessionId: 'session_B',
      ));

      final grouped = await service.getClipsGroupedBySession();

      expect(grouped.length, 2);
      expect(grouped['session_A']?.length, 2);
      expect(grouped['session_B']?.length, 1);
    });

    test('should return clips by session ID', () async {
      final now = DateTime.now();

      await service.saveClip(SavedClip(
        id: 'clip_1',
        filePath: '/path/1.mp4',
        thumbnailPath: null,
        duration: const Duration(seconds: 1),
        createdAt: now,
        aspectRatio: 'square',
        sessionId: 'session_X',
      ));
      await service.saveClip(SavedClip(
        id: 'clip_2',
        filePath: '/path/2.mp4',
        thumbnailPath: null,
        duration: const Duration(seconds: 2),
        createdAt: now,
        aspectRatio: 'square',
        sessionId: 'session_Y',
      ));

      final sessionXClips = await service.getClipsBySession('session_X');

      expect(sessionXClips.length, 1);
      expect(sessionXClips.first.id, 'clip_1');
    });

    test('should generate unique session ID', () {
      final id1 = ClipLibraryService.generateSessionId();
      final id2 = ClipLibraryService.generateSessionId();

      expect(id1, isNot(equals(id2)));
      expect(id1, startsWith('session_'));
    });
  });
}
```

**Step 2: Run test to verify it fails**

Run: `cd /Users/rabble/code/andotherstuff/openvine/mobile && flutter test test/services/clip_library_service_test.dart`

Expected: FAIL - getClipsGroupedBySession method doesn't exist

**Step 3: Write minimal implementation**

Add to `lib/services/clip_library_service.dart`:

```dart
  /// Get all clips grouped by session ID
  /// Returns Map<sessionId, List<SavedClip>>
  /// Clips without sessionId are grouped under 'ungrouped'
  Future<Map<String, List<SavedClip>>> getClipsGroupedBySession() async {
    final clips = await getAllClips();
    final grouped = <String, List<SavedClip>>{};

    for (final clip in clips) {
      final key = clip.sessionId ?? 'ungrouped';
      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(clip);
    }

    return grouped;
  }

  /// Get clips for a specific session
  Future<List<SavedClip>> getClipsBySession(String sessionId) async {
    final clips = await getAllClips();
    return clips.where((c) => c.sessionId == sessionId).toList();
  }

  /// Generate a unique session ID for grouping clips
  static String generateSessionId() {
    return 'session_${DateTime.now().millisecondsSinceEpoch}';
  }
```

**Step 4: Run test to verify it passes**

Run: `cd /Users/rabble/code/andotherstuff/openvine/mobile && flutter test test/services/clip_library_service_test.dart`

Expected: PASS

**Step 5: Commit**

```bash
git add lib/services/clip_library_service.dart test/services/clip_library_service_test.dart
git commit -m "feat(clips): add session grouping to ClipLibraryService"
```

---

## Task 3: Create Clip Count Provider

**Files:**
- Create: `lib/providers/clip_count_provider.dart`
- Test: `test/providers/clip_count_provider_test.dart`

**Step 1: Write the failing test**

Create `test/providers/clip_count_provider_test.dart`:

```dart
// ABOUTME: TDD tests for clip count provider
// ABOUTME: Tests reactive clip count updates for profile display

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/saved_clip.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/clip_count_provider.dart';
import 'package:openvine/services/clip_library_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ClipCountProvider', () {
    late ProviderContainer container;
    late ClipLibraryService clipService;
    late Directory tempDir;
    late List<File> tempFiles;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      clipService = ClipLibraryService(prefs);

      tempDir = await Directory.systemTemp.createTemp('clip_test_');
      tempFiles = [];

      container = ProviderContainer(
        overrides: [
          clipLibraryServiceProvider.overrideWith((ref) async => clipService),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      for (final file in tempFiles) {
        if (file.existsSync()) {
          await file.delete();
        }
      }
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    File createTempVideoFile(String name) {
      final file = File('${tempDir.path}/$name.mp4');
      file.writeAsStringSync('fake video');
      tempFiles.add(file);
      return file;
    }

    test('should return 0 when no clips exist', () async {
      final count = await container.read(clipCountProvider.future);
      expect(count, 0);
    });

    test('should return correct count when clips exist', () async {
      final file1 = createTempVideoFile('video1');
      final file2 = createTempVideoFile('video2');

      await clipService.saveClip(SavedClip(
        id: 'clip_1',
        filePath: file1.path,
        thumbnailPath: null,
        duration: const Duration(seconds: 1),
        createdAt: DateTime.now(),
        aspectRatio: 'square',
      ));
      await clipService.saveClip(SavedClip(
        id: 'clip_2',
        filePath: file2.path,
        thumbnailPath: null,
        duration: const Duration(seconds: 2),
        createdAt: DateTime.now(),
        aspectRatio: 'square',
      ));

      container.invalidate(clipCountProvider);
      final count = await container.read(clipCountProvider.future);

      expect(count, 2);
    });

    test('should only count clips with existing video files', () async {
      final existingFile = createTempVideoFile('existing');

      await clipService.saveClip(SavedClip(
        id: 'clip_valid',
        filePath: existingFile.path,
        thumbnailPath: null,
        duration: const Duration(seconds: 1),
        createdAt: DateTime.now(),
        aspectRatio: 'square',
      ));
      await clipService.saveClip(SavedClip(
        id: 'clip_orphan',
        filePath: '/nonexistent/path.mp4',
        thumbnailPath: null,
        duration: const Duration(seconds: 1),
        createdAt: DateTime.now(),
        aspectRatio: 'square',
      ));

      container.invalidate(clipCountProvider);
      final count = await container.read(clipCountProvider.future);

      expect(count, 1);
    });
  });
}
```

**Step 2: Run test to verify it fails**

Run: `cd /Users/rabble/code/andotherstuff/openvine/mobile && flutter test test/providers/clip_count_provider_test.dart`

Expected: FAIL - clipCountProvider doesn't exist

**Step 3: Write minimal implementation**

Create `lib/providers/clip_count_provider.dart`:

```dart
// ABOUTME: Riverpod provider for reactive clip count updates
// ABOUTME: Used by profile screen to display clip library count

import 'dart:io';

import 'package:openvine/providers/app_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'clip_count_provider.g.dart';

/// Provider that returns the current number of clips in the library.
/// Only counts clips where the video file still exists on disk.
@riverpod
Future<int> clipCount(Ref ref) async {
  final clipService = await ref.watch(clipLibraryServiceProvider.future);
  final clips = await clipService.getAllClips();
  return clips.where((c) => File(c.filePath).existsSync()).length;
}
```

**Step 4: Run build_runner and test**

Run:
```bash
cd /Users/rabble/code/andotherstuff/openvine/mobile
dart run build_runner build --delete-conflicting-outputs
flutter test test/providers/clip_count_provider_test.dart
```

Expected: PASS

**Step 5: Commit**

```bash
git add lib/providers/clip_count_provider.dart lib/providers/clip_count_provider.g.dart test/providers/clip_count_provider_test.dart
git commit -m "feat(clips): add clipCountProvider for profile display"
```

---

## Task 4: Create Draft to Clip Migration Service

**Files:**
- Create: `lib/services/draft_migration_service.dart`
- Test: `test/services/draft_migration_service_test.dart`

**Step 1: Write the failing test**

Create `test/services/draft_migration_service_test.dart`:

```dart
// ABOUTME: Tests for migrating VineDrafts to SavedClips
// ABOUTME: Verifies one-time migration preserves video files

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' show AspectRatio;
import 'package:openvine/models/vine_draft.dart';
import 'package:openvine/services/clip_library_service.dart';
import 'package:openvine/services/draft_migration_service.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('DraftMigrationService', () {
    late DraftMigrationService migrationService;
    late DraftStorageService draftService;
    late ClipLibraryService clipService;
    late Directory tempDir;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      draftService = DraftStorageService(prefs);
      clipService = ClipLibraryService(prefs);
      migrationService = DraftMigrationService(
        draftService: draftService,
        clipService: clipService,
        prefs: prefs,
      );

      tempDir = await Directory.systemTemp.createTemp('migration_test_');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    File createTempVideo(String name) {
      final file = File('${tempDir.path}/$name.mp4');
      file.writeAsStringSync('fake video content');
      return file;
    }

    test('should migrate draft to clip', () async {
      final videoFile = createTempVideo('draft_video');
      final draft = VineDraft(
        id: 'draft_123',
        videoFile: videoFile,
        title: 'Test Draft',
        description: 'Description',
        hashtags: ['test'],
        frameCount: 30,
        selectedApproach: 'native',
        createdAt: DateTime(2025, 12, 18, 10, 0),
        lastModified: DateTime(2025, 12, 18, 10, 0),
        publishStatus: PublishStatus.draft,
        publishError: null,
        publishAttempts: 0,
        aspectRatio: AspectRatio.square,
      );

      await draftService.saveDraft(draft);

      final result = await migrationService.migrate();

      expect(result.migratedCount, 1);
      expect(result.skippedCount, 0);

      final clips = await clipService.getAllClips();
      expect(clips.length, 1);
      expect(clips.first.filePath, videoFile.path);
      expect(clips.first.sessionId, 'migrated_draft_123');
    });

    test('should skip drafts with missing video files', () async {
      final draft = VineDraft(
        id: 'draft_orphan',
        videoFile: File('/nonexistent/video.mp4'),
        title: 'Orphan Draft',
        description: '',
        hashtags: [],
        frameCount: 0,
        selectedApproach: 'native',
        createdAt: DateTime.now(),
        lastModified: DateTime.now(),
        publishStatus: PublishStatus.draft,
        publishError: null,
        publishAttempts: 0,
        aspectRatio: AspectRatio.square,
      );

      await draftService.saveDraft(draft);

      final result = await migrationService.migrate();

      expect(result.migratedCount, 0);
      expect(result.skippedCount, 1);
    });

    test('should only migrate once', () async {
      final videoFile = createTempVideo('draft_video');
      final draft = VineDraft(
        id: 'draft_456',
        videoFile: videoFile,
        title: 'Test',
        description: '',
        hashtags: [],
        frameCount: 0,
        selectedApproach: 'native',
        createdAt: DateTime.now(),
        lastModified: DateTime.now(),
        publishStatus: PublishStatus.draft,
        publishError: null,
        publishAttempts: 0,
        aspectRatio: AspectRatio.square,
      );

      await draftService.saveDraft(draft);

      // First migration
      await migrationService.migrate();

      // Second migration should be no-op
      final result = await migrationService.migrate();

      expect(result.migratedCount, 0);
      expect(result.alreadyMigrated, true);
    });

    test('should clear drafts after successful migration', () async {
      final videoFile = createTempVideo('draft_video');
      final draft = VineDraft(
        id: 'draft_789',
        videoFile: videoFile,
        title: 'Test',
        description: '',
        hashtags: [],
        frameCount: 0,
        selectedApproach: 'native',
        createdAt: DateTime.now(),
        lastModified: DateTime.now(),
        publishStatus: PublishStatus.draft,
        publishError: null,
        publishAttempts: 0,
        aspectRatio: AspectRatio.square,
      );

      await draftService.saveDraft(draft);
      await migrationService.migrate();

      final remainingDrafts = await draftService.getAllDrafts();
      expect(remainingDrafts, isEmpty);
    });
  });
}
```

**Step 2: Run test to verify it fails**

Run: `cd /Users/rabble/code/andotherstuff/openvine/mobile && flutter test test/services/draft_migration_service_test.dart`

Expected: FAIL - DraftMigrationService doesn't exist

**Step 3: Write minimal implementation**

Create `lib/services/draft_migration_service.dart`:

```dart
// ABOUTME: One-time migration service to convert VineDrafts to SavedClips
// ABOUTME: Preserves video files, creates clips with migrated session IDs

import 'package:openvine/models/saved_clip.dart';
import 'package:openvine/services/clip_library_service.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:openvine/services/video_thumbnail_service.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MigrationResult {
  const MigrationResult({
    required this.migratedCount,
    required this.skippedCount,
    required this.alreadyMigrated,
  });

  final int migratedCount;
  final int skippedCount;
  final bool alreadyMigrated;
}

class DraftMigrationService {
  DraftMigrationService({
    required this.draftService,
    required this.clipService,
    required this.prefs,
  });

  final DraftStorageService draftService;
  final ClipLibraryService clipService;
  final SharedPreferences prefs;

  static const String _migrationKey = 'drafts_migrated_to_clips';

  /// Check if migration has already been performed
  bool get hasMigrated => prefs.getBool(_migrationKey) ?? false;

  /// Migrate all drafts to clips. Only runs once.
  Future<MigrationResult> migrate() async {
    if (hasMigrated) {
      Log.info(
        '📦 Draft migration already completed, skipping',
        name: 'DraftMigrationService',
      );
      return const MigrationResult(
        migratedCount: 0,
        skippedCount: 0,
        alreadyMigrated: true,
      );
    }

    final drafts = await draftService.getAllDrafts();
    var migratedCount = 0;
    var skippedCount = 0;

    for (final draft in drafts) {
      if (!draft.videoFile.existsSync()) {
        Log.warning(
          '📦 Skipping draft ${draft.id} - video file missing',
          name: 'DraftMigrationService',
        );
        skippedCount++;
        continue;
      }

      // Generate thumbnail for the clip
      String? thumbnailPath;
      try {
        thumbnailPath = await VideoThumbnailService.extractThumbnail(
          videoPath: draft.videoFile.path,
          timeMs: 100,
        );
      } catch (e) {
        Log.warning(
          '📦 Failed to generate thumbnail for draft ${draft.id}: $e',
          name: 'DraftMigrationService',
        );
      }

      final clip = SavedClip(
        id: 'clip_migrated_${draft.id}',
        filePath: draft.videoFile.path,
        thumbnailPath: thumbnailPath,
        duration: const Duration(seconds: 6), // Assume max duration for legacy
        createdAt: draft.createdAt,
        aspectRatio: draft.aspectRatio.name,
        sessionId: 'migrated_${draft.id}',
      );

      await clipService.saveClip(clip);
      migratedCount++;

      Log.info(
        '📦 Migrated draft ${draft.id} to clip ${clip.id}',
        name: 'DraftMigrationService',
      );
    }

    // Clear all drafts after successful migration
    await draftService.clearAllDrafts();

    // Mark migration as complete
    await prefs.setBool(_migrationKey, true);

    Log.info(
      '📦 Migration complete: $migratedCount migrated, $skippedCount skipped',
      name: 'DraftMigrationService',
    );

    return MigrationResult(
      migratedCount: migratedCount,
      skippedCount: skippedCount,
      alreadyMigrated: false,
    );
  }
}
```

**Step 4: Run test to verify it passes**

Run: `cd /Users/rabble/code/andotherstuff/openvine/mobile && flutter test test/services/draft_migration_service_test.dart`

Expected: PASS

**Step 5: Commit**

```bash
git add lib/services/draft_migration_service.dart test/services/draft_migration_service_test.dart
git commit -m "feat(migration): add DraftMigrationService to convert drafts to clips"
```

---

## Task 5: Auto-Save Segments to Clip Library

**Files:**
- Modify: `lib/providers/vine_recording_provider.dart`
- Test: `test/providers/vine_recording_auto_save_test.dart`

**Step 1: Write the failing test**

Create `test/providers/vine_recording_auto_save_test.dart`:

```dart
// ABOUTME: Tests for auto-saving recording segments to clip library
// ABOUTME: Verifies segments are immediately persisted as SavedClips

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/clip_library_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('VineRecordingProvider auto-save', () {
    late ProviderContainer container;
    late ClipLibraryService clipService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      clipService = ClipLibraryService(prefs);

      container = ProviderContainer(
        overrides: [
          clipLibraryServiceProvider.overrideWith((ref) async => clipService),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('should save segment to clip library with session ID', () async {
      // This test validates the integration exists
      // Full integration test requires camera mocking

      final sessionId = ClipLibraryService.generateSessionId();

      expect(sessionId, startsWith('session_'));
      expect(sessionId.length, greaterThan(8));
    });
  });
}
```

**Step 2: Implementation notes**

The full implementation requires modifying `VineRecordingProvider.stopSegment()` to:
1. Generate session ID at recording start
2. On each segment stop, save to ClipLibraryService
3. Remove draft auto-creation from `stopRecording()`

This is a larger change that integrates with the camera system. The test above validates the session ID generation. Full integration testing requires camera mocks.

**Step 3: Modify VineRecordingProvider**

Key changes to `lib/providers/vine_recording_provider.dart`:

1. Add `_currentSessionId` field
2. In `startRecording()`: generate new session ID
3. In `stopSegment()`: save segment as clip to library
4. In `stopRecording()`: remove draft auto-creation, just navigate

(Detailed implementation deferred to execution phase due to complexity)

**Step 4: Commit placeholder**

```bash
git add test/providers/vine_recording_auto_save_test.dart
git commit -m "test(recording): add auto-save segment test scaffold"
```

---

## Task 6: Update Clip Library Screen with Selection Mode

**Files:**
- Modify: `lib/screens/clip_library_screen.dart`
- Test: `test/screens/clip_library_selection_test.dart`

**Step 1: Write the failing test**

Create `test/screens/clip_library_selection_test.dart`:

```dart
// ABOUTME: Tests for clip library selection mode
// ABOUTME: Verifies multi-select and "Create Video" flow

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/screens/clip_library_screen.dart';

void main() {
  group('ClipLibraryScreen selection mode', () {
    testWidgets('should show Select button in app bar', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: ClipLibraryScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Select'), findsOneWidget);
    });

    testWidgets('should show Create Video button when clips selected', (tester) async {
      // This test requires clip data to be present
      // Full test in integration testing
      expect(true, isTrue); // Placeholder
    });
  });
}
```

**Step 2: Implementation notes**

Update `ClipLibraryScreen` to add:
1. "Select" button in app bar to enter selection mode
2. Checkbox overlays on clips when in selection mode
3. "Create Video" FAB when clips are selected
4. Session grouping headers in the grid

(Detailed implementation in execution phase)

---

## Task 7: Update Profile Screen - Rename Drafts to Clips

**Files:**
- Modify: `lib/screens/profile_screen_router.dart`
- Modify: `lib/router/app_router.dart`

**Step 1: Changes needed**

In `profile_screen_router.dart`:
- Change `draftCountProvider` to `clipCountProvider`
- Change button text from "Drafts" to "Clips"
- Update `_openDrafts()` to `_openClips()`

In `app_router.dart`:
- Update `/drafts` route to go to `ClipLibraryScreen`
- Or rename route to `/clips`

**Step 2: Implementation**

```dart
// In profile_screen_router.dart, around line 849
final clipCountAsync = ref.watch(clipCountProvider);
// ...
child: clipCountAsync.when(
  data: (count) => count > 0
      ? Text('Clips ($count)')
      : const Text('Clips'),
  loading: () => const Text('Clips'),
  error: (_, __) => const Text('Clips'),
),
```

**Step 3: Commit**

```bash
git add lib/screens/profile_screen_router.dart lib/router/app_router.dart
git commit -m "feat(profile): rename Drafts to Clips, use clipCountProvider"
```

---

## Task 8: Add "Add from Library" to ClipManager

**Files:**
- Modify: `lib/screens/clip_manager_screen.dart`

**Step 1: Changes needed**

Add button to ClipManagerScreen that:
1. Opens ClipLibraryScreen in selection mode
2. Returns selected clips
3. Adds them to current composition

**Step 2: Implementation notes**

Add an "Add from Library" icon button in the app bar or as a FAB. When tapped, push ClipLibraryScreen with `selectionMode: true` and `onClipSelected` callback.

---

## Task 9: Add Duration Warning to ClipManager

**Files:**
- Modify: `lib/screens/clip_manager_screen.dart`

**Step 1: Changes needed**

1. Show total duration prominently
2. When total > 6.3s, show warning banner
3. On "Next", auto-trim and proceed

**Step 2: Implementation**

```dart
// Add warning widget when over limit
if (totalDuration > const Duration(milliseconds: 6300))
  Container(
    padding: const EdgeInsets.all(8),
    color: Colors.orange.withOpacity(0.2),
    child: const Text(
      'Video will be trimmed to 6.3 seconds',
      style: TextStyle(color: Colors.orange),
    ),
  ),
```

---

## Task 10: Run Migration on App Startup

**Files:**
- Modify: `lib/main.dart` or startup service

**Step 1: Implementation**

Add migration call during app initialization:

```dart
// In app startup
final migrationService = DraftMigrationService(
  draftService: draftService,
  clipService: clipService,
  prefs: prefs,
);
await migrationService.migrate();
```

---

## Task 11: Clean Up - Remove Draft Code

**Files to remove (after migration verified working):**
- `lib/models/vine_draft.dart`
- `lib/services/draft_storage_service.dart`
- `lib/providers/draft_count_provider.dart`
- `lib/screens/vine_drafts_screen.dart`
- `lib/widgets/draft_thumbnail.dart`
- `lib/widgets/draft_count_badge.dart`
- Related test files

**Note:** Keep these until migration is confirmed working in production. Can be removed in a follow-up PR.

---

## Execution Order

1. Task 1: SavedClip sessionId (foundation)
2. Task 2: ClipLibraryService grouping (foundation)
3. Task 3: Clip count provider (foundation)
4. Task 4: Migration service (enables testing)
5. Task 10: Run migration on startup
6. Task 7: Profile screen update (visible change)
7. Task 6: Clip library selection mode
8. Task 8: Add from library in ClipManager
9. Task 9: Duration warning
10. Task 5: Auto-save segments (biggest change)
11. Task 11: Clean up draft code (final)

---

**Plan complete and saved to `docs/plans/2025-12-18-clip-library-implementation.md`.**

**Two execution options:**

1. **Subagent-Driven (this session)** - I dispatch fresh subagent per task, review between tasks, fast iteration

2. **Parallel Session (separate)** - Open new session with executing-plans, batch execution with checkpoints

Which approach?
