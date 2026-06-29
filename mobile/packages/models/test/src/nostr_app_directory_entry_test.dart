import 'package:models/models.dart';
import 'package:test/test.dart';

void main() {
  group('NostrAppDirectoryEntry', () {
    test('defaults allowedNavigationOrigins to empty', () {
      final entry = _buildEntry();

      expect(entry.allowedNavigationOrigins, isEmpty);
    });

    test('round-trips allowedNavigationOrigins through JSON when present', () {
      final entry = _buildEntry(
        allowedNavigationOrigins: const ['https://login.divine.video'],
      );

      final json = entry.toJson();

      expect(
        json['allowed_navigation_origins'],
        equals(['https://login.divine.video']),
      );
      expect(
        NostrAppDirectoryEntry.fromJson(json).allowedNavigationOrigins,
        equals(['https://login.divine.video']),
      );
    });

    test('omits allowed_navigation_origins from JSON when empty', () {
      final json = _buildEntry().toJson();

      expect(json.containsKey('allowed_navigation_origins'), isFalse);
    });
  });
}

NostrAppDirectoryEntry _buildEntry({
  List<String> allowedNavigationOrigins = const [],
}) {
  return NostrAppDirectoryEntry(
    id: '1',
    slug: 'test',
    name: 'Test',
    tagline: 'A test app',
    description: 'Description',
    iconUrl: 'https://example.com/icon.png',
    launchUrl: 'https://example.com/app',
    allowedOrigins: const ['https://example.com'],
    allowedNavigationOrigins: allowedNavigationOrigins,
    allowedMethods: const ['getPublicKey'],
    allowedSignEventKinds: const [1],
    promptRequiredFor: const ['signEvent'],
    status: 'approved',
    sortOrder: 0,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );
}
