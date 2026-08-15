// ABOUTME: Freezes the share sheet behind lib/utils/share_sheet.dart so no
// ABOUTME: call site can present a share without a sharePositionOrigin.

import 'dart:io';

import 'package:test/test.dart';

/// The one file allowed to reach for the plugin directly, because it is what
/// fills the anchor for everybody else.
const _entryPoint = 'lib/utils/share_sheet.dart';

void main() {
  group('share sheet entry point', () {
    test('only the wrapper calls SharePlus directly', () {
      final offenders = <String>[];

      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final path = entity.path;
        if (path == _entryPoint) continue;
        if (entity.readAsStringSync().contains('SharePlus.instance')) {
          offenders.add(path);
        }
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'iPad rejects a share whose sharePositionOrigin is missing '
            '(#7506). Call showShareSheet(context, params) — or '
            'showShareSheetAtOrigin when the anchor was resolved before an '
            'await — from $_entryPoint instead of SharePlus.instance.share.',
      );
    });
  });
}
