import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Apple native auth error contract', () {
    test('maps NSURLError auth-required failures to auth_required', () {
      final source = _appleSourceFile().readAsStringSync();

      final authCase = source.indexOf('NSURLErrorUserAuthenticationRequired');
      final authMapping = source.indexOf('return "auth_required"', authCase);
      final defaultCase = source.indexOf('default:', authCase);

      expect(
        authCase,
        greaterThanOrEqualTo(0),
        reason:
            'Bare AVFoundation NSURLErrorDomain -1013 failures must not fall '
            'through to unknown.',
      );
      expect(authMapping, greaterThan(authCase));
      expect(
        authMapping,
        lessThan(defaultCase),
        reason:
            'The auth-required case must be handled inside the '
            'NSURLErrorDomain '
            'switch before default maps unrecognised errors to unknown.',
      );
    });

    test('maps HTTP 401 responses to auth_required', () {
      final source = _appleSourceFile().readAsStringSync();

      final responseBranch = source.indexOf(
        'NSURLErrorFailingURLResponseErrorKey',
      );
      final statusCheck = source.indexOf('httpResponse.statusCode == 401');
      final statusMapping = source.indexOf('return "auth_required"');

      expect(responseBranch, greaterThanOrEqualTo(0));
      expect(statusCheck, greaterThan(responseBranch));
      expect(statusMapping, greaterThan(statusCheck));
    });
  });
}

/// The iOS and macOS players share a single Darwin source tree
/// (`darwin/divine_video_player/Sources/`), so the auth contract is asserted
/// once.
File _appleSourceFile() {
  final packageRelative = File(
    'darwin/divine_video_player/Sources/divine_video_player/'
    'DivineVideoPlayerInstance.swift',
  );
  if (packageRelative.existsSync()) {
    return packageRelative;
  }

  return File(
    'packages/divine_video_player/'
    'darwin/divine_video_player/Sources/divine_video_player/'
    'DivineVideoPlayerInstance.swift',
  );
}
