// ABOUTME: End-to-end two-device sound library sync against local_stack.
// ABOUTME: Real relay, real encryption, no mocks.
//
// Requires the local Docker stack running first:
//   cd local_stack && docker compose up -d
// Then, from mobile/:
//   flutter test integration_test/creator_sync/sound_sync_two_device_test.dart
//
// That command only reaches the stack from an Android emulator. The relay
// URL is built from `localHost`, which `environment_config.dart` hardcodes
// to '10.0.2.2' with no platform branch — an emulator-only alias for the
// host machine. Run from macOS it routes out the default gateway, never
// reaches local_stack, and the harness times out waiting to connect. Use
// the Android emulator, or point `_relayUrl` in the harness at
// 'ws://localhost:$localRelayPort' for a local run.
//
// This file lives outside integration_test/e2e/ and carries no `service`
// tag, so `mobile_service_integration_tests` (which runs
// `flutter test integration_test/e2e/ --tags service`) never executes it.
// CI only `dart format`-checks and `flutter analyze`s this file — it never
// runs it, because local_stack is not available there.
//
// AS COMMITTED, THIS TEST HAS NEVER BEEN EXECUTED: it was authored in an
// environment where the Docker daemon was unresponsive, so local_stack
// could not be started. Run it manually against a live local_stack before
// treating it as a working regression guard.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/sync_e2e_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('sound library sync across two devices', () {
    late SyncE2eHarness harness;

    setUp(() async => harness = await SyncE2eHarness.start());
    tearDown(() async => harness.dispose());

    testWidgets('a sound saved on device A appears on device B', (
      tester,
    ) async {
      await harness.deviceA.local.upsert(
        harness.soundId,
        harness.soundBody(label: 'intro'),
      );

      await harness.deviceA.repository.reconcile();
      final outcome = await harness.deviceB.repository.reconcile();

      expect(outcome.pulled, equals(1));
      expect(
        (await harness.deviceB.local.readAll())[harness.soundId],
        equals(harness.soundBody(label: 'intro')),
      );
    });

    testWidgets('both devices converge on the newer edit', (tester) async {
      await harness.deviceA.local.upsert(
        harness.soundId,
        harness.soundBody(label: 'first'),
      );
      await harness.deviceA.repository.reconcile();
      await harness.deviceB.repository.reconcile();

      await harness.deviceB.local.upsert(
        harness.soundId,
        harness.soundBody(label: 'second'),
      );
      await harness.deviceB.repository.publishLocalChange(harness.soundId);
      await harness.deviceA.repository.reconcile();

      expect(
        (await harness.deviceA.local
            .readAll())[harness.soundId]!['personalLabel'],
        equals('second'),
      );
    });

    testWidgets('a deletion on A removes the sound on B and stays deleted', (
      tester,
    ) async {
      await harness.deviceA.local.upsert(
        harness.soundId,
        harness.soundBody(label: 'doomed'),
      );
      await harness.deviceA.repository.reconcile();
      await harness.deviceB.repository.reconcile();

      await harness.deviceA.local.remove(harness.soundId);
      await harness.deviceA.repository.publishLocalDeletion(harness.soundId);
      await harness.deviceB.repository.reconcile();

      expect(await harness.deviceB.local.readAll(), isEmpty);

      // Second pass must not resurrect it from B's local state.
      await harness.deviceB.repository.reconcile();
      expect(await harness.deviceB.local.readAll(), isEmpty);
    });

    testWidgets('device B unwraps the vault key device A created', (
      tester,
    ) async {
      expect(
        harness.deviceB.vaultKeyBytes,
        equals(harness.deviceA.vaultKeyBytes),
      );
    });
  });
}
