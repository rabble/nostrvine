// ABOUTME: Tests PublishError persistence encode/decode + back-compat.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/video_publish/publish_error_kind.dart';
import 'package:openvine/services/video_publish/video_publish_service.dart';

void main() {
  group('PublishError persistence', () {
    test('round-trips every kind without a server name', () {
      for (final kind in PublishErrorKind.values) {
        final encoded = PublishError(kind).toPersistedString();
        final decoded = PublishError.fromPersistedString(encoded);
        expect(decoded, isNotNull);
        expect(decoded!.kind, kind);
        expect(decoded.serverName, isNull);
        expect(decoded.rawFallback, isNull);
      }
    });

    test('round-trips a server kind with its server name', () {
      const error = PublishError(
        PublishErrorKind.serverNotFound,
        serverName: 'media.divine.video',
      );
      final decoded = PublishError.fromPersistedString(
        error.toPersistedString(),
      );
      expect(decoded!.kind, PublishErrorKind.serverNotFound);
      expect(decoded.serverName, 'media.divine.video');
    });

    test('persists a rawFallback verbatim and decodes it as generic', () {
      const error = PublishError(
        PublishErrorKind.generic,
        rawFallback: 'Upstream already-friendly message.',
      );
      expect(error.toPersistedString(), 'Upstream already-friendly message.');

      final decoded = PublishError.fromPersistedString(
        error.toPersistedString(),
      );
      expect(decoded!.kind, PublishErrorKind.generic);
      expect(decoded.rawFallback, 'Upstream already-friendly message.');
    });

    test('decodes a legacy (pre-#4892) sentence string as a rawFallback', () {
      final decoded = PublishError.fromPersistedString(
        'Something went wrong. Please try again.',
      );
      expect(decoded!.kind, PublishErrorKind.generic);
      expect(decoded.rawFallback, 'Something went wrong. Please try again.');
    });

    test('decodes an unknown pek1 kind name as a generic rawFallback', () {
      final decoded = PublishError.fromPersistedString('pek1:notARealKind');
      expect(decoded!.kind, PublishErrorKind.generic);
      expect(decoded.rawFallback, 'pek1:notARealKind');
    });

    test('returns null for a null or empty persisted value', () {
      expect(PublishError.fromPersistedString(null), isNull);
      expect(PublishError.fromPersistedString(''), isNull);
    });
  });
}
