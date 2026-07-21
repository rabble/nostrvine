import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Android native auth error contract', () {
    test('maps HTTP 401 responses to auth_required', () {
      final source = _androidSourceFile().readAsStringSync();

      final badStatusBranch = source.indexOf(
        'PlaybackException.ERROR_CODE_IO_BAD_HTTP_STATUS',
      );
      final statusCheck = source.indexOf('status == 401');
      final statusMapping = source.indexOf('"auth_required"', statusCheck);
      final genericClientMapping = source.indexOf(
        'status in 400..499 -> "http_client_error"',
      );

      expect(badStatusBranch, greaterThanOrEqualTo(0));
      expect(statusCheck, greaterThan(badStatusBranch));
      expect(statusMapping, greaterThan(statusCheck));
      expect(
        statusMapping,
        lessThan(genericClientMapping),
        reason:
            'HTTP 401 must be classified before the generic 4xx mapping so '
            'Dart can route it through the age-gate path without parsing the '
            'raw error message.',
      );
    });
  });
}

File _androidSourceFile() {
  final packageRelative = File(
    'android/src/main/kotlin/com/divinevideo/divine_video_player/'
    'DivineVideoPlayerInstance.kt',
  );
  if (packageRelative.existsSync()) {
    return packageRelative;
  }

  return File(
    'packages/divine_video_player/'
    'android/src/main/kotlin/com/divinevideo/divine_video_player/'
    'DivineVideoPlayerInstance.kt',
  );
}
