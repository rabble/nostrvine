// ABOUTME: Widget tests for FollowingBar.
// ABOUTME: Verifies empty state, avatar rendering, and user tap callback.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/inbox/widgets/following_bar.dart';
import 'package:openvine/widgets/user_avatar.dart';

import '../../../helpers/test_provider_overrides.dart';

void main() {
  const pubkey1 =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const pubkey2 =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

  final now = DateTime.now();

  UserProfile createTestProfile({
    required String pubkey,
    String? displayName,
    String? name,
  }) {
    return UserProfile(
      pubkey: pubkey,
      displayName: displayName,
      name: name,
      rawData: const {},
      createdAt: now,
      eventId:
          'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
    );
  }

  group(FollowingBar, () {
    group('renders', () {
      testWidgets('renders $SizedBox when following list is empty', (
        tester,
      ) async {
        await tester.pumpWidget(
          testMaterialApp(
            additionalOverrides: [
              cachedFollowingListProvider.overrideWith((ref) => <String>[]),
            ],
            home: Scaffold(
              body: FollowingBar(onUserTapped: (_) {}),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(FollowingBar), findsOneWidget);
        expect(find.byType(UserAvatar), findsNothing);
        expect(find.byType(SizedBox), findsOneWidget);
      });

      testWidgets('renders $UserAvatar for each following user', (
        tester,
      ) async {
        final profile1 = createTestProfile(
          pubkey: pubkey1,
          displayName: 'Alice',
        );
        final profile2 = createTestProfile(
          pubkey: pubkey2,
          displayName: 'Bob',
        );

        await tester.pumpWidget(
          testMaterialApp(
            additionalOverrides: [
              cachedFollowingListProvider.overrideWith(
                (ref) => [pubkey1, pubkey2],
              ),
              fetchUserProfileProvider(pubkey1).overrideWith(
                (ref) async => profile1,
              ),
              fetchUserProfileProvider(pubkey2).overrideWith(
                (ref) async => profile2,
              ),
            ],
            home: Scaffold(
              body: FollowingBar(onUserTapped: (_) {}),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(UserAvatar), findsNWidgets(2));
      });
    });

    group('interactions', () {
      testWidgets(
        'calls onUserTapped with correct pubkey when user is tapped',
        (tester) async {
          String? tappedPubkey;
          final profile1 = createTestProfile(
            pubkey: pubkey1,
            displayName: 'Alice',
          );
          final profile2 = createTestProfile(
            pubkey: pubkey2,
            displayName: 'Bob',
          );

          await tester.pumpWidget(
            testMaterialApp(
              additionalOverrides: [
                cachedFollowingListProvider.overrideWith(
                  (ref) => [pubkey1, pubkey2],
                ),
                fetchUserProfileProvider(pubkey1).overrideWith(
                  (ref) async => profile1,
                ),
                fetchUserProfileProvider(pubkey2).overrideWith(
                  (ref) async => profile2,
                ),
              ],
              home: Scaffold(
                body: FollowingBar(
                  onUserTapped: (pk) => tappedPubkey = pk,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Tap the first user avatar
          await tester.tap(find.text('Alice'));
          await tester.pumpAndSettle();

          expect(tappedPubkey, equals(pubkey1));
        },
      );
    });
  });
}
