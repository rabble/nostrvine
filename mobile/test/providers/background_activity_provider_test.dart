// ABOUTME: Pins that one container yields one BackgroundActivityManager
// ABOUTME: The lifecycle driver and its registrants must share an instance

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/providers/background_activity_provider.dart';
import 'package:openvine/services/background_activity_manager.dart';

void main() {
  group('backgroundActivityManagerProvider', () {
    test('hands the same instance to every reader in one container', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // AppLifecycleHandler drives the manager; AuthService, UploadManager and
      // AnalyticsService register into it. If a rebuild ever handed those two
      // sides different instances, the lifecycle fan-out would reach an empty
      // registry and nothing would fail loudly — so pin it (#4743).
      expect(
        container.read(backgroundActivityManagerProvider),
        same(container.read(backgroundActivityManagerProvider)),
      );
    });

    test('a registration is visible to a second read of the provider', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container
          .read(backgroundActivityManagerProvider)
          .registerService(_ProbeService());

      expect(
        (container
                    .read(backgroundActivityManagerProvider)
                    .getStatus()['serviceNames']!
                as List)
            .cast<String>(),
        contains('ProbeService'),
      );
    });

    test('separate containers get separate registries', () {
      final a = ProviderContainer();
      final b = ProviderContainer();
      addTearDown(a.dispose);
      addTearDown(b.dispose);

      a
          .read(backgroundActivityManagerProvider)
          .registerService(_ProbeService());

      // Account-scoped on purpose: a swap discards the leaving account's
      // manager wholesale, so a registrant that fails to unregister (#8413)
      // cannot follow the user into the next account.
      expect(
        (b.read(backgroundActivityManagerProvider).getStatus()['serviceNames']!
                as List)
            .cast<String>(),
        isNot(contains('ProbeService')),
      );
    });
  });
}

class _ProbeService implements BackgroundAwareService {
  @override
  String get serviceName => 'ProbeService';

  @override
  void onAppBackgrounded() {}

  @override
  void onExtendedBackground() {}

  @override
  void onAppResumed() {}

  @override
  void onPeriodicCleanup() {}
}
