// ABOUTME: Test configuration file that loads fonts and sets up golden tests
// ABOUTME: This file is automatically executed before all tests in the test directory

import 'dart:async';

import 'package:alchemist/alchemist.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:golden_toolkit/golden_toolkit.dart';
import 'test_setup.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // Set up test environment with plugin mocks (secure_storage, path_provider, etc.)
  setupTestEnvironment();

  // Web / `flutter test --platform chrome`: skip golden font loading and Alchemist.
  // Those paths can stall headless Chrome with almost no CPU while `loading …` is shown.
  if (kIsWeb) {
    return testMain();
  }

  // Load app fonts for golden tests
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
