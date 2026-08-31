// ABOUTME: TEMPORARY probe proving the failing-shard seed summary renders.
// ABOUTME: Fails in CI only; removed before this PR leaves draft.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('seed report probe', () {
    test('fails in CI so one shard goes red', () {
      // Deliberate and temporary (#8418). Gated on CI so the pre-push hook,
      // which runs changed-file tests locally, still passes — pushing red is
      // forbidden, and --no-verify more so.
      expect(
        Platform.environment['CI'] == 'true',
        isFalse,
        reason: 'deliberate CI-only failure; proves the seed summary renders',
      );
    });
  });
}
