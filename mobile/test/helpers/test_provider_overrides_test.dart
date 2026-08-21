// ABOUTME: Tests for shared widget-test provider overrides.
// ABOUTME: Guards against real services leaking into unrelated widget tests.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/providers/nip05_verification_provider.dart';
import 'package:openvine/providers/social_providers.dart';
import 'package:openvine/services/auth_service.dart';

import 'test_provider_overrides.dart';

class _FakeAuthService extends Fake implements AuthService {}

void main() {
  test('standard overrides give auth mocks a session-cleanup callback', () {
    final auth = MockAuthService();

    getStandardTestOverrides(mockAuthService: auth);

    final unregister = auth.registerBeforeSessionTeardownCallback(() async {});
    expect(unregister, isA<void Function()>());
    expect(unregister, returnsNormally);
  });

  test('standard overrides leave hand-written auth fakes alone', () {
    expect(
      () => getStandardTestOverrides(mockAuthService: _FakeAuthService()),
      returnsNormally,
    );
  });

  test('standard overrides keep analytics inert in unrelated tests', () {
    final container = ProviderContainer(
      overrides: getStandardTestOverrides().cast(),
    );
    addTearDown(container.dispose);

    expect(
      container.read(analyticsServiceProvider),
      isA<TestAnalyticsService>(),
    );
  });

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
