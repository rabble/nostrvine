// ABOUTME: Contract tests for the shared test environment in test_setup.dart
// ABOUTME: Pins the per-process path_provider isolation that keeps concurrent
// ABOUTME: very_good test processes off each other's Hive boxes and databases

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  group('path_provider isolation', () {
    // `very_good test --optimization` runs the merged bundle and every
    // VGV-skip-tagged file as separate concurrent processes. A fixed path here
    // put all of them on the same Hive boxes and database files on disk.
    final processMarker = 'divine_test_${pid}_';

    test(
      'resolves the app directories under a per-process temp root',
      () async {
        final documents = await getApplicationDocumentsDirectory();
        final support = await getApplicationSupportDirectory();
        final temporary = await getTemporaryDirectory();

        for (final directory in [documents, support, temporary]) {
          expect(
            directory.path,
            contains(processMarker),
            reason:
                'path_provider must resolve under a root keyed on the process '
                'id, or concurrent test processes share files on disk',
          );
          expect(directory.existsSync(), isTrue);
        }

        expect(
          {documents.path, support.path, temporary.path},
          hasLength(3),
          reason: 'documents, support and temporary must not be the same dir',
        );
      },
    );

    test(
      'the raw MethodChannel agrees with PathProviderPlatform.instance',
      () async {
        const channel = MethodChannel('plugins.flutter.io/path_provider');

        Future<String?> viaChannel(String method) =>
            channel.invokeMethod<String>(method);

        expect(
          await viaChannel('getApplicationDocumentsDirectory'),
          (await getApplicationDocumentsDirectory()).path,
        );
        expect(
          await viaChannel('getApplicationSupportDirectory'),
          (await getApplicationSupportDirectory()).path,
        );
        expect(
          await viaChannel('getTemporaryDirectory'),
          (await getTemporaryDirectory()).path,
        );
      },
    );
  });
}
