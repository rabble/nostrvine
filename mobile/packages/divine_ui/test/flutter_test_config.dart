// ABOUTME: Alchemist golden config for the divine_ui package test suite.
// ABOUTME: Platform goldens are disabled so only the platform-agnostic CI
// ABOUTME: variant runs — byte-identical on a dev's machine and on Ubuntu CI.

import 'dart:async';

import 'package:alchemist/alchemist.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // Disabling platform goldens leaves only the CI variant (Ahem-obscured text,
  // no shadows), which renders identically across platforms. Without this, the
  // Linux platform variant on CI would demand goldens/linux/*.png that a macOS
  // dev never generates. Alchemist loads declared fonts itself, so no explicit
  // font setup is needed here.
  await AlchemistConfig.runWithConfig(
    config: const AlchemistConfig(
      platformGoldensConfig: PlatformGoldensConfig(enabled: false),
    ),
    run: testMain,
  );
}
