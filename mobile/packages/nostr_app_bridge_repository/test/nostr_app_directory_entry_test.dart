import 'package:nostr_app_bridge_repository/nostr_app_bridge_repository.dart';
import 'package:test/test.dart';

void main() {
  group(NostrAppDirectoryEntry, () {
    NostrAppDirectoryEntry buildEntry({
      String launchUrl = 'https://example.com/app',
    }) {
      return NostrAppDirectoryEntry(
        id: '1',
        slug: 'test',
        name: 'Test',
        tagline: 'A test app',
        description: 'Description',
        iconUrl: 'https://example.com/icon.png',
        launchUrl: launchUrl,
        allowedOrigins: const ['https://example.com'],
        allowedMethods: const ['getPublicKey'],
        allowedSignEventKinds: const [1],
        promptRequiredFor: const ['signEvent'],
        status: 'approved',
        sortOrder: 0,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );
    }

    group('primaryOrigin', () {
      test('returns origin for a valid URL with path', () {
        final entry = buildEntry(
          launchUrl: 'https://primal.net/app',
        );
        expect(entry.primaryOrigin, 'https://primal.net');
      });

      test('returns origin for a URL with port', () {
        final entry = buildEntry(
          launchUrl: 'https://example.com:8080/path',
        );
        expect(
          entry.primaryOrigin,
          'https://example.com:8080',
        );
      });

      test('returns raw value for unparseable input', () {
        final entry = buildEntry(launchUrl: 'not-a-url');
        expect(entry.primaryOrigin, 'not-a-url');
      });

      test('returns raw value when scheme is missing', () {
        final entry = buildEntry(
          launchUrl: 'example.com/path',
        );
        expect(entry.primaryOrigin, 'example.com/path');
      });

      test('returns raw value for empty string', () {
        final entry = buildEntry(launchUrl: '');
        expect(entry.primaryOrigin, '');
      });
    });

    group('autoLoginScript', () {
      test('defaults to null', () {
        final entry = buildEntry();
        expect(entry.autoLoginScript, isNull);
      });

      test('round-trips through JSON', () {
        final entry = NostrAppDirectoryEntry(
          id: '1',
          slug: 'test',
          name: 'Test',
          tagline: 'A test app',
          description: 'Description',
          iconUrl: 'https://example.com/icon.png',
          launchUrl: 'https://example.com/app',
          allowedOrigins: const ['https://example.com'],
          allowedMethods: const ['getPublicKey'],
          allowedSignEventKinds: const [1],
          promptRequiredFor: const ['signEvent'],
          status: 'approved',
          sortOrder: 0,
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
          autoLoginScript: "localStorage.setItem('pk', '{{PUBKEY}}');",
        );
        final json = entry.toJson();
        expect(
          json['auto_login_script'],
          equals("localStorage.setItem('pk', '{{PUBKEY}}');"),
        );

        final restored = NostrAppDirectoryEntry.fromJson(json);
        expect(
          restored.autoLoginScript,
          equals(entry.autoLoginScript),
        );
      });

      test('omits auto_login_script from JSON when null', () {
        final entry = buildEntry();
        final json = entry.toJson();
        expect(json.containsKey('auto_login_script'), isFalse);
      });
    });

    group('Equatable', () {
      test('two entries with same fields are equal', () {
        final a = buildEntry();
        final b = buildEntry();
        expect(a, equals(b));
      });

      test(
        'entries with different launchUrl are not equal',
        () {
          final a = buildEntry();
          final b = buildEntry(
            launchUrl: 'https://other.com',
          );
          expect(a, isNot(equals(b)));
        },
      );
    });
  });
}
