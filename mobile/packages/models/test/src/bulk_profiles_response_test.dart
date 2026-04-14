import 'package:models/models.dart';
import 'package:test/test.dart';

void main() {
  group(BulkProfilesResponse, () {
    group('constructor', () {
      test('creates instance with empty map', () {
        const response = BulkProfilesResponse(profiles: {});

        expect(response.profiles, isEmpty);
      });

      test('creates instance with UserProfileFound entries', () {
        final alice = UserProfileFound(
          profile: UserProfileData.fromJson(
            'pubkey1',
            const {'name': 'Alice', 'display_name': 'Alice A'},
          ),
        );
        final bob = UserProfileFound(
          profile: UserProfileData.fromJson('pubkey2', const {'name': 'Bob'}),
        );
        final response = BulkProfilesResponse(
          profiles: {'pubkey1': alice, 'pubkey2': bob},
        );

        expect(response.profiles, hasLength(2));
        expect(response.profiles['pubkey1'], isA<UserProfileFound>());
        expect(
          (response.profiles['pubkey1']! as UserProfileFound).profile.name,
          equals('Alice'),
        );
        expect(response.profiles['pubkey2'], isA<UserProfileFound>());
        expect(
          (response.profiles['pubkey2']! as UserProfileFound).profile.name,
          equals('Bob'),
        );
      });

      test('creates instance with UserProfileNotPublished entries', () {
        const notPublished = UserProfileNotPublished(pubkey: 'pubkey3');
        const response = BulkProfilesResponse(
          profiles: {'pubkey3': notPublished},
        );

        expect(response.profiles, hasLength(1));
        expect(response.profiles['pubkey3'], isA<UserProfileNotPublished>());
        expect(
          (response.profiles['pubkey3']! as UserProfileNotPublished).pubkey,
          equals('pubkey3'),
        );
      });
    });
  });
}
