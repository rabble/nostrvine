import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Runner force-links SQLCipher for every app build configuration', () {
    final project = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();

    for (final config in ['Debug', 'Profile', 'Release']) {
      final block = _configBlocks(project, config).where(
        (block) =>
            block.contains('PRODUCT_BUNDLE_IDENTIFIER = co.openvine.app;'),
      );

      expect(
        block,
        hasLength(1),
        reason: '$config Runner config must exist exactly once',
      );
      final runnerConfig = block.single;
      expect(runnerConfig, contains('OTHER_LDFLAGS = ('));
      expect(runnerConfig, contains(r'"$(inherited)"'));
      expect(runnerConfig, contains('"-framework"'));
      expect(runnerConfig, contains('SQLCipher'));
    }
  });

  test('tracked SwiftPM lockfiles do not pin plain CSQLite', () {
    for (final path in [
      'ios/Runner.xcworkspace/xcshareddata/swiftpm/Package.resolved',
      'ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved',
    ]) {
      final packageResolved = File(path).readAsStringSync();
      expect(packageResolved, isNot(contains('simolus3/CSQLite')));
      expect(packageResolved, isNot(contains('"identity" : "csqlite"')));
    }
  });
}

List<String> _configBlocks(String project, String config) {
  final blocks = <String>[];
  final marker = '/* $config */ = {';
  final endMarker = 'name = $config;';
  var offset = 0;
  while (true) {
    final start = project.indexOf(marker, offset);
    if (start == -1) return blocks;
    final end = project.indexOf(endMarker, start);
    if (end == -1) return blocks;
    blocks.add(project.substring(start, end + endMarker.length));
    offset = end + endMarker.length;
  }
}
