import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/utils/sensitive_uri_for_logs.dart';

void main() {
  group('redactUriStringForLogs', () {
    test('returns invalid placeholder when parse fails', () {
      expect(redactUriStringForLogs('::::'), '[invalid-uri]');
      expect(redactUriStringForLogs(''), '[invalid-uri]');
      expect(redactUriStringForLogs('   '), '[invalid-uri]');
    });

    test(
      'redacts all query values (token, code, deviceCode, verifier, secret)',
      () {
        final raw =
            'https://divine.video/invite?token=abc&code=CDEF&deviceCode=dd&'
            'verifier=vv&secret=ss&other=xx';
        final out = redactUriStringForLogs(raw);
        expect(out, isNot(contains('abc')));
        expect(out, isNot(contains('CDEF')));
        expect(out, isNot(contains('deviceCode=dd')));
        expect(out, isNot(contains('verifier=vv')));
        expect(out, isNot(contains('secret=ss')));
        expect(out, isNot(contains('other=xx')));
        expect(out, contains('token'));
        expect(out, contains('deviceCode'));
        expect(out, contains('verifier'));
        expect(out, contains('secret'));
        expect(out, contains(redactedUriComponentForLogs));
      },
    );

    test('query key casing is preserved; values remain redacted', () {
      final raw = 'https://divine.video/path?Code=up&TOKEN=t&VERIFIER=v';
      final out = redactUriStringForLogs(raw);
      expect(out, isNot(contains('Code=up')));
      expect(out, isNot(contains('TOKEN=t')));
      expect(out, isNot(contains('VERIFIER=v')));
      expect(out.split('Code=').last, startsWith(redactedUriComponentForLogs));
    });

    test('redacts duplicate query parameter values', () {
      final raw = 'https://divine.video/x?state=1&state=2';
      final out = redactUriStringForLogs(raw);
      expect(out, isNot(contains('state=1')));
      expect(
        out.split(redactedUriComponentForLogs).length - 1,
        greaterThanOrEqualTo(2),
      );
    });

    test('preserves video and profile refs (full path segments)', () {
      final note =
          'note1qqqqqqqzghd5m8qyv7qkz9q7qkqkqkqkqkqkqkqkqkqkqkqkqkqkqkqkqkqkqkqkq';
      final raw = 'https://divine.video/video/$note';
      final out = redactUriStringForLogs(raw);
      expect(out, contains(note));

      final npub =
          'npub180cvv07tjdrrgpa9jzd0cdkej42kwsaxq9rz7gvdpjx6nz004f9uulstw6';
      final rawProfile = 'https://divine.video/profile/$npub/3';
      final outProfile = redactUriStringForLogs(rawProfile);
      expect(outProfile, contains(npub));
      expect(outProfile, contains('/3'));
    });

    test('redacts invite code path segment after /invite/', () {
      final raw =
          'https://divine.video/invite/ABCD-EFGH-INVITE?utm_source=test';
      final out = redactUriStringForLogs(raw);
      expect(out, isNot(contains('ABCD')));
      expect(out, isNot(contains('utm_source=test')));
      expect(out, contains('/invite/$redactedUriComponentForLogs'));
    });

    test('clears userInfo credentials', () {
      final raw = 'https://user:sekret@divine.video/video/foo';
      final out = redactUriStringForLogs(raw);
      expect(out, isNot(contains('sekret')));
      expect(out, startsWith('https://divine.video/'));
      expect(out, contains('/video/foo'));
    });

    test('redacts fragment contents', () {
      final raw = 'https://divine.video/page#oops=sensitive-bit';
      final out = redactUriStringForLogs(raw);
      expect(out, isNot(contains('sensitive-bit')));
      expect(out, endsWith('#$redactedUriComponentForLogs'));
    });

    test('handles divine scheme callback style URIs', () {
      final raw = 'divine://signer-return?token=supersecret&refresh=1';
      final out = redactUriStringForLogs(raw);
      expect(out, startsWith('divine://'));
      expect(out, isNot(contains('supersecret')));
    });
  });
}
