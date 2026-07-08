// ABOUTME: Test configuration file that sets up app-wide plugin mocks.
// ABOUTME: Golden-only font and Alchemist setup is opt-in to keep unit tests fast.

import 'dart:async';

import 'package:alchemist/alchemist.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:openvine/widgets/avatar_failure_cache.dart';

import 'helpers/shared_channel_override.dart';
import 'test_setup.dart';

const _runGoldenSetup = bool.fromEnvironment('DIVINE_GOLDEN_TESTS');

/// When set (via `--dart-define=DIVINE_STRICT_CHANNELS=true`), the
/// heal-and-blame tearDown also `fail()`s the test that leaked a shared
/// channel. Off by default so the harness heals silently locally; CI can flip
/// it on once the full suite is proven clean under it (#5738).
const _strictChannels = bool.fromEnvironment('DIVINE_STRICT_CHANNELS');

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // Set up test environment with plugin mocks (secure_storage, path_provider, etc.)
  setupTestEnvironment();

  // Under `very_good test --optimization` the whole unit suite runs in one
  // isolate and flutter_test auto-restores nothing, so a test that replaces a
  // shared MethodChannel handler without restoring it strands every later
  // suite (#5738). This root tearDown runs after every test in the bundle
  // (inner group/file tearDowns first), heals any shared channel that drifted
  // from its canonical handler, and — under DIVINE_STRICT_CHANNELS — blames
  // the perpetrating test. Compliant tests never trip it.
  tearDown(() => healAndBlameSharedChannels(strict: _strictChannels));

  // UserAvatar records broken image URLs in a process-global negative cache.
  // In the merged optimizer isolate that state would otherwise leak a failed
  // URL into a later test that expects the same avatar to load. Reset it after
  // every test so avatar failure caching stays test-local.
  tearDown(AvatarFailureCache.instance.clear);

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
