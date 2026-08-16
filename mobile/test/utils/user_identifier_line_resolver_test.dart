// ABOUTME: Tests the secondary identifier line shown under a display name
// ABOUTME: Covers NIP-05 precedence and the social-proof fallback

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/services/nip05_verification_service.dart';
import 'package:openvine/utils/user_identifier_line_resolver.dart';

void main() {
  group('resolveUserIdentifierLine', () {
    late AppLocalizations l10n;

    setUp(() {
      l10n = lookupAppLocalizations(const Locale('en'));
    });

    String? resolve({
      String? handle,
      Nip05VerificationStatus? verificationStatus,
      bool isOwnProfile = false,
      FollowRelationship relationship = FollowRelationship.none,
      int? followerCount,
    }) {
      return resolveUserIdentifierLine(
        l10n: l10n,
        locale: 'en',
        handle: handle,
        verificationStatus: verificationStatus,
        isOwnProfile: isOwnProfile,
        relationship: relationship,
        followerCount: followerCount,
      );
    }

    group('NIP-05 precedence', () {
      test('shows the handle while verification is still pending', () {
        expect(resolve(handle: '@jack'), equals('@jack'));
      });

      test('shows the handle when verification errored on the network', () {
        expect(
          resolve(
            handle: '@jack',
            verificationStatus: Nip05VerificationStatus.error,
          ),
          equals('@jack'),
        );
      });

      test('shows the handle once verified', () {
        expect(
          resolve(
            handle: '@jack',
            verificationStatus: Nip05VerificationStatus.verified,
          ),
          equals('@jack'),
        );
      });

      test('hides a handle that failed verification on another profile', () {
        expect(
          resolve(
            handle: '@jack',
            verificationStatus: Nip05VerificationStatus.failed,
            followerCount: 12,
          ),
          equals('12 followers'),
        );
      });

      test("keeps a failed handle on the viewer's own profile", () {
        expect(
          resolve(
            handle: '@jack',
            verificationStatus: Nip05VerificationStatus.failed,
            isOwnProfile: true,
          ),
          equals('@jack'),
        );
      });

      test('falls through when the handle is empty', () {
        expect(
          resolve(handle: '', relationship: FollowRelationship.mutual),
          equals('Mutual'),
        );
      });
    });

    group('social proof fallback', () {
      test('combines relationship and follower count', () {
        expect(
          resolve(
            relationship: FollowRelationship.mutual,
            followerCount: 2100,
          ),
          equals('Mutual · 2.1K followers'),
        );
      });

      test('reports when the account follows the viewer', () {
        expect(
          resolve(relationship: FollowRelationship.followsYou),
          equals('Follows you'),
        );
      });

      test('reports when the viewer follows the account', () {
        expect(
          resolve(relationship: FollowRelationship.youFollow),
          equals('You follow'),
        );
      });

      test('shows only the count when there is no relationship', () {
        expect(resolve(followerCount: 430), equals('430 followers'));
      });

      test('singularizes a lone follower', () {
        expect(resolve(followerCount: 1), equals('1 follower'));
      });

      test('omits a zero follower count rather than showing "0 followers"', () {
        expect(
          resolve(
            relationship: FollowRelationship.youFollow,
            followerCount: 0,
          ),
          equals('You follow'),
        );
      });

      test('returns null when nothing useful is known', () {
        expect(resolve(), isNull);
      });

      test('returns null when the only signal is a zero count', () {
        expect(resolve(followerCount: 0), isNull);
      });
    });
  });
}
