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

  test('opens the uploads box only after Hive has a home path', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final coordinator = app.createStartupCoordinatorForTesting(container);

    // HiveStorage is the only owner of Hive's process-global home path, so the
    // uploads box must not open before it — otherwise the box lands in
    // whatever directory happens to be current (#6958).
    expect(
      coordinator.serviceRegistrationForTesting('UploadManager')?.dependencies,
      contains('HiveStorage'),
    );
  });

  test('initializes performance monitoring before runApp', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final coordinator = app.createStartupCoordinatorForTesting(container);

    // Anything later drops every trace started during cold start: the monitor
    // early-returns until it is initialized, so the traces are never created
    // rather than merely late (#7118).
    expect(
      coordinator.serviceRegistrationForTesting('PerformanceMonitoring')?.phase,
      StartupPhase.critical,
    );
  });

  test('performance monitoring does not extend the critical phase', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final coordinator = app.createStartupCoordinatorForTesting(container);

    // The phase runs each dependency level with `Future.wait`, so a
    // dependency-free service costs nothing beyond the slowest sibling. Giving
    // it a dependency would move it into a later level and put its platform
    // round-trip on the critical path in series.
    expect(
      coordinator
          .serviceRegistrationForTesting('PerformanceMonitoring')
          ?.dependencies,
      isEmpty,
    );
  });

  test('runs C2PA debris cleanup as optional deferred startup work', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final coordinator = app.createStartupCoordinatorForTesting(container);
    final registration = coordinator.serviceRegistrationForTesting(
      'C2paDebrisSweep',
    );

    expect(registration?.phase, StartupPhase.deferred);
    expect(registration?.optional, isTrue);
  });
}
