// ABOUTME: Test configuration file that sets up app-wide plugin mocks.
// ABOUTME: Golden-only font and Alchemist setup is opt-in to keep unit tests fast.

import 'dart:async';

import 'package:alchemist/alchemist.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:golden_toolkit/golden_toolkit.dart';
import 'test_setup.dart';

const _runGoldenSetup = bool.fromEnvironment('DIVINE_GOLDEN_TESTS');

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // Set up test environment with plugin mocks (secure_storage, path_provider, etc.)
  setupTestEnvironment();

  // Web / `flutter test --platform chrome`: skip golden font loading and
  // Alchemist. Those paths can stall headless Chrome with almost no CPU while
  // `loading ...` is shown.
  if (kIsWeb || !_runGoldenSetup) {
    return testMain();
  }

  // Golden runs opt in with:
  //   flutter test -D DIVINE_GOLDEN_TESTS=true test/goldens/
  await loadAppFonts();

  // Configure Alchemist for better golden test output
  return AlchemistConfig.runWithConfig(
    config: const AlchemistConfig(
      // Platform variants to test
      platformGoldensConfig: PlatformGoldensConfig(),
      // CI-specific configuration
      ciGoldensConfig: CiGoldensConfig(),
    ),
    run: testMain,
  );
}
