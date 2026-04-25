// ABOUTME: Tests for ProfileBannerLayer
// ABOUTME: Verifies banner image, profile color fallback, and own/other-profile resolution

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/my_profile/my_profile_bloc.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/widgets/profile/profile_banner_layer.dart';
import 'package:openvine/widgets/profile/profile_header_widget.dart';

class _MockMyProfileBloc extends MockBloc<MyProfileEvent, MyProfileState>
    implements MyProfileBloc {}

const _testUserHex =
    '78a5c21b5166dc1474b64ddf7454bf79e6b5d6b4a77148593bf1e866b73c2738';

UserProfile _profileWithBanner(String? banner) {
  return UserProfile(
    pubkey: _testUserHex,
    rawData: {'banner': ?banner},
    banner: banner,
    createdAt: DateTime.now(),
    eventId: 'test-event',
  );
}

void main() {
  group(ProfileBannerLayer, () {
    Widget buildSubject({
      required bool isOwnProfile,
      UserProfile? suppliedProfile,
      UserProfile? myProfile,
      UserProfile? riverpodProfile,
    }) {
      Widget layer = ProfileBannerLayer(
        userIdHex: _testUserHex,
        isOwnProfile: isOwnProfile,
        profile: suppliedProfile,
      );

      if (isOwnProfile) {
        final mockBloc = _MockMyProfileBloc();
        when(() => mockBloc.state).thenReturn(
          myProfile != null
              ? MyProfileUpdated(profile: myProfile)
              : const MyProfileInitial(),
        );
        layer = BlocProvider<MyProfileBloc>.value(
          value: mockBloc,
          child: layer,
        );
      }

      return ProviderScope(
        overrides: [
          fetchUserProfileProvider(
            _testUserHex,
          ).overrideWith((ref) async => riverpodProfile),
        ],
        child: MaterialApp(home: Scaffold(body: layer)),
      );
    }

    testWidgets(
      'renders ProfileBanner with banner URL when profile has http banner',
      (tester) async {
        await tester.pumpWidget(
          buildSubject(
            isOwnProfile: true,
            myProfile: _profileWithBanner('https://example.com/banner.jpg'),
          ),
        );
        await tester.pump();

        final banner = tester.widget<ProfileBanner>(find.byType(ProfileBanner));
        expect(banner.bannerUrl, equals('https://example.com/banner.jpg'));
        expect(banner.profileColor, isNull);
      },
    );

    testWidgets('falls back to profileColor when banner field is a hex color', (
      tester,
    ) async {
      // Vine-imported profiles store a hex color in the banner field;
      // hasBannerImage is false, profileBackgroundColor resolves the hex.
      await tester.pumpWidget(
        buildSubject(
          isOwnProfile: true,
          myProfile: _profileWithBanner('0x336699'),
        ),
      );
      await tester.pump();

      final banner = tester.widget<ProfileBanner>(find.byType(ProfileBanner));
      expect(banner.bannerUrl, isNull);
      expect(banner.profileColor, isNotNull);
    });

    testWidgets('renders default banner when profile has no banner field', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(isOwnProfile: true, myProfile: _profileWithBanner(null)),
      );
      await tester.pump();

      final banner = tester.widget<ProfileBanner>(find.byType(ProfileBanner));
      expect(banner.bannerUrl, isNull);
      expect(banner.profileColor, isNull);
    });

    testWidgets('uses widget.profile for other profiles when supplied', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(
          isOwnProfile: false,
          suppliedProfile: _profileWithBanner('https://example.com/other.jpg'),
        ),
      );
      await tester.pump();

      final banner = tester.widget<ProfileBanner>(find.byType(ProfileBanner));
      expect(banner.bannerUrl, equals('https://example.com/other.jpg'));
    });

    testWidgets('falls back to fetchUserProfileProvider for other profiles', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(
          isOwnProfile: false,
          riverpodProfile: _profileWithBanner('https://example.com/relay.jpg'),
        ),
      );
      await tester.pumpAndSettle();

      final banner = tester.widget<ProfileBanner>(find.byType(ProfileBanner));
      expect(banner.bannerUrl, equals('https://example.com/relay.jpg'));
    });

    testWidgets(
      'renders default banner when own MyProfile state has no profile',
      (tester) async {
        await tester.pumpWidget(buildSubject(isOwnProfile: true));
        await tester.pump();

        // No banner data anywhere → ProfileBanner falls back to gradient.
        final banner = tester.widget<ProfileBanner>(find.byType(ProfileBanner));
        expect(banner.bannerUrl, isNull);
        expect(banner.profileColor, isNull);
      },
    );
  });
}
