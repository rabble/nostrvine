// ABOUTME: Tests for shared widget-test provider overrides.
// ABOUTME: Guards against real services leaking into unrelated widget tests.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/providers/nip05_verification_provider.dart';

import 'test_provider_overrides.dart';

void main() {
  test('standard overrides mock NIP-05 verification by default', () {
    final container = ProviderContainer(
      overrides: getStandardTestOverrides().cast(),
    );
    addTearDown(container.dispose);

    expect(
      container.read(nip05VerificationServiceProvider),
      isA<MockNip05VerificationService>(),
    );
  });
}
