// ABOUTME: Tests the viewer-auth result type and its headers accessor.
// ABOUTME: Confirms only the authorized variant exposes headers.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/viewer_auth_result.dart';

void main() {
  group(ViewerAuthResult, () {
    test('ViewerAuthAuthorized exposes its headers via headersOrNull', () {
      const headers = {'Authorization': 'Nostr token'};
      const result = ViewerAuthAuthorized(headers);

      expect(result.headers, equals(headers));
      expect(result.headersOrNull, equals(headers));
    });

    test('ViewerAuthSignerUnreachable has no headers', () {
      const result = ViewerAuthSignerUnreachable();

      expect(result.headersOrNull, isNull);
    });

    test('ViewerAuthBlockedByPreference has no headers', () {
      const result = ViewerAuthBlockedByPreference();

      expect(result.headersOrNull, isNull);
    });

    test('ViewerAuthUnavailable has no headers', () {
      const result = ViewerAuthUnavailable();

      expect(result.headersOrNull, isNull);
    });
  });
}
