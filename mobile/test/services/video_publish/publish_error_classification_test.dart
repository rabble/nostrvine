// ABOUTME: Tests VideoPublishService.classifyPublishErrorMessage + the drift
// ABOUTME: guard that every UploadManager error category maps to a stable kind.

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/services/upload_manager.dart';
import 'package:openvine/services/video_publish/publish_error_kind.dart';
import 'package:openvine/services/video_publish/video_publish_service.dart';

class _MockBlossomUploadService extends Mock implements BlossomUploadService {}

void main() {
  group('classifyPublishErrorMessage', () {
    test('maps raw technical exceptions to their kind', () {
      const cases = <String, PublishErrorKind>{
        'SocketException: Network is unreachable': PublishErrorKind.noInternet,
        'Connection refused': PublishErrorKind.serverUnreachable,
        'Connection timed out': PublishErrorKind.timeout,
        'HandshakeException: certificate verify failed': PublishErrorKind.tls,
        '404 not_found': PublishErrorKind.serverNotFound,
        '413 payload too large': PublishErrorKind.fileTooLarge,
        '500 internal server error': PublishErrorKind.serverInternalError,
        '502 bad gateway': PublishErrorKind.serverDown,
        '401 unauthorized': PublishErrorKind.notSignedIn,
        '403 forbidden': PublishErrorKind.forbidden,
        'PathNotFoundException: no such file': PublishErrorKind.fileNotFound,
        'No space left on device': PublishErrorKind.lowStorage,
        'Thumbnail upload failed': PublishErrorKind.thumbnailFailed,
        'Failed to publish nostr event': PublishErrorKind.nostrPublishFailed,
        '429 too many requests': PublishErrorKind.rateLimited,
        'Upload session expired': PublishErrorKind.uploadSessionExpired,
        'Permission denied': PublishErrorKind.permissionDenied,
        'Out of memory': PublishErrorKind.outOfMemory,
      };
      cases.forEach((input, expected) {
        expect(
          VideoPublishService.classifyPublishErrorMessage(input),
          expected,
          reason: '"$input" should classify as $expected',
        );
      });
    });

    test('returns null for genuinely unknown user-friendly text', () {
      expect(
        VideoPublishService.classifyPublishErrorMessage(
          'A brand new upstream message we do not recognize yet.',
        ),
        isNull,
      );
    });

    test('returns null for an opaque stack/class dump', () {
      expect(
        VideoPublishService.classifyPublishErrorMessage(
          '#0      _SomeClass.method (package:foo/foo.dart:12:3)',
        ),
        isNull,
      );
    });

    test('HTTP status wins over an app-permission substring', () {
      // A 403 from the server is server-forbidden, even if the body text
      // mentions "permission denied" — the status branch runs first.
      expect(
        VideoPublishService.classifyPublishErrorMessage(
          '403 forbidden: permission denied',
        ),
        PublishErrorKind.forbidden,
      );
    });
  });

  group('UploadManager error-message drift guard', () {
    late UploadManager uploadManager;

    setUp(() {
      uploadManager = UploadManager(
        blossomService: _MockBlossomUploadService(),
      );
    });

    // If UploadManager.getUserFriendlyErrorMessage copy ever drifts, these
    // assertions fail loudly — closing the window where an upload failure
    // would silently fall back to verbatim English instead of re-localizing.
    const expectations = <(String, PublishErrorKind)>[
      ('NO_INTERNET', PublishErrorKind.noInternet),
      ('SLOW_CONNECTION', PublishErrorKind.timeout),
      ('TIMEOUT', PublishErrorKind.timeout),
      ('NETWORK_ERROR', PublishErrorKind.serverUnreachable),
      ('DNS_ERROR', PublishErrorKind.serverUnreachable),
      ('FILE_NOT_FOUND', PublishErrorKind.fileNotFound),
      ('FILE_TOO_LARGE', PublishErrorKind.fileTooLarge),
      ('OUT_OF_MEMORY', PublishErrorKind.outOfMemory),
      ('PERMISSION_DENIED', PublishErrorKind.permissionDenied),
      ('AUTHENTICATION', PublishErrorKind.notSignedIn),
      ('UPLOAD_SESSION_EXPIRED', PublishErrorKind.uploadSessionExpired),
      ('RATE_LIMITED', PublishErrorKind.rateLimited),
      ('SERVER_UNAVAILABLE', PublishErrorKind.serverDown),
      ('SERVER_ERROR', PublishErrorKind.serverInternalError),
      ('CLIENT_ERROR', PublishErrorKind.generic),
    ];

    for (final (category, expected) in expectations) {
      test('$category renders to a sentence that classifies as $expected', () {
        final message = uploadManager.getUserFriendlyErrorMessage(
          category,
          ConnectivityResult.wifi,
        );
        expect(
          VideoPublishService.classifyPublishErrorMessage(message),
          expected,
          reason: 'category $category -> "$message"',
        );
      });
    }

    test('the default (unknown category) message classifies as generic', () {
      final message = uploadManager.getUserFriendlyErrorMessage(
        'SOME_FUTURE_CATEGORY',
        ConnectivityResult.wifi,
      );
      expect(
        VideoPublishService.classifyPublishErrorMessage(message),
        PublishErrorKind.generic,
      );
    });

    test('NETWORK_ERROR maps regardless of the interpolated network type', () {
      for (final connectivity in [
        ConnectivityResult.wifi,
        ConnectivityResult.mobile,
        ConnectivityResult.ethernet,
      ]) {
        final message = uploadManager.getUserFriendlyErrorMessage(
          'NETWORK_ERROR',
          connectivity,
        );
        expect(
          VideoPublishService.classifyPublishErrorMessage(message),
          PublishErrorKind.serverUnreachable,
          reason: 'NETWORK_ERROR on $connectivity -> "$message"',
        );
      }
    });
  });
}
