import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/bootstrap/font_licenses.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('bundledFontLicenseEntries', () {
    test(
      'yields one OFL entry per bundled font with its embedded copyright',
      () async {
        final entries = await bundledFontLicenseEntries(rootBundle).toList();

        expect(entries, hasLength(4));

        final textByFamily = <String, String>{
          for (final entry in entries)
            entry.packages.single: entry.paragraphs
                .map((paragraph) => paragraph.text)
                .join('\n'),
        };

        expect(
          textByFamily.keys,
          containsAll(<String>[
            'Inter',
            'Bricolage Grotesque',
            'Pacifico',
            'Chivo Mono',
          ]),
        );

        // Copyright year matches the copyright embedded in the shipped .ttf
        // (see #3659 / findings F16), not the newer upstream OFL.txt.
        expect(
          textByFamily['Inter'],
          allOf(
            contains('Copyright 2016 The Inter Project Authors'),
            contains('SIL Open Font License, Version 1.1'),
          ),
        );
        expect(
          textByFamily['Bricolage Grotesque'],
          allOf(
            contains('Copyright 2022 The Bricolage Grotesque Project Authors'),
            contains('SIL Open Font License, Version 1.1'),
          ),
        );
        expect(
          textByFamily['Pacifico'],
          allOf(
            contains('Copyright 2018 The Pacifico Project Authors'),
            contains('SIL Open Font License, Version 1.1'),
          ),
        );
        expect(
          textByFamily['Chivo Mono'],
          allOf(
            contains('Copyright 2018 The Chivo Project Authors'),
            contains('SIL Open Font License, Version 1.1'),
          ),
        );
      },
    );
  });

  group('registerBundledFontLicenses', () {
    // LicenseRegistry is process-global with no auto-reset between tests under
    // the VGV merged isolate; reset() keeps later suites clean.
    tearDown(LicenseRegistry.reset);

    test('adds each bundled font license to the global registry', () async {
      registerBundledFontLicenses();

      final registeredPackages = await LicenseRegistry.licenses
          .expand((entry) => entry.packages)
          .toSet();

      expect(
        registeredPackages,
        containsAll(<String>[
          'Inter',
          'Bricolage Grotesque',
          'Pacifico',
          'Chivo Mono',
        ]),
      );
    });
  });
}
