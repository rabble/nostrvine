// ABOUTME: Pins Hive's home path to one directory regardless of open order
// ABOUTME: Covers migration of boxes stranded in the legacy documents directory

// Permanent: mutates PathProviderPlatform.instance and Hive's process-global
// home path while validating where box files land.
@Tags(['skip_very_good_optimization'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:openvine/constants/hive_box_names.dart';
import 'package:openvine/services/hive_storage_service.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _FakePathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  _FakePathProviderPlatform({
    required this.documentsPath,
    required this.appSupportPath,
  });

  final String documentsPath;
  final String appSupportPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;

  @override
  Future<String?> getApplicationSupportPath() async => appSupportPath;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(HiveStorageService, () {
    late Directory root;
    late Directory documentsDir;
    late Directory appSupportDir;
    late String homePath;
    late PathProviderPlatform originalPathProvider;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('hive_storage_service_');
      documentsDir = await Directory(
        p.join(root.path, 'Documents'),
      ).create(recursive: true);
      appSupportDir = await Directory(
        p.join(root.path, 'app_support'),
      ).create(recursive: true);
      homePath = p.join(
        appSupportDir.path,
        HiveStorageService.homeDirectoryName,
      );

      originalPathProvider = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _FakePathProviderPlatform(
        documentsPath: documentsDir.path,
        appSupportPath: appSupportDir.path,
      );

      HiveStorageService.resetForTesting();
    });

    tearDown(() async {
      await Hive.close();
      PathProviderPlatform.instance = originalPathProvider;
      HiveStorageService.resetForTesting();
      if (root.existsSync()) root.deleteSync(recursive: true);
    });

    test('opens boxes under the Application Support home directory', () async {
      await HiveStorageService.initialize();

      final box = await Hive.openBox<dynamic>(HiveBoxNames.notifications);

      expect(p.dirname(box.path!), homePath);
    });

    test('repeat initialization does not reassign the home path', () async {
      await HiveStorageService.initialize();
      final firstBox = await Hive.openBox<dynamic>(HiveBoxNames.notifications);

      final elsewhere = await Directory(
        p.join(root.path, 'elsewhere'),
      ).create(recursive: true);
      PathProviderPlatform.instance = _FakePathProviderPlatform(
        documentsPath: elsewhere.path,
        appSupportPath: elsewhere.path,
      );

      await HiveStorageService.initialize();
      final secondBox = await Hive.openBox<dynamic>(HiveBoxNames.hashtagStats);

      expect(p.dirname(secondBox.path!), p.dirname(firstBox.path!));
    });

    test(
      'moves a box stranded in the documents directory into the home',
      () async {
        _writeBoxFile(documentsDir, HiveBoxNames.notifications, 'stranded');

        await HiveStorageService.initialize();

        expect(
          _readBoxFile(Directory(homePath), HiveBoxNames.notifications),
          'stranded',
        );
        expect(
          _boxFile(documentsDir, HiveBoxNames.notifications).existsSync(),
          isFalse,
        );
      },
    );

    test('keeps the more recently written copy of a split box', () async {
      const boxName = HiveBoxNames.pushNotificationPreferencesDirty;
      await Directory(homePath).create(recursive: true);

      _writeBoxFile(
        documentsDir,
        boxName,
        'documents',
        modified: DateTime(2026, 8, 12),
      );
      _writeBoxFile(
        Directory(homePath),
        boxName,
        'home',
        modified: DateTime(2026, 8, 10),
      );

      await HiveStorageService.initialize();

      expect(_readBoxFile(Directory(homePath), boxName), 'documents');
      expect(_boxFile(documentsDir, boxName).existsSync(), isFalse);
    });

    test('drops the stranded copy when the home copy is newer', () async {
      const boxName = HiveBoxNames.pushNotificationPreferencesDirty;
      await Directory(homePath).create(recursive: true);

      _writeBoxFile(
        documentsDir,
        boxName,
        'documents',
        modified: DateTime(2026, 8, 10),
      );
      _writeBoxFile(
        Directory(homePath),
        boxName,
        'home',
        modified: DateTime(2026, 8, 12),
      );

      await HiveStorageService.initialize();

      expect(_readBoxFile(Directory(homePath), boxName), 'home');
      expect(_boxFile(documentsDir, boxName).existsSync(), isFalse);
    });

    test('rescues a stranded box left only as a compacted copy', () async {
      const boxName = HiveBoxNames.notifications;
      _writeCompactedBoxFile(documentsDir, boxName, 'compacted');

      await HiveStorageService.initialize();

      expect(_readBoxFile(Directory(homePath), boxName), 'compacted');
      expect(_compactedBoxFile(documentsDir, boxName).existsSync(), isFalse);
    });

    test('leaves no compacted leftover in the legacy home', () async {
      const boxName = HiveBoxNames.pushNotificationPreferencesDirty;
      await Directory(homePath).create(recursive: true);

      // A crashed compaction leaves the compacted copy beside the box file
      // Hive still prefers, on whichever side of the split it happened.
      _writeBoxFile(
        documentsDir,
        boxName,
        'documents',
        modified: DateTime(2026, 8, 10),
      );
      _writeCompactedBoxFile(documentsDir, boxName, 'documents compacted');
      _writeBoxFile(
        Directory(homePath),
        boxName,
        'home',
        modified: DateTime(2026, 8, 12),
      );

      await HiveStorageService.initialize();

      expect(_readBoxFile(Directory(homePath), boxName), 'home');
      expect(_boxFile(documentsDir, boxName).existsSync(), isFalse);
      expect(_compactedBoxFile(documentsDir, boxName).existsSync(), isFalse);
    });

    test('removes stranded lock files', () async {
      final lockFile = File(
        p.join(documentsDir.path, '${HiveBoxNames.personalEvents}.lock'),
      )..writeAsStringSync('');

      await HiveStorageService.initialize();

      expect(lockFile.existsSync(), isFalse);
    });
  });
}

File _boxFile(Directory dir, String boxName) =>
    File(p.join(dir.path, '$boxName.hive'));

/// Where compaction writes the compacted box before renaming it over the box
/// file, and what Hive restores from when the box file is missing.
File _compactedBoxFile(Directory dir, String boxName) =>
    File(p.join(dir.path, '$boxName.hivec'));

void _writeCompactedBoxFile(Directory dir, String boxName, String contents) =>
    _compactedBoxFile(dir, boxName).writeAsStringSync(contents);

void _writeBoxFile(
  Directory dir,
  String boxName,
  String contents, {
  DateTime? modified,
}) {
  final file = _boxFile(dir, boxName)..writeAsStringSync(contents);
  if (modified != null) file.setLastModifiedSync(modified);
}

String _readBoxFile(Directory dir, String boxName) =>
    _boxFile(dir, boxName).readAsStringSync();
