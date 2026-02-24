import 'package:models/models.dart';
import 'package:test/test.dart';

void main() {
  group(BulkProfilesResponse, () {
    group('constructor', () {
      test('creates instance with empty map', () {
        const response = BulkProfilesResponse(profiles: {});

        expect(response.profiles, isEmpty);
      });

      test('creates instance with profiles', () {
        const response = BulkProfilesResponse(
          profiles: {
            'pubkey1': {'name': 'Alice', 'display_name': 'Alice A'},
            'pubkey2': {'name': 'Bob'},
          },
        );

        expect(response.profiles, hasLength(2));
        expect(
          response.profiles['pubkey1']?['name'],
          equals('Alice'),
        );
        expect(
          response.profiles['pubkey2']?['name'],
          equals('Bob'),
        );
      });
    });
  });
}
