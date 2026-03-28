import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/nip05_verification_provider.dart';

import 'test_provider_overrides.dart';

void main() {
  group('getStandardTestOverrides', () {
    test('overrides nip05 verification service by default', () {
      final container = ProviderContainer(
        overrides: [
          ...getStandardTestOverrides(),
          databaseProvider.overrideWith(
            (ref) => throw StateError('database should not be read'),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(
        () => container.read(nip05VerificationServiceProvider),
        returnsNormally,
      );
    });
  });
}
