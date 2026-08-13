// ABOUTME: Unit tests for ClipCategoriesDao CRUD and clip-unfiling behaviour.
// ABOUTME: Covers ordering, per-account isolation, and delete cascade rules.

import 'dart:io';

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late ClipCategoriesDao dao;
  late ClipsDao clipsDao;
  late String tempDbPath;

  const ownerA =
      'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2';
  const ownerB =
      'b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3';

  setUp(() async {
    final tempDir = Directory.systemTemp.createTempSync('clip_categories_dao_');
    tempDbPath = '${tempDir.path}/test.db';
    database = AppDatabase.test(NativeDatabase(File(tempDbPath)));
    dao = database.clipCategoriesDao;
    clipsDao = database.clipsDao;
  });

  tearDown(() async {
    await database.close();
    final file = File(tempDbPath);
    if (file.existsSync()) file.deleteSync();
  });

  Future<void> insertCategory(
    String id, {
    String name = 'Travel',
    int orderIndex = 0,
    String? ownerPubkey,
  }) {
    return dao.upsertCategory(
      id: id,
      name: name,
      createdAt: DateTime(2026, 3, 5),
      orderIndex: orderIndex,
      ownerPubkey: ownerPubkey,
    );
  }

  Future<void> insertLibraryClip(String id, {String? categoryId}) async {
    await clipsDao.upsertClip(
      id: id,
      orderIndex: 0,
      durationMs: 3000,
      recordedAt: DateTime(2026, 3, 5),
      data: '{}',
      filePath: '$id.mp4',
      thumbnailPath: null,
    );
    if (categoryId != null) {
      await clipsDao.setClipCategory(id: id, categoryId: categoryId);
    }
  }

  group(ClipCategoriesDao, () {
    group('getCategories', () {
      test('returns categories ordered by orderIndex', () async {
        await insertCategory('cat-b', name: 'B', orderIndex: 2);
        await insertCategory('cat-a', name: 'A', orderIndex: 1);

        final categories = await dao.getCategories();

        expect(categories.map((c) => c.id), ['cat-a', 'cat-b']);
      });

      test(
        'scopes to the owner and keeps legacy rows without an owner',
        () async {
          await insertCategory('cat-a', ownerPubkey: ownerA);
          await insertCategory('cat-b', ownerPubkey: ownerB);
          await insertCategory('cat-legacy');

          final categories = await dao.getCategories(ownerPubkey: ownerA);

          expect(
            categories.map((c) => c.id),
            unorderedEquals(['cat-a', 'cat-legacy']),
          );
        },
      );
    });

    group('upsertCategory', () {
      test('updates an existing row instead of duplicating it', () async {
        await insertCategory('cat-a');
        await insertCategory('cat-a', name: 'Trips');

        final categories = await dao.getCategories();

        expect(categories, hasLength(1));
        expect(categories.single.name, 'Trips');
      });
    });

    group('renameCategory', () {
      test('renames an existing category', () async {
        await insertCategory('cat-a');

        final renamed = await dao.renameCategory(id: 'cat-a', name: 'Trips');

        expect(renamed, isTrue);
        final categories = await dao.getCategories();
        expect(categories.single.name, 'Trips');
      });

      test('reports false for an unknown category', () async {
        expect(await dao.renameCategory(id: 'missing', name: 'X'), isFalse);
      });
    });

    group('deleteCategory', () {
      test('keeps the clips and unfiles them', () async {
        await insertCategory('cat-a');
        await insertLibraryClip('clip-1', categoryId: 'cat-a');
        await insertLibraryClip('clip-2', categoryId: 'cat-a');

        final deleted = await dao.deleteCategory('cat-a');

        expect(deleted, isTrue);
        expect(await dao.getCategories(), isEmpty);
        final clips = await clipsDao.getLibraryClips();
        expect(clips, hasLength(2));
        expect(clips.every((c) => c.categoryId == null), isTrue);
      });

      test('leaves clips of other categories filed', () async {
        await insertCategory('cat-a');
        await insertCategory('cat-b', name: 'Food');
        await insertLibraryClip('clip-1', categoryId: 'cat-a');
        await insertLibraryClip('clip-2', categoryId: 'cat-b');

        await dao.deleteCategory('cat-a');

        final clips = await clipsDao.getLibraryClips();
        final byId = {for (final c in clips) c.id: c};
        expect(byId['clip-1']?.categoryId, null);
        expect(byId['clip-2']?.categoryId, 'cat-b');
      });

      test('reports false for an unknown category', () async {
        expect(await dao.deleteCategory('missing'), isFalse);
      });
    });

    group('highestOrderIndex', () {
      test('returns null when the account has no categories', () async {
        expect(await dao.highestOrderIndex(ownerPubkey: ownerA), null);
      });

      test('returns the highest index in use', () async {
        await insertCategory('cat-a', ownerPubkey: ownerA);
        await insertCategory('cat-b', orderIndex: 7, ownerPubkey: ownerA);

        expect(await dao.highestOrderIndex(ownerPubkey: ownerA), 7);
      });
    });

    group('deleteAllForUser', () {
      test(
        'drops owned categories, unfiles their clips, keeps legacy rows',
        () async {
          await insertCategory('cat-a', ownerPubkey: ownerA);
          await insertCategory('cat-legacy');
          await insertLibraryClip('clip-1', categoryId: 'cat-a');

          final deleted = await dao.deleteAllForUser(ownerA);

          expect(deleted, 1);
          expect((await dao.getCategories()).map((c) => c.id), ['cat-legacy']);
          final clips = await clipsDao.getLibraryClips();
          expect(clips.single.categoryId, null);
        },
      );
    });

    group('claimLegacyRows', () {
      test('attributes ownerless categories to the new owner', () async {
        await insertCategory('cat-legacy');
        await insertCategory('cat-b', ownerPubkey: ownerB);

        final claimed = await dao.claimLegacyRows(ownerA);

        expect(claimed, 1);
        final categories = await dao.getCategories();
        final byId = {for (final category in categories) category.id: category};
        expect(byId['cat-legacy']?.ownerPubkey, ownerA);
        expect(byId['cat-b']?.ownerPubkey, ownerB);
      });
    });
  });

  group('ClipsDao category and archive columns', () {
    test('setClipCategory files and unfiles a clip', () async {
      await insertCategory('cat-a');
      await insertLibraryClip('clip-1');

      await clipsDao.setClipCategory(id: 'clip-1', categoryId: 'cat-a');
      expect((await clipsDao.getClipById('clip-1'))?.categoryId, 'cat-a');

      await clipsDao.setClipCategory(id: 'clip-1', categoryId: null);
      expect((await clipsDao.getClipById('clip-1'))?.categoryId, null);
    });

    test('setClipArchived sets and clears the marker', () async {
      await insertLibraryClip('clip-1');
      final archivedAt = DateTime(2026, 3, 2);

      await clipsDao.setClipArchived(id: 'clip-1', archivedAt: archivedAt);
      expect((await clipsDao.getClipById('clip-1'))?.archivedAt, archivedAt);

      await clipsDao.setClipArchived(id: 'clip-1', archivedAt: null);
      expect((await clipsDao.getClipById('clip-1'))?.archivedAt, null);
    });

    test(
      'upsertClip preserves an existing category and archive marker',
      () async {
        await insertCategory('cat-a');
        await insertLibraryClip('clip-1', categoryId: 'cat-a');
        await clipsDao.setClipArchived(
          id: 'clip-1',
          archivedAt: DateTime(2026, 3, 2),
        );

        // Mirrors ClipLibraryService.saveClip re-writing a clip after asset
        // recovery: it must not silently unfile or unarchive the clip.
        await clipsDao.upsertClip(
          id: 'clip-1',
          orderIndex: 0,
          durationMs: 4000,
          recordedAt: DateTime(2026, 3, 5),
          data: '{"recovered":true}',
          filePath: 'clip-1.mp4',
          thumbnailPath: 'clip-1.jpg',
        );

        final row = await clipsDao.getClipById('clip-1');
        expect(row?.categoryId, 'cat-a');
        expect(row?.archivedAt, DateTime(2026, 3, 2));
        expect(row?.thumbnailPath, 'clip-1.jpg');
      },
    );

    test(
      'setClipCategory can clear the archive marker in the same write',
      () async {
        await insertCategory('cat-a');
        await insertLibraryClip('clip-1');
        await clipsDao.setClipArchived(
          id: 'clip-1',
          archivedAt: DateTime(2026, 3, 2),
        );

        await clipsDao.setClipCategory(
          id: 'clip-1',
          categoryId: 'cat-a',
          clearArchived: true,
        );

        final row = await clipsDao.getClipById('clip-1');
        expect(row?.categoryId, 'cat-a');
        expect(row?.archivedAt, null);
      },
    );

    test(
      'setClipCategory leaves the archive marker alone by default',
      () async {
        await insertLibraryClip('clip-1');
        await clipsDao.setClipArchived(
          id: 'clip-1',
          archivedAt: DateTime(2026, 3, 2),
        );

        await clipsDao.setClipCategory(id: 'clip-1', categoryId: null);

        final row = await clipsDao.getClipById('clip-1');
        expect(row?.archivedAt, DateTime(2026, 3, 2));
      },
    );
  });
}
