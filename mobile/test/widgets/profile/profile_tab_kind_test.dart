import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/widgets/profile/profile_tab_kind.dart';

void main() {
  group('profileTabKinds', () {
    test('own profile shows Collabs between Videos and Liked, plus Saved', () {
      expect(
        profileTabKinds(isOwnProfile: true),
        equals(const [
          ProfileTabKind.videos,
          ProfileTabKind.collabs,
          ProfileTabKind.liked,
          ProfileTabKind.reposts,
          ProfileTabKind.saved,
          ProfileTabKind.comments,
        ]),
      );
    });

    test('own profile surfaces a Collabs tab (the #5213 fix)', () {
      final kinds = profileTabKinds(isOwnProfile: true);
      expect(kinds, contains(ProfileTabKind.collabs));
      expect(kinds.indexOf(ProfileTabKind.collabs), equals(1));
    });

    test('own profile keeps the Saved tab', () {
      expect(
        profileTabKinds(isOwnProfile: true),
        contains(ProfileTabKind.saved),
      );
    });

    test('other profile order is unchanged (Collabs in the 4th slot)', () {
      expect(
        profileTabKinds(isOwnProfile: false),
        equals(const [
          ProfileTabKind.videos,
          ProfileTabKind.liked,
          ProfileTabKind.reposts,
          ProfileTabKind.collabs,
          ProfileTabKind.comments,
        ]),
      );
    });

    test('other profile keeps Collabs at index 3 and has no Saved tab', () {
      final kinds = profileTabKinds(isOwnProfile: false);
      expect(kinds.indexOf(ProfileTabKind.collabs), equals(3));
      expect(kinds, isNot(contains(ProfileTabKind.saved)));
    });

    test('own profile has 6 tabs, other profile has 5', () {
      expect(profileTabKinds(isOwnProfile: true), hasLength(6));
      expect(profileTabKinds(isOwnProfile: false), hasLength(5));
    });
  });
}
