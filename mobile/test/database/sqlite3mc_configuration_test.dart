// ABOUTME: Guards native SQLite encryption dependency wiring.
// ABOUTME: Ensures sqlite3mc hooks stay active and plain SQLite providers stay out.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

void main() {
  group('SQLite3MultipleCiphers configuration', () {
    test('root pubspec selects sqlite3mc through package:sqlite3 hooks', () {
      final pubspec = _readYamlFile('pubspec.yaml');
      final hooks = pubspec['hooks'] as YamlMap?;
      final userDefines = hooks?['user_defines'] as YamlMap?;
      final sqlite3 = userDefines?['sqlite3'] as YamlMap?;

      expect(
        sqlite3?['source'],
        equals('sqlite3mc'),
        reason:
            'Native builds must use SQLite3MultipleCiphers, not plain SQLite.',
      );
    });

    test('plain SQLite native providers are not dependencies', () {
      for (final path in const [
        'pubspec.yaml',
        'packages/db_client/pubspec.yaml',
        'packages/cache_sync/pubspec.yaml',
      ]) {
        final names = _dependencyNames(_readYamlFile(path));
        expect(
          names,
          isNot(contains('sqlcipher_flutter_libs')),
          reason: '$path must not use the retired sqlite3 2.x SQLCipher path.',
        );
        expect(
          names,
          isNot(contains('sqlite3_flutter_libs')),
          reason: '$path must not link a competing plain SQLite provider.',
        );
        expect(
          names,
          isNot(contains('drift_flutter')),
          reason:
              '$path must not pull sqlite3_flutter_libs back in transitively.',
        );
      }
    });

    test('iOS SwiftPM lockfiles do not pin stale CSQLite', () {
      final xcodeProjectLockfile = [
        'ios/Runner.xcodeproj/project.xcworkspace/xcshareddata',
        'swiftpm',
        'Package.resolved',
      ].join('/');

      for (final path in [
        'ios/Runner.xcworkspace/xcshareddata/swiftpm/Package.resolved',
        xcodeProjectLockfile,
      ]) {
        final json =
            jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;
        final pins = json['pins'] as List<Object?>? ?? const [];
        final identities = pins
            .whereType<Map<String, Object?>>()
            .map((pin) => pin['identity'])
            .toSet();
        expect(
          identities,
          isNot(contains('csqlite')),
          reason: '$path must not retain the old simolus3/CSQLite SwiftPM pin.',
        );
      }
    });
  });
}

YamlMap _readYamlFile(String path) =>
    loadYaml(File(path).readAsStringSync()) as YamlMap;

Set<String> _dependencyNames(YamlMap pubspec) {
  final names = <String>{};
  for (final sectionName in const [
    'dependencies',
    'dev_dependencies',
    'dependency_overrides',
  ]) {
    final section = pubspec[sectionName];
    if (section is YamlMap) {
      names.addAll(section.keys.whereType<String>());
    }
  }
  return names;
}
