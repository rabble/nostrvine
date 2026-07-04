// ABOUTME: Sanctioned per-test overrides + heal-and-blame for shared MethodChannels.
// ABOUTME: Guards the #5738 merged-isolate leak class where a test replaces a
// ABOUTME: setupTestEnvironment-owned channel handler and strands later suites.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_setup.dart';

final Set<String> _sanctioned = <String>{};

/// Shared channels currently under a sanctioned override. The heal-and-blame
/// tearDown skips these (an intentional, self-restoring override is not a
/// leak). Exposed for the harness and its self-tests.
Set<String> get sanctionedChannels => Set<String>.unmodifiable(_sanctioned);

/// Temporarily replace the handler for a shared MethodChannel for the current
/// test scope, auto-restoring the canonical handler (and un-sanctioning) on
/// teardown.
///
/// Only the channels in [sharedChannelNames] may be overridden here — those are
/// the ones `setupTestEnvironment` installs once per merged isolate. A
/// test-local channel does not need sanctioning: install it and clear it in
/// your own `tearDown`.
///
/// Works from a test body, `setUp` (per-test scope), or `setUpAll` (group
/// scope — `addTearDown` routes to a group-scoped `tearDownAll`).
///
/// Not ref-counted: do not nest two overrides of the *same* channel across
/// scopes (e.g. a `setUpAll` override plus a per-test body override). The inner
/// teardown restores the canonical handler and un-sanctions the channel, which
/// would drop the outer override for the rest of the group. Override a given
/// shared channel at one scope only.
void overrideSharedChannel(
  MethodChannel channel,
  SharedChannelHandler? handler,
) {
  assert(
    sharedChannelNames.contains(channel.name),
    'overrideSharedChannel is only for shared channels installed by '
    'setupTestEnvironment (${sharedChannelNames.join(', ')}). '
    'For a test-local channel, install it and clear it in your own tearDown.',
  );
  _sanctioned.add(channel.name);
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, handler);
  addTearDown(() {
    restoreSharedChannel(channel);
    _sanctioned.remove(channel.name);
  });
}

/// Shared channels whose live handler is neither canonical nor sanctioned —
/// i.e. a test replaced or cleared it without restoring. Pure: no side effects.
List<String> findSharedChannelViolations() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final violations = <String>[];
  canonicalSharedHandlers.forEach((name, handler) {
    if (_sanctioned.contains(name)) return;
    if (!messenger.checkMockMessageHandler(name, handler)) {
      violations.add(name);
    }
  });
  return violations;
}

/// After every test (wired as a root `tearDown` in `flutter_test_config.dart`):
/// reinstall the canonical handler for every violated shared channel so the
/// next suite in the merged isolate is not stranded, and — only when [strict]
/// (the `DIVINE_STRICT_CHANNELS` build flag) — `fail()` the perpetrating test.
///
/// Compliant tests never trip this (heal only fires on a real violation), so
/// it is a no-op for correct code.
void healAndBlameSharedChannels({required bool strict}) {
  final violations = findSharedChannelViolations();
  if (violations.isEmpty) return;
  for (final name in violations) {
    restoreSharedChannel(MethodChannel(name));
  }
  if (strict) {
    fail(
      'This test replaced shared MethodChannel(s) ${violations.join(', ')} '
      'without restoring them. Under very_good --optimization every suite '
      'shares one isolate, so the next suite inherits the broken handler '
      '(#5738). Use overrideSharedChannel(channel, handler) (auto-restores) '
      'or addTearDown(restoreSharedChannelDefaults). '
      'See .claude/rules/testing.md (VGV merged isolate).',
    );
  }
}
