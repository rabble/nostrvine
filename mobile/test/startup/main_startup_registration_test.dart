import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/features/app/startup/startup_phase.dart';
import 'package:openvine/main.dart' as app;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

class _FakeUpdater implements ShorebirdUpdater {
  _FakeUpdater({this.status = UpdateStatus.upToDate, this.updateError});

  final UpdateStatus status;
  final Object? updateError;

  @override
  bool get isAvailable => true;

  @override
  Future<UpdateStatus> checkForUpdate({UpdateTrack? track}) async => status;

  @override
  Future<Patch?> readCurrentPatch() async => null;

  @override
  Future<Patch?> readNextPatch() async => null;

  @override
  Future<void> update({UpdateTrack? track}) async {
    if (updateError case final error?) throw error;
  }
}

void main() {
  test(
    'starts the Shorebird track update without waiting for a frame',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      var updaterCreations = 0;
      var updateCalls = 0;

      app.startShorebirdStartupUpdate(
        preferences: preferences,
        updaterFactory: () {
          updaterCreations++;
          return _FakeUpdater();
        },
        updateSubscribedTrack:
            ({required updater, required preferences}) async {
              updateCalls++;
            },
      );

      // No frame is rendered anywhere in this test. Startup calls this ~236
      // lines before `runApp`, so anything that only ran on the first frame
      // was stranded by a Dart-side failure in between — the launch a patch
      // most often exists to repair.
      await Future<void>.delayed(Duration.zero);

      expect(updaterCreations, 1);
      expect(updateCalls, 1);
    },
  );

  test('constructs the updater exactly once for the whole startup', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    ShorebirdUpdater? shared;
    var updaterCreations = 0;

    app.startShorebirdStartupUpdate(
      preferences: preferences,
      updaterFactory: () {
        updaterCreations++;
        return shared ??= _FakeUpdater();
      },
      updateSubscribedTrack:
          ({required updater, required preferences}) async {},
    );

    // The synchronous FFI probe in the real constructor is the cost of moving
    // this off the first frame, so build provenance must reuse this instance
    // rather than pay it twice.
    expect(updaterCreations, 1);
    expect(shared, isNotNull);
  });

  test('does not report expected Shorebird update failures', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    var reports = 0;

    await app.updateShorebirdFromSubscribedTrack(
      updater: _FakeUpdater(
        status: UpdateStatus.outdated,
        updateError: const UpdateException(
          message: 'download failed',
          reason: UpdateFailureReason.downloadFailed,
        ),
      ),
      preferences: preferences,
      reportUnexpectedError: (error, stackTrace) async => reports++,
    );

    expect(reports, 0);
  });

  test('reports unexpected Shorebird startup failures', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    Object? reported;
    final error = StateError('broken invariant');

    await app.updateShorebirdFromSubscribedTrack(
      updater: _FakeUpdater(
        status: UpdateStatus.outdated,
        updateError: error,
      ),
      preferences: preferences,
      reportUnexpectedError: (value, stackTrace) async => reported = value,
    );

    expect(reported, same(error));
  });

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
