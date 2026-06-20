import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/features/app/startup/startup_phase.dart';
import 'package:openvine/main.dart' as app;

void main() {
  test('initializes disk-backed startup services before runApp', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final coordinator = app.createStartupCoordinatorForTesting(container);

    expect(
      coordinator.serviceRegistrationForTesting('HiveStorage')?.phase,
      StartupPhase.critical,
    );
    expect(
      coordinator.serviceRegistrationForTesting('CacheSync')?.phase,
      StartupPhase.critical,
    );
  });
}
