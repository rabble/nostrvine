// ABOUTME: E2E test verifying C2PA signer initializes without crashing
// ABOUTME: Catches StrongBox fallback bug (issue #2019) where StrongBoxSigner
// ABOUTME: was used with a software-backed key on devices without StrongBox
// ABOUTME: Requires: local Docker stack running (mise run local_up)

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/main.dart' as app;
import 'package:path_provider/path_provider.dart';
import 'package:patrol/patrol.dart';

import '../helpers/test_setup.dart';

void main() {
  group('C2PA Signer Initialization', () {
    patrolTest('C2PA hardware signer creates cert file on emulator', ($) async {
      final tester = $.tester;
      final originalOnError = suppressSetStateErrors();
      final originalErrorBuilder = saveErrorWidgetBuilder();

      final appDir = await getApplicationDocumentsDirectory();
      final certFile = File('${appDir.path}/c2pa_signing_divine.cert');

      // Force the test to validate fresh certificate creation on startup.
      if (certFile.existsSync()) {
        certFile.deleteSync();
      }

      // Launch the app — C2PA init runs async on Dispatchers.IO at startup
      launchAppGuarded(app.main);
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Wait for C2PA init to complete (certificate enrollment + signing)
      // Poll for cert file (C2PA init runs async, may take a few seconds)
      var certExists = false;
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(seconds: 1));
        if (certFile.existsSync()) {
          certExists = true;
          break;
        }
      }

      // The cert file is written by createHardwareSigner() only on success.
      // On the buggy path (StrongBoxSigner with software key), init crashes
      // and the cert file is never created.
      expect(
        certExists,
        isTrue,
        reason:
            'C2PA cert file should exist after successful signer init. '
            'If missing, createHardwareSigner() crashed — likely the '
            'StrongBox fallback bug (issue #2019) where StrongBoxSigner '
            'is used with a software-backed key.',
      );

      // Verify cert file has content (not empty/corrupt)
      final certContent = certFile.readAsStringSync();
      expect(
        certContent,
        contains('BEGIN CERTIFICATE'),
        reason: 'Cert file should contain a valid PEM certificate',
      );

      restoreErrorWidgetBuilder(originalErrorBuilder);
      restoreErrorHandler(originalOnError);
      drainAsyncErrors(tester);
    });
  });
}
