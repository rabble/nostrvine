// ABOUTME: Tests the 18+ verification gate for dashboard-configured featured tabs.
// ABOUTME: Unverified and still-loading viewers fail closed until verification resolves.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/providers/featured_tabs_providers.dart';
import 'package:openvine/providers/moderation_providers.dart';
import 'package:openvine/services/age_verification_service.dart';

class _MockAgeVerificationService extends Mock
    implements AgeVerificationService {}

void main() {
  late _MockAgeVerificationService ageVerificationService;

  setUp(() {
    ageVerificationService = _MockAgeVerificationService();
    when(() => ageVerificationService.initialized).thenAnswer((_) async {});
    when(() => ageVerificationService.isAdultContentVerified).thenReturn(false);
  });

  ProviderContainer createContainer() {
    final container = ProviderContainer(
      overrides: [
        ageVerificationServiceProvider.overrideWithValue(
          ageVerificationService,
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('featuredTabAgeGateProvider', () {
    test('gates while persisted adult verification is loading', () {
      final container = createContainer();

      expect(container.read(featuredTabAgeGateProvider), isTrue);
    });

    test('gates a viewer without 18+ verification', () async {
      final container = createContainer();

      await container.read(featuredTabViewerIsAdultProvider.future);

      expect(container.read(featuredTabAgeGateProvider), isTrue);
    });

    test('does not gate an 18+ verified viewer', () async {
      when(
        () => ageVerificationService.isAdultContentVerified,
      ).thenReturn(true);
      final container = createContainer();

      await container.read(featuredTabViewerIsAdultProvider.future);

      expect(container.read(featuredTabAgeGateProvider), isFalse);
    });

    test('recomputes when adult verification changes', () async {
      var verified = false;
      when(
        () => ageVerificationService.isAdultContentVerified,
      ).thenAnswer((_) => verified);
      final container = createContainer();
      await container.read(featuredTabViewerIsAdultProvider.future);
      expect(container.read(featuredTabAgeGateProvider), isTrue);

      verified = true;
      container
          .read(adultContentVerificationVersionProvider.notifier)
          .increment();
      await container.read(featuredTabViewerIsAdultProvider.future);

      expect(container.read(featuredTabAgeGateProvider), isFalse);
    });
  });
}
