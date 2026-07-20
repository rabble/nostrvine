// ABOUTME: Test configuration file that sets up app-wide plugin mocks.
// ABOUTME: Alchemist config (platform goldens off) is always applied so migrated
// ABOUTME: goldens gate CI inline; real-font loading stays opt-in for speed.

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

  // Web / `flutter test --platform chrome`: skip golden/font setup entirely.
  // Those paths can stall headless Chrome with almost no CPU while
  // `loading ...` is shown.
  if (kIsWeb) {
    return testMain();
  }

  // Alchemist goldens run INLINE in the normal suite (no --dart-define): a plain
  // `very_good test` compares them, so migrated component goldens gate CI. We
  // disable platform goldens so only the platform-agnostic CI variant (Ahem-
  // obscured text, no shadows) is generated and compared — byte-identical on a
  // dev's macOS and Ubuntu CI. Real fonts are loaded only for the opt-in local
  // golden suite (`--dart-define=DIVINE_GOLDEN_TESTS=true`); the block-text CI
  // goldens don't need them. Applying the config for every test is inert for
  // non-golden tests (it only sets a zone value) and is alchemist's intended
  // flutter_test_config usage.
  if (_runGoldenSetup) {
    await loadAppFonts();
  }
  return AlchemistConfig.runWithConfig(
    config: const AlchemistConfig(
      platformGoldensConfig: PlatformGoldensConfig(enabled: false),
    ),
    run: testMain,
  );
}
