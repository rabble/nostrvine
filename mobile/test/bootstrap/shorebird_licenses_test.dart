import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/bootstrap/shorebird_licenses.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('shorebirdLicenseEntries', () {
    test('loads both license choices under one updater package', () async {
      final entries = await shorebirdLicenseEntries(rootBundle).toList();

      expect(entries, hasLength(2));
      expect(
        entries.expand((entry) => entry.packages),
        everyElement('Shorebird updater'),
      );

      final texts = entries
          .map(
            (entry) =>
                entry.paragraphs.map((paragraph) => paragraph.text).join('\n'),
          )
          .toList();
      expect(texts, contains(contains('MIT License')));
      expect(
        texts,
        contains(
          allOf(
            contains('Apache License'),
            contains('Version 2.0, January 2004'),
          ),
        ),
      );
    });
  });

  group('registerShorebirdLicenses', () {
    tearDown(LicenseRegistry.reset);

    test('adds the updater licenses to the global registry', () async {
      registerShorebirdLicenses();

      final entries = await LicenseRegistry.licenses
          .where((entry) => entry.packages.contains('Shorebird updater'))
          .toList();

      expect(entries, hasLength(2));
    });
  });
}
