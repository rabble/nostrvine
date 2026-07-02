// ABOUTME: Regression test for #5738/#5340 — RealIntegrationTestHelper must
// ABOUTME: restore the shared secure-storage handler after its group ends.

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'real_integration_test_helper.dart';

// Under very_good --optimization all suites share one isolate, and the
// app-wide harness (test_setup.dart) installs a working in-memory
// secure-storage handler once per process. RealIntegrationTestHelper
// overwrites that handler with a degraded one (read → null); before #5738 it
// never restored it, silently stranding any later suite that relied on the
// ambient handler. The two groups run in declaration order locally; under a
// shuffled merged run either order passes, and the perpetrator-first order
// exercises the restore.
void main() {
  group('while RealIntegrationTestHelper is installed', () {
    setUpAll(RealIntegrationTestHelper.setupTestEnvironment);

    test('degraded handler is active inside the group', () async {
      const storage = FlutterSecureStorage();
      await storage.write(key: 'k5738_degraded', value: 'dropped');
      expect(await storage.read(key: 'k5738_degraded'), isNull);
    });
  });

  group('after the helper group completes', () {
    test('ambient write-then-read roundtrip works again', () async {
      const storage = FlutterSecureStorage();
      await storage.write(key: 'k5738_restored', value: 'v5738');
      expect(await storage.read(key: 'k5738_restored'), equals('v5738'));
    });
  });
}
